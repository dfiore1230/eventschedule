<?php

namespace Tests\Feature;

use App\Mail\ConfirmSubscriptionMail;
use App\Models\EmailCampaign;
use App\Models\EmailCampaignRecipientStat;
use App\Models\EmailCampaignRecipient;
use App\Models\EmailList;
use App\Models\EmailSubscriber;
use App\Models\EmailSubscription;
use App\Models\EmailSuppression;
use App\Models\Event;
use App\Models\Sale;
use App\Models\SystemRole;
use App\Models\User;
use App\Services\Email\EmailListService;
use App\Services\Email\EmailProviderInterface;
use App\Services\Email\EmailProviderSendResult;
use App\Services\Email\EmailProviderWebhookResult;
use App\Services\Email\EmailTemplateRenderer;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\URL;
use Tests\TestCase;

class MassEmailTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        // Ensure user_roles is not empty to avoid auto-superadmin on first user.
        $existingRole = SystemRole::query()->firstOrCreate(['slug' => 'existing'], ['name' => 'Existing']);
        User::factory()->create()->systemRoles()->attach($existingRole);
    }

    public function test_public_subscribe_requires_confirmation_when_double_opt_in_enabled(): void
    {
        Mail::fake();
        config(['mass_email.double_opt_in_marketing' => true]);

        $list = app(EmailListService::class)->getGlobalList();

        $response = $this->postJson(route('public.subscribe'), [
            'email' => 'subscriber@example.com',
            'first_name' => 'Sam',
            'list_id' => $list->id,
        ]);

        $response->assertStatus(202);

        $subscriber = EmailSubscriber::query()->where('email', 'subscriber@example.com')->first();
        $this->assertNotNull($subscriber);

        $this->assertDatabaseHas('email_subscriptions', [
            'subscriber_id' => $subscriber->id,
            'list_id' => $list->id,
            'status' => EmailSubscription::STATUS_PENDING,
        ]);

        Mail::assertSent(ConfirmSubscriptionMail::class);
    }

    public function test_public_confirm_marks_subscription_subscribed(): void
    {
        $list = app(EmailListService::class)->getGlobalList();
        $subscriber = EmailSubscriber::query()->create(['email' => 'pending@example.com']);
        $subscription = EmailSubscription::query()->create([
            'subscriber_id' => $subscriber->id,
            'list_id' => $list->id,
            'status' => EmailSubscription::STATUS_PENDING,
        ]);

        $url = URL::temporarySignedRoute('public.confirm', now()->addMinutes(10), [
            'subscriber' => $subscriber->id,
            'list' => $list->id,
        ]);

        $response = $this->get($url);
        $response->assertStatus(200);

        $this->assertSame(EmailSubscription::STATUS_SUBSCRIBED, $subscription->fresh()->status);
    }

    public function test_public_unsubscribe_marks_subscription_unsubscribed(): void
    {
        $list = app(EmailListService::class)->getGlobalList();
        $subscriber = EmailSubscriber::query()->create(['email' => 'unsub@example.com']);
        $subscription = EmailSubscription::query()->create([
            'subscriber_id' => $subscriber->id,
            'list_id' => $list->id,
            'status' => EmailSubscription::STATUS_SUBSCRIBED,
        ]);

        $url = URL::temporarySignedRoute('public.unsubscribe', now()->addMinutes(10), [
            'subscriber' => $subscriber->id,
            'list' => $list->id,
            'scope' => 'list',
        ]);

        $response = $this->get($url);
        $response->assertStatus(200);

        $this->assertSame(EmailSubscription::STATUS_UNSUBSCRIBED, $subscription->fresh()->status);
    }

    public function test_campaign_send_filters_suppressed_and_opt_out(): void
    {
        $provider = new FakeEmailProvider();
        $this->app->instance(EmailProviderInterface::class, $provider);

        $list = app(EmailListService::class)->getGlobalList();

        $unsubscribed = EmailSubscriber::query()->create([
            'email' => 'unsubbed@example.com',
            'marketing_unsubscribed_at' => now(),
        ]);
        EmailSubscription::query()->create([
            'subscriber_id' => $unsubscribed->id,
            'list_id' => $list->id,
            'status' => EmailSubscription::STATUS_SUBSCRIBED,
            'metadata' => ['marketing_opt_in' => true],
        ]);

        $optOut = EmailSubscriber::query()->create(['email' => 'optout@example.com']);
        EmailSubscription::query()->create([
            'subscriber_id' => $optOut->id,
            'list_id' => $list->id,
            'status' => EmailSubscription::STATUS_SUBSCRIBED,
            'metadata' => ['marketing_opt_in' => false],
        ]);

        $suppressed = EmailSubscriber::query()->create(['email' => 'suppressed@example.com']);
        EmailSubscription::query()->create([
            'subscriber_id' => $suppressed->id,
            'list_id' => $list->id,
            'status' => EmailSubscription::STATUS_SUBSCRIBED,
            'metadata' => ['marketing_opt_in' => true],
        ]);
        EmailSuppression::query()->create([
            'email' => 'suppressed@example.com',
            'reason' => EmailSuppression::REASON_BOUNCE,
        ]);

        $valid = EmailSubscriber::query()->create(['email' => 'valid@example.com', 'first_name' => 'Valid']);
        EmailSubscription::query()->create([
            'subscriber_id' => $valid->id,
            'list_id' => $list->id,
            'status' => EmailSubscription::STATUS_SUBSCRIBED,
            'metadata' => ['marketing_opt_in' => true],
        ]);

        $campaign = EmailCampaign::query()->create([
            'email_type' => EmailCampaign::TYPE_MARKETING,
            'subject' => 'Hello {{firstName}}',
            'from_email' => 'from@example.com',
            'from_name' => 'Sender',
            'content_text' => 'Body',
            'status' => EmailCampaign::STATUS_SCHEDULED,
        ]);
        $campaign->lists()->attach($list->id);

        $job = new \App\Jobs\SendEmailCampaignJob($campaign->id);
        $job->handle($provider, new EmailTemplateRenderer());

        $this->assertCount(1, $provider->sent);
        $this->assertSame('valid@example.com', $provider->sent[0]->toEmail);

        $recipient = EmailCampaignRecipient::query()
            ->where('campaign_id', $campaign->id)
            ->where('email', 'valid@example.com')
            ->first();
        $this->assertNotNull($recipient);
        $this->assertSame(EmailCampaignRecipient::STATUS_ACCEPTED, $recipient->status);

        $stats = EmailCampaignRecipientStat::query()->where('campaign_id', $campaign->id)->first();
        $this->assertNotNull($stats);
        $this->assertSame(4, $stats->targeted_count);
        $this->assertSame(3, $stats->suppressed_count);
        $this->assertSame(1, $stats->provider_accepted_count);
    }

    public function test_webhook_updates_suppression_and_unsubscribe(): void
    {
        $list = app(EmailListService::class)->getGlobalList();
        $subscriberA = EmailSubscriber::query()->create(['email' => 'bounce@example.com']);
        $subscriberB = EmailSubscriber::query()->create(['email' => 'all@example.com']);

        EmailSubscription::query()->create([
            'subscriber_id' => $subscriberA->id,
            'list_id' => $list->id,
            'status' => EmailSubscription::STATUS_SUBSCRIBED,
        ]);
        EmailSubscription::query()->create([
            'subscriber_id' => $subscriberB->id,
            'list_id' => $list->id,
            'status' => EmailSubscription::STATUS_SUBSCRIBED,
        ]);

        $campaign = EmailCampaign::query()->create([
            'email_type' => EmailCampaign::TYPE_MARKETING,
            'subject' => 'Test',
            'from_email' => 'from@example.com',
            'from_name' => 'Sender',
            'content_text' => 'Body',
            'status' => EmailCampaign::STATUS_SENT,
        ]);
        EmailCampaignRecipientStat::query()->create(['campaign_id' => $campaign->id]);
        EmailCampaignRecipient::query()->create([
            'campaign_id' => $campaign->id,
            'subscriber_id' => $subscriberA->id,
            'list_id' => $list->id,
            'email' => 'bounce@example.com',
            'status' => EmailCampaignRecipient::STATUS_ACCEPTED,
        ]);

        $payload = [
            'events' => [
                ['type' => 'bounce', 'email' => 'bounce@example.com', 'campaign_id' => $campaign->id],
                ['type' => 'complaint', 'email' => 'bounce@example.com'],
                ['type' => 'unsubscribe', 'email' => 'bounce@example.com', 'list_id' => $list->id],
                ['type' => 'unsubscribe', 'email' => 'all@example.com', 'unsubscribe_all' => true],
            ],
        ];

        $response = $this->postJson(route('email_provider.webhook'), $payload);
        $response->assertStatus(200);

        $this->assertDatabaseHas('email_suppressions', [
            'email' => 'bounce@example.com',
            'reason' => EmailSuppression::REASON_COMPLAINT,
        ]);

        $subscriptionA = EmailSubscription::query()
            ->where('subscriber_id', $subscriberA->id)
            ->where('list_id', $list->id)
            ->first();

        $this->assertSame(EmailSubscription::STATUS_UNSUBSCRIBED, $subscriptionA->status);
        $this->assertNotNull($subscriberB->fresh()->marketing_unsubscribed_at);

        $stats = EmailCampaignRecipientStat::query()->where('campaign_id', $campaign->id)->first();
        $this->assertSame(1, $stats->bounced_count);

        $recipient = EmailCampaignRecipient::query()
            ->where('campaign_id', $campaign->id)
            ->where('email', 'bounce@example.com')
            ->first();
        $this->assertNotNull($recipient);
        $this->assertSame(EmailCampaignRecipient::STATUS_BOUNCED, $recipient->status);
    }

    public function test_event_list_membership_updates_on_sale_paid_and_refund(): void
    {
        config(['mass_email.event_list_membership_on_refund' => 'retain']);

        $owner = User::factory()->create();
        $event = Event::factory()->create(['user_id' => $owner->id]);

        $sale = Sale::query()->create([
            'event_id' => $event->id,
            'name' => 'Buyer',
            'email' => 'buyer@example.com',
            'secret' => 'secret-123',
            'event_date' => now()->format('Y-m-d'),
            'subdomain' => 'test-subdomain',
            'status' => 'unpaid',
            'payment_method' => 'cash',
            'marketing_opt_in' => true,
        ]);

        $sale->update(['status' => 'paid']);

        $list = EmailList::query()->where('event_id', $event->id)->where('type', EmailList::TYPE_EVENT)->first();
        $this->assertNotNull($list);

        $subscription = EmailSubscription::query()
            ->where('list_id', $list->id)
            ->whereHas('subscriber', fn ($query) => $query->where('email', 'buyer@example.com'))
            ->first();

        $this->assertNotNull($subscription);
        $this->assertSame(EmailSubscription::STATUS_SUBSCRIBED, $subscription->status);
        $this->assertTrue($subscription->metadata['marketing_opt_in']);

        $sale->update(['status' => 'refunded']);

        $subscription->refresh();
        $this->assertSame(EmailSubscription::STATUS_SUBSCRIBED, $subscription->status);
        $this->assertSame('refunded', $subscription->metadata['ticket_status']);
    }

    public function test_returning_buyer_backfills_event_lists_on_new_purchase(): void
    {
        $owner = User::factory()->create();
        $eventOne = Event::factory()->create(['user_id' => $owner->id]);
        $eventTwo = Event::factory()->create(['user_id' => $owner->id]);

        Sale::query()->create([
            'event_id' => $eventOne->id,
            'name' => 'Buyer',
            'email' => 'repeat@example.com',
            'secret' => 'secret-one',
            'event_date' => now()->format('Y-m-d'),
            'subdomain' => 'test-subdomain',
            'status' => 'paid',
            'payment_method' => 'cash',
            'marketing_opt_in' => true,
        ]);

        $saleTwo = Sale::query()->create([
            'event_id' => $eventTwo->id,
            'name' => 'Buyer',
            'email' => 'repeat@example.com',
            'secret' => 'secret-two',
            'event_date' => now()->format('Y-m-d'),
            'subdomain' => 'test-subdomain',
            'status' => 'unpaid',
            'payment_method' => 'cash',
            'marketing_opt_in' => true,
        ]);

        $saleTwo->update(['status' => 'paid']);

        $listOne = EmailList::query()->where('event_id', $eventOne->id)->where('type', EmailList::TYPE_EVENT)->first();
        $listTwo = EmailList::query()->where('event_id', $eventTwo->id)->where('type', EmailList::TYPE_EVENT)->first();

        $this->assertNotNull($listOne);
        $this->assertNotNull($listTwo);

        $this->assertDatabaseHas('email_subscriptions', [
            'list_id' => $listOne->id,
            'status' => EmailSubscription::STATUS_SUBSCRIBED,
        ]);

        $this->assertDatabaseHas('email_subscriptions', [
            'list_id' => $listTwo->id,
            'status' => EmailSubscription::STATUS_SUBSCRIBED,
        ]);
    }
}

class FakeEmailProvider implements EmailProviderInterface
{
    public array $sent = [];

    public function sendBatch(array $messages): EmailProviderSendResult
    {
        $this->sent = array_merge($this->sent, $messages);

        return new EmailProviderSendResult(count($messages), 0);
    }

    public function validateFromAddress(string $fromEmail): bool
    {
        return true;
    }

    public function parseWebhook(Request $request): EmailProviderWebhookResult
    {
        return new EmailProviderWebhookResult();
    }

    public function syncSuppressions(array $emails, string $reason): void
    {
        // No-op for tests.
    }
}
