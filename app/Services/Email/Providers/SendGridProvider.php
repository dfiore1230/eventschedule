<?php

namespace App\Services\Email\Providers;

use App\Services\Email\EmailMessage;
use App\Services\Email\EmailProviderInterface;
use App\Services\Email\EmailProviderSendResult;
use App\Services\Email\EmailProviderWebhookResult;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;

class SendGridProvider implements EmailProviderInterface
{
    public function sendBatch(array $messages): EmailProviderSendResult
    {
        $accepted = 0;
        $failed = 0;
        $details = [];
        $apiKey = (string) config('mass_email.api_key');

        if ($apiKey === '') {
            return new EmailProviderSendResult(0, count($messages), [
                ['error' => 'SendGrid API key is not configured.'],
            ]);
        }

        foreach ($messages as $message) {
            try {
                $payload = $this->buildPayload($message);
                $response = Http::withToken($apiKey)
                    ->acceptJson()
                    ->post('https://api.sendgrid.com/v3/mail/send', $payload);

                if ($response->successful() || $response->status() === 202) {
                    $accepted++;
                } else {
                    $failed++;
                    $details[] = [
                        'status' => $response->status(),
                        'error' => $response->body(),
                    ];
                }
            } catch (\Throwable $e) {
                $failed++;
                $details[] = ['error' => $e->getMessage()];
            }
        }

        return new EmailProviderSendResult($accepted, $failed, $details);
    }

    public function validateFromAddress(string $fromEmail): bool
    {
        return (bool) filter_var($fromEmail, FILTER_VALIDATE_EMAIL);
    }

    public function parseWebhook(Request $request): EmailProviderWebhookResult
    {
        $events = $request->all();
        if (! is_array($events)) {
            $events = [];
        }

        $bounces = [];
        $complaints = [];
        $unsubscribes = [];

        foreach ($events as $event) {
            if (! is_array($event)) {
                continue;
            }

            $type = $event['event'] ?? null;
            $payload = [
                'email' => $event['email'] ?? null,
                'campaign_id' => $event['custom_args']['campaign_id'] ?? null,
                'list_id' => $event['custom_args']['list_id'] ?? null,
            ];

            if (in_array($type, ['bounce', 'blocked', 'dropped', 'deferred'], true)) {
                $bounces[] = $payload;
            } elseif ($type === 'spamreport') {
                $complaints[] = $payload;
            } elseif (in_array($type, ['unsubscribe', 'group_unsubscribe'], true)) {
                $payload['unsubscribe_all'] = empty($payload['list_id']);
                $unsubscribes[] = $payload;
            }
        }

        return new EmailProviderWebhookResult($bounces, $complaints, $unsubscribes);
    }

    private function buildPayload(EmailMessage $message): array
    {
        $content = [];

        if ($message->text) {
            $content[] = [
                'type' => 'text/plain',
                'value' => $message->text,
            ];
        }

        if ($message->html) {
            $content[] = [
                'type' => 'text/html',
                'value' => $message->html,
            ];
        }

        $personalization = [
            'to' => [
                [
                    'email' => $message->toEmail,
                    'name' => $message->toName,
                ],
            ],
            'subject' => $message->subject,
            'headers' => $message->headers,
            'custom_args' => $message->metadata,
        ];

        if (! empty($message->metadata['email_type'])) {
            $personalization['categories'] = [$message->metadata['email_type']];
        }

        $payload = [
            'personalizations' => [$personalization],
            'from' => [
                'email' => $message->fromEmail,
                'name' => $message->fromName,
            ],
            'content' => $content,
        ];

        if ($message->replyTo) {
            $payload['reply_to'] = ['email' => $message->replyTo];
        }

        return $payload;
    }
}
