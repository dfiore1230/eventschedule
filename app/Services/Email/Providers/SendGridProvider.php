<?php

namespace App\Services\Email\Providers;

use App\Services\Email\EmailMessage;
use App\Services\Email\EmailProviderInterface;
use App\Services\Email\EmailProviderSendResult;
use App\Services\Email\EmailProviderWebhookResult;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class SendGridProvider implements EmailProviderInterface
{
    public function sendBatch(array $messages): EmailProviderSendResult
    {
        $accepted = 0;
        $failed = 0;
        $details = [];
        $messageIds = [];
        $apiKey = (string) config('mass_email.api_key');

        if ($apiKey === '') {
            return new EmailProviderSendResult(0, count($messages), [
                ['error' => 'SendGrid API key is not configured.'],
            ]);
        }

        if ($this->canBatch($messages)) {
            $payload = $this->buildBatchPayload($messages);
            try {
                $response = Http::withToken($apiKey)
                    ->acceptJson()
                    ->post('https://api.sendgrid.com/v3/mail/send', $payload);

                if ($response->successful() || $response->status() === 202) {
                    $accepted = count($messages);
                    $messageId = $response->header('X-Message-Id');
                    foreach ($messages as $message) {
                        if ($messageId) {
                            $messageIds[$message->toEmail] = $messageId;
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
                $response = Http::withToken($apiKey)
                    ->acceptJson()
                    ->post('https://api.sendgrid.com/v3/mail/send', $payload);

                if ($response->successful() || $response->status() === 202) {
                    $accepted++;
                    $messageId = $response->header('X-Message-Id');
                    if ($messageId) {
                        $messageIds[$message->toEmail] = $messageId;
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

        return (bool) filter_var($fromEmail, FILTER_VALIDATE_EMAIL) && $apiKey !== '';
    }

    public function parseWebhook(Request $request): EmailProviderWebhookResult
    {
        if (! $this->verifyWebhookSignature($request)) {
            Log::warning('SendGrid webhook signature verification failed');
            return new EmailProviderWebhookResult([], [], []);
        }

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

    public function syncSuppressions(array $emails, string $reason): void
    {
        $apiKey = (string) config('mass_email.api_key');

        if ($apiKey === '' || $emails === []) {
            return;
        }

        $emails = array_values(array_unique(array_filter($emails)));

        $endpoint = match ($reason) {
            'complaint' => 'https://api.sendgrid.com/v3/suppression/spam_reports',
            'bounce' => 'https://api.sendgrid.com/v3/suppression/bounces',
            default => 'https://api.sendgrid.com/v3/asm/suppressions/global',
        };

        $payload = $reason === 'complaint' || $reason === 'bounce'
            ? ['emails' => $emails]
            : ['recipient_emails' => $emails];

        try {
            Http::withToken($apiKey)->acceptJson()->post($endpoint, $payload);
        } catch (\Throwable $e) {
            Log::warning('SendGrid suppression sync failed', ['error' => $e->getMessage()]);
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
            ) {
                return false;
            }
        }

        return true;
    }

    private function buildBatchPayload(array $messages): array
    {
        $first = $messages[0];
        $personalizations = [];

        foreach ($messages as $message) {
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

            $personalizations[] = $personalization;
        }

        $payload = [
            'personalizations' => $personalizations,
            'from' => [
                'email' => $first->fromEmail,
                'name' => $first->fromName,
            ],
            'content' => [],
        ];

        if ($first->replyTo) {
            $payload['reply_to'] = ['email' => $first->replyTo];
        }

        if ($first->text) {
            $payload['content'][] = [
                'type' => 'text/plain',
                'value' => $first->text,
            ];
        }

        if ($first->html) {
            $payload['content'][] = [
                'type' => 'text/html',
                'value' => $first->html,
            ];
        }

        $asmGroupId = (int) config('mass_email.sendgrid_unsubscribe_group_id', 0);
        if ($asmGroupId > 0) {
            $payload['asm'] = [
                'group_id' => $asmGroupId,
                'groups_to_display' => [$asmGroupId],
            ];
        }

        return $payload;
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

        $asmGroupId = (int) config('mass_email.sendgrid_unsubscribe_group_id', 0);
        if ($asmGroupId > 0) {
            $payload['asm'] = [
                'group_id' => $asmGroupId,
                'groups_to_display' => [$asmGroupId],
            ];
        }

        return $payload;
    }

    private function verifyWebhookSignature(Request $request): bool
    {
        $publicKey = (string) config('mass_email.webhook_public_key');

        if ($publicKey === '') {
            return true;
        }

        if (! function_exists('sodium_crypto_sign_verify_detached')) {
            return false;
        }

        $signature = $request->header('X-Twilio-Email-Event-Webhook-Signature');
        $timestamp = $request->header('X-Twilio-Email-Event-Webhook-Timestamp');

        if (! $signature || ! $timestamp) {
            return false;
        }

        $signedPayload = $timestamp . $request->getContent();
        $signatureBytes = base64_decode($signature, true);
        $publicKeyBytes = base64_decode($publicKey, true);

        if ($signatureBytes === false || $publicKeyBytes === false) {
            return false;
        }

        return sodium_crypto_sign_verify_detached($signatureBytes, $signedPayload, $publicKeyBytes);
    }
}
