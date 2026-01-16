<?php

namespace Tests\Feature;

use App\Services\Email\EmailMessage;
use App\Services\Email\Providers\MailchimpProvider;
use App\Services\Email\Providers\MailgunProvider;
use App\Services\Email\Providers\SendGridProvider;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class EmailProviderTest extends TestCase
{
    public function test_sendgrid_batch_send_records_message_ids(): void
    {
        config(['mass_email.api_key' => 'sg-test-key']);

        Http::fake([
            'https://api.sendgrid.com/v3/mail/send' => Http::response('', 202, [
                'X-Message-Id' => 'sg-123',
            ]),
        ]);

        $provider = new SendGridProvider();
        $messages = $this->buildMessages();

        $result = $provider->sendBatch($messages);

        $this->assertSame(2, $result->acceptedCount);
        $this->assertSame(0, $result->failedCount);
        $this->assertSame('sg-123', $result->messageIds['a@example.com'] ?? null);
        $this->assertSame('sg-123', $result->messageIds['b@example.com'] ?? null);
    }

    public function test_mailgun_batch_send_records_message_ids(): void
    {
        config([
            'mass_email.api_key' => 'mg-test-key',
            'mass_email.sending_domain' => 'example.test',
        ]);

        Http::fake([
            'https://api.mailgun.net/v3/example.test/messages' => Http::response([
                'id' => 'mg-123',
            ], 200),
        ]);

        $provider = new MailgunProvider();
        $messages = $this->buildMessages();

        $result = $provider->sendBatch($messages);

        $this->assertSame(2, $result->acceptedCount);
        $this->assertSame(0, $result->failedCount);
        $this->assertSame('mg-123', $result->messageIds['a@example.com'] ?? null);
        $this->assertSame('mg-123', $result->messageIds['b@example.com'] ?? null);
    }

    public function test_mailchimp_batch_send_records_message_ids(): void
    {
        config(['mass_email.api_key' => 'mc-test-key']);

        Http::fake([
            'https://mandrillapp.com/api/1.0/messages/send.json' => Http::response([
                [
                    'email' => 'a@example.com',
                    'status' => 'sent',
                    '_id' => 'mc-1',
                ],
                [
                    'email' => 'b@example.com',
                    'status' => 'queued',
                    '_id' => 'mc-2',
                ],
            ], 200),
        ]);

        $provider = new MailchimpProvider();
        $messages = $this->buildMessages();

        $result = $provider->sendBatch($messages);

        $this->assertSame(2, $result->acceptedCount);
        $this->assertSame(0, $result->failedCount);
        $this->assertSame('mc-1', $result->messageIds['a@example.com'] ?? null);
        $this->assertSame('mc-2', $result->messageIds['b@example.com'] ?? null);
    }

    public function test_sendgrid_webhook_signature_rejects_invalid_signature(): void
    {
        config(['mass_email.webhook_public_key' => base64_encode('invalid-key')]);

        $request = Request::create('/webhooks/email-provider', 'POST', [
            [
                'event' => 'bounce',
                'email' => 'a@example.com',
            ],
        ]);
        $request->headers->set('X-Twilio-Email-Event-Webhook-Signature', 'invalid');
        $request->headers->set('X-Twilio-Email-Event-Webhook-Timestamp', '123456');

        $provider = new SendGridProvider();
        $result = $provider->parseWebhook($request);

        $this->assertSame([], $result->bounces);
        $this->assertSame([], $result->complaints);
        $this->assertSame([], $result->unsubscribes);
    }

    public function test_mailgun_webhook_signature_accepts_valid_signature(): void
    {
        config(['mass_email.webhook_secret' => 'mailgun-secret']);

        $payload = [
            'timestamp' => '1691000000',
            'token' => 'token-123',
            'signature' => hash_hmac('sha256', '1691000000token-123', 'mailgun-secret'),
            'event-data' => [
                'event' => 'bounced',
                'recipient' => 'bounced@example.com',
            ],
        ];

        $request = Request::create('/webhooks/email-provider', 'POST', $payload);

        $provider = new MailgunProvider();
        $result = $provider->parseWebhook($request);

        $this->assertCount(1, $result->bounces);
    }

    public function test_mailchimp_webhook_signature_accepts_valid_signature(): void
    {
        config(['mass_email.api_key' => 'mandrill-secret']);

        $events = [[
            'event' => 'spam',
            'msg' => [
                'email' => 'spam@example.com',
                'metadata' => [
                    'campaign_id' => 10,
                ],
            ],
        ]];

        $payload = [
            'mandrill_events' => json_encode($events),
        ];

        $request = Request::create('https://example.test/webhooks/email-provider', 'POST', $payload);
        $signature = $this->buildMandrillSignature($request->url(), $payload, 'mandrill-secret');
        $request->headers->set('X-Mandrill-Signature', $signature);

        $provider = new MailchimpProvider();
        $result = $provider->parseWebhook($request);

        $this->assertCount(1, $result->complaints);
    }

    public function test_provider_suppression_sync_hits_provider_endpoints(): void
    {
        Http::fake();

        config(['mass_email.api_key' => 'sg-test-key']);
        (new SendGridProvider())->syncSuppressions(['a@example.com'], 'complaint');

        config([
            'mass_email.api_key' => 'mg-test-key',
            'mass_email.sending_domain' => 'example.test',
        ]);
        (new MailgunProvider())->syncSuppressions(['b@example.com'], 'unsubscribe');

        config(['mass_email.api_key' => 'mc-test-key']);
        (new MailchimpProvider())->syncSuppressions(['c@example.com'], 'unsubscribe');

        Http::assertSentCount(3);
    }

    /**
     * @return array<int, EmailMessage>
     */
    private function buildMessages(): array
    {
        return [
            new EmailMessage(
                'a@example.com',
                'A User',
                'Hello',
                'from@example.com',
                'From Name',
                null,
                '<p>Hello there</p>',
                'Hello there',
                ['X-Test' => '1'],
                ['campaign_id' => 1, 'list_id' => 2, 'email_type' => 'marketing']
            ),
            new EmailMessage(
                'b@example.com',
                'B User',
                'Hello',
                'from@example.com',
                'From Name',
                null,
                '<p>Hello there</p>',
                'Hello there',
                ['X-Test' => '1'],
                ['campaign_id' => 1, 'list_id' => 2, 'email_type' => 'marketing']
            ),
        ];
    }

    private function buildMandrillSignature(string $url, array $params, string $key): string
    {
        ksort($params);
        $payload = $url;

        foreach ($params as $paramKey => $value) {
            if (is_scalar($value)) {
                $payload .= $paramKey . $value;
            }
        }

        $hash = hash_hmac('sha1', $payload, $key, true);

        return base64_encode($hash);
    }
}
