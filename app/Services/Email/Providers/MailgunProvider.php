<?php

namespace App\Services\Email\Providers;

use App\Services\Email\EmailMessage;
use App\Services\Email\EmailProviderInterface;
use App\Services\Email\EmailProviderSendResult;
use App\Services\Email\EmailProviderWebhookResult;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;

class MailgunProvider implements EmailProviderInterface
{
    public function sendBatch(array $messages): EmailProviderSendResult
    {
        $accepted = 0;
        $failed = 0;
        $details = [];
        $apiKey = (string) config('mass_email.api_key');
        $domain = (string) config('mass_email.sending_domain');

        if ($apiKey === '' || $domain === '') {
            return new EmailProviderSendResult(0, count($messages), [
                ['error' => 'Mailgun API key or sending domain is not configured.'],
            ]);
        }

        $endpoint = 'https://api.mailgun.net/v3/' . $domain . '/messages';

        foreach ($messages as $message) {
            try {
                $payload = $this->buildPayload($message);
                $response = Http::withBasicAuth('api', $apiKey)
                    ->asForm()
                    ->post($endpoint, $payload);

                if ($response->successful()) {
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
        $payload = $request->all();
        $events = [];

        if (isset($payload['event-data'])) {
            $events[] = $payload['event-data'];
        } elseif (isset($payload['items']) && is_array($payload['items'])) {
            $events = $payload['items'];
        } elseif (is_array($payload)) {
            $events = $payload;
        }

        $bounces = [];
        $complaints = [];
        $unsubscribes = [];

        foreach ($events as $event) {
            if (! is_array($event)) {
                continue;
            }

            $type = $event['event'] ?? $event['type'] ?? null;
            $email = $event['recipient'] ?? $event['email'] ?? null;
            $custom = $event['user-variables'] ?? $event['custom_args'] ?? [];

            $payload = [
                'email' => $email,
                'campaign_id' => $custom['campaign_id'] ?? null,
                'list_id' => $custom['list_id'] ?? null,
            ];

            if (in_array($type, ['bounced', 'failed'], true)) {
                $bounces[] = $payload;
            } elseif ($type === 'complained') {
                $complaints[] = $payload;
            } elseif ($type === 'unsubscribed') {
                $payload['unsubscribe_all'] = empty($payload['list_id']);
                $unsubscribes[] = $payload;
            }
        }

        return new EmailProviderWebhookResult($bounces, $complaints, $unsubscribes);
    }

    private function buildPayload(EmailMessage $message): array
    {
        $payload = [
            'to' => $message->toName ? $message->toName . ' <' . $message->toEmail . '>' : $message->toEmail,
            'from' => $message->fromName ? $message->fromName . ' <' . $message->fromEmail . '>' : $message->fromEmail,
            'subject' => $message->subject,
        ];

        if ($message->replyTo) {
            $payload['h:Reply-To'] = $message->replyTo;
        }

        if ($message->text) {
            $payload['text'] = $message->text;
        }

        if ($message->html) {
            $payload['html'] = $message->html;
        }

        foreach ($message->headers as $key => $value) {
            if ($value === null || $value === '') {
                continue;
            }

            $payload['h:' . $key] = (string) $value;
        }

        foreach ($message->metadata as $key => $value) {
            if ($value === null || $value === '') {
                continue;
            }

            $payload['v:' . $key] = (string) $value;
        }

        return $payload;
    }
}
