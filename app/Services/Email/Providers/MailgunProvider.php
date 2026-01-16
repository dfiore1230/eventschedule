<?php

namespace App\Services\Email\Providers;

use App\Services\Email\EmailMessage;
use App\Services\Email\EmailProviderInterface;
use App\Services\Email\EmailProviderSendResult;
use App\Services\Email\EmailProviderWebhookResult;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class MailgunProvider implements EmailProviderInterface
{
    public function sendBatch(array $messages): EmailProviderSendResult
    {
        $accepted = 0;
        $failed = 0;
        $details = [];
        $messageIds = [];
        $apiKey = (string) config('mass_email.api_key');
        $domain = (string) config('mass_email.sending_domain');

        if ($apiKey === '' || $domain === '') {
            return new EmailProviderSendResult(0, count($messages), [
                ['error' => 'Mailgun API key or sending domain is not configured.'],
            ]);
        }

        $endpoint = 'https://api.mailgun.net/v3/' . $domain . '/messages';

        if ($this->canBatch($messages)) {
            $payload = $this->buildBatchPayload($messages);

            try {
                $response = Http::withBasicAuth('api', $apiKey)
                    ->asForm()
                    ->post($endpoint, $payload);

                if ($response->successful()) {
                    $accepted = count($messages);
                    $responseId = $response->json('id');
                    foreach ($messages as $message) {
                        if ($responseId) {
                            $messageIds[$message->toEmail] = $responseId;
                        }
                    }
                } else {
                    $failed = count($messages);
                    $details[] = [
                        'status' => $response->status(),
                        'error' => $response->body(),
                    ];
                }
            } catch (\Throwable $e) {
                $failed = count($messages);
                $details[] = ['error' => $e->getMessage()];
            }

            return new EmailProviderSendResult($accepted, $failed, $details, $messageIds);
        }

        foreach ($messages as $message) {
            try {
                $payload = $this->buildPayload($message);
                $response = Http::withBasicAuth('api', $apiKey)
                    ->asForm()
                    ->post($endpoint, $payload);

                if ($response->successful()) {
                    $accepted++;
                    $responseId = $response->json('id');
                    if ($responseId) {
                        $messageIds[$message->toEmail] = $responseId;
                    }
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

        return new EmailProviderSendResult($accepted, $failed, $details, $messageIds);
    }

    public function validateFromAddress(string $fromEmail): bool
    {
        $apiKey = (string) config('mass_email.api_key');
        $domain = (string) config('mass_email.sending_domain');

        return (bool) filter_var($fromEmail, FILTER_VALIDATE_EMAIL) && $apiKey !== '' && $domain !== '';
    }

    public function parseWebhook(Request $request): EmailProviderWebhookResult
    {
        if (! $this->verifyWebhookSignature($request)) {
            Log::warning('Mailgun webhook signature verification failed');
            return new EmailProviderWebhookResult([], [], []);
        }

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

    public function syncSuppressions(array $emails, string $reason): void
    {
        $apiKey = (string) config('mass_email.api_key');
        $domain = (string) config('mass_email.sending_domain');

        if ($apiKey === '' || $domain === '' || $emails === []) {
            return;
        }

        $emails = array_values(array_unique(array_filter($emails)));
        $endpoint = match ($reason) {
            'complaint' => "https://api.mailgun.net/v3/{$domain}/complaints",
            'bounce' => "https://api.mailgun.net/v3/{$domain}/bounces",
            default => "https://api.mailgun.net/v3/{$domain}/unsubscribes",
        };

        foreach ($emails as $email) {
            try {
                Http::withBasicAuth('api', $apiKey)
                    ->asForm()
                    ->post($endpoint, ['address' => $email]);
            } catch (\Throwable $e) {
                Log::warning('Mailgun suppression sync failed', [
                    'email' => $email,
                    'error' => $e->getMessage(),
                ]);
            }
        }
    }

    private function canBatch(array $messages): bool
    {
        if (count($messages) <= 1) {
            return false;
        }

        $first = $messages[0];

        foreach ($messages as $message) {
            if (
                $message->subject !== $first->subject
                || $message->fromEmail !== $first->fromEmail
                || $message->fromName !== $first->fromName
                || $message->replyTo !== $first->replyTo
                || $message->html !== $first->html
                || $message->text !== $first->text
                || $message->headers !== $first->headers
                || $message->metadata !== $first->metadata
            ) {
                return false;
            }
        }

        return true;
    }

    private function buildBatchPayload(array $messages): array
    {
        $first = $messages[0];
        $recipients = array_map(function ($message) {
            return $message->toName ? $message->toName . ' <' . $message->toEmail . '>' : $message->toEmail;
        }, $messages);

        $payload = [
            'to' => implode(',', $recipients),
            'from' => $first->fromName ? $first->fromName . ' <' . $first->fromEmail . '>' : $first->fromEmail,
            'subject' => $first->subject,
        ];

        if ($first->replyTo) {
            $payload['h:Reply-To'] = $first->replyTo;
        }

        if ($first->text) {
            $payload['text'] = $first->text;
        }

        if ($first->html) {
            $payload['html'] = $first->html;
        }

        foreach ($first->headers as $key => $value) {
            if ($value === null || $value === '') {
                continue;
            }

            $payload['h:' . $key] = (string) $value;
        }

        foreach ($first->metadata as $key => $value) {
            if ($value === null || $value === '') {
                continue;
            }

            $payload['v:' . $key] = (string) $value;
        }

        return $payload;
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

    private function verifyWebhookSignature(Request $request): bool
    {
        $signingKey = (string) config('mass_email.webhook_secret');

        if ($signingKey === '') {
            return true;
        }

        $timestamp = (string) $request->input('timestamp');
        $token = (string) $request->input('token');
        $signature = (string) $request->input('signature');

        if ($timestamp === '' || $token === '' || $signature === '') {
            return false;
        }

        $hmac = hash_hmac('sha256', $timestamp . $token, $signingKey);

        return hash_equals($hmac, $signature);
    }
}
