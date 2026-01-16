<?php

namespace App\Services\Email\Providers;

use App\Services\Email\EmailMessage;
use App\Services\Email\EmailProviderInterface;
use App\Services\Email\EmailProviderSendResult;
use App\Services\Email\EmailProviderWebhookResult;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class MailchimpProvider implements EmailProviderInterface
{
    private const API_ENDPOINT = 'https://mandrillapp.com/api/1.0/messages/send.json';

    public function sendBatch(array $messages): EmailProviderSendResult
    {
        $accepted = 0;
        $failed = 0;
        $details = [];
        $messageIds = [];
        $apiKey = (string) config('mass_email.api_key');

        if ($apiKey === '') {
            return new EmailProviderSendResult(0, count($messages), [
                ['error' => 'Mailchimp Transactional API key is not configured.'],
            ]);
        }

        if ($this->canBatch($messages)) {
            $payload = $this->buildBatchPayload($messages, $apiKey);
            try {
                $response = Http::acceptJson()->post(self::API_ENDPOINT, $payload);

                if (! $response->successful()) {
                    return new EmailProviderSendResult(0, count($messages), [[
                        'status' => $response->status(),
                        'error' => $response->body(),
                    ]]);
                }

                $results = $response->json();
                if (is_array($results)) {
                    foreach ($results as $result) {
                        $status = $result['status'] ?? '';
                        if (in_array($status, ['sent', 'queued', 'scheduled'], true)) {
                            $accepted++;
                        } else {
                            $failed++;
                            $details[] = [
                                'status' => $status,
                                'error' => $result['reject_reason'] ?? 'Mailchimp rejected message.',
                            ];
                        }

                        if (! empty($result['email']) && ! empty($result['_id'])) {
                            $messageIds[$result['email']] = $result['_id'];
                        }
                    }
                }

                return new EmailProviderSendResult($accepted, $failed, $details, $messageIds);
            } catch (\Throwable $e) {
                return new EmailProviderSendResult(0, count($messages), [['error' => $e->getMessage()]]);
            }
        }

        foreach ($messages as $message) {
            try {
                $payload = $this->buildPayload($message, $apiKey);
                $response = Http::acceptJson()->post(self::API_ENDPOINT, $payload);

                if (! $response->successful()) {
                    $failed++;
                    $details[] = [
                        'status' => $response->status(),
                        'error' => $response->body(),
                    ];
                    continue;
                }

                $results = $response->json();
                $status = is_array($results) && isset($results[0]['status'])
                    ? (string) $results[0]['status']
                    : '';

                if (in_array($status, ['sent', 'queued', 'scheduled'], true)) {
                    $accepted++;
                    if (! empty($results[0]['_id'])) {
                        $messageIds[$message->toEmail] = $results[0]['_id'];
                    }
                } else {
                    $failed++;
                    $details[] = [
                        'status' => $status,
                        'error' => $results[0]['reject_reason'] ?? 'Mailchimp rejected message.',
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
            Log::warning('Mailchimp webhook signature verification failed');
            return new EmailProviderWebhookResult([], [], []);
        }

        $eventsPayload = $request->input('mandrill_events');
        $events = [];

        if (is_string($eventsPayload)) {
            $decoded = json_decode($eventsPayload, true);
            if (is_array($decoded)) {
                $events = $decoded;
            }
        } elseif (is_array($eventsPayload)) {
            $events = $eventsPayload;
        } elseif (is_array($request->all())) {
            $events = $request->all();
        }

        $bounces = [];
        $complaints = [];
        $unsubscribes = [];

        foreach ($events as $event) {
            if (! is_array($event)) {
                continue;
            }

            $type = $event['event'] ?? null;
            $msg = $event['msg'] ?? [];
            $metadata = is_array($msg) ? ($msg['metadata'] ?? []) : [];

            $payload = [
                'email' => $msg['email'] ?? $event['email'] ?? null,
                'campaign_id' => $metadata['campaign_id'] ?? null,
                'list_id' => $metadata['list_id'] ?? null,
            ];

            if (in_array($type, ['hard_bounce', 'soft_bounce', 'reject', 'defer'], true)) {
                $bounces[] = $payload;
            } elseif ($type === 'spam') {
                $complaints[] = $payload;
            } elseif ($type === 'unsub') {
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

        foreach ($emails as $email) {
            try {
                Http::acceptJson()->post('https://mandrillapp.com/api/1.0/rejects/add.json', [
                    'key' => $apiKey,
                    'email' => $email,
                    'comment' => $reason,
                ]);
            } catch (\Throwable $e) {
                Log::warning('Mailchimp suppression sync failed', [
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

    private function buildBatchPayload(array $messages, string $apiKey): array
    {
        $first = $messages[0];

        $to = array_map(function ($message) {
            return [
                'email' => $message->toEmail,
                'name' => $message->toName,
                'type' => 'to',
            ];
        }, $messages);

        $payload = [
            'key' => $apiKey,
            'message' => [
                'to' => $to,
                'from_email' => $first->fromEmail,
                'from_name' => $first->fromName,
                'subject' => $first->subject,
                'headers' => $first->headers,
                'metadata' => $first->metadata,
            ],
        ];

        if ($first->replyTo) {
            $payload['message']['headers']['Reply-To'] = $first->replyTo;
        }

        if ($first->text) {
            $payload['message']['text'] = $first->text;
        }

        if ($first->html) {
            $payload['message']['html'] = $first->html;
        }

        return $payload;
    }

    private function buildPayload(EmailMessage $message, string $apiKey): array
    {
        $payload = [
            'key' => $apiKey,
            'message' => [
                'to' => [[
                    'email' => $message->toEmail,
                    'name' => $message->toName,
                    'type' => 'to',
                ]],
                'from_email' => $message->fromEmail,
                'from_name' => $message->fromName,
                'subject' => $message->subject,
                'headers' => $message->headers,
                'metadata' => $message->metadata,
            ],
        ];

        if ($message->replyTo) {
            $payload['message']['headers']['Reply-To'] = $message->replyTo;
        }

        if ($message->text) {
            $payload['message']['text'] = $message->text;
        }

        if ($message->html) {
            $payload['message']['html'] = $message->html;
        }

        return $payload;
    }

    private function verifyWebhookSignature(Request $request): bool
    {
        $apiKey = (string) config('mass_email.api_key');

        if ($apiKey === '') {
            return true;
        }

        $signature = $request->header('X-Mandrill-Signature');

        if (! $signature) {
            return false;
        }

        $params = $request->all();
        ksort($params);

        $payload = $request->url();

        foreach ($params as $key => $value) {
            if (is_scalar($value)) {
                $payload .= $key . $value;
            }
        }

        $hash = hash_hmac('sha1', $payload, $apiKey, true);
        $expected = base64_encode($hash);

        return hash_equals($expected, $signature);
    }
}
