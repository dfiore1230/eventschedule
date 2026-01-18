<?php

namespace Tests\Feature;

use App\Models\Permission;
use App\Models\SystemRole;
use App\Models\User;
use App\Models\Event;
use App\Models\Role;
use App\Models\Setting;
use App\Services\Authorization\AuthorizationService;
use App\Services\Email\EmailListService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class EmailUiTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $existingRole = SystemRole::query()->firstOrCreate(['slug' => 'existing'], ['name' => 'Existing']);
        User::factory()->create()->systemRoles()->attach($existingRole);
    }

    public function test_admin_can_access_global_email_pages(): void
    {
        $admin = $this->createManagerWithPermission('settings.manage');

        $this->actingAs($admin)->get(route('email.index'))->assertStatus(200);
        $this->actingAs($admin)->get(route('email.create'))->assertStatus(200);
        $this->actingAs($admin)->get(route('email.subscribers.index'))->assertStatus(200);
    }

    public function test_non_admin_cannot_access_global_email_pages(): void
    {
        $user = User::factory()->create();

        $this->actingAs($user)->get(route('email.index'))->assertStatus(403);
        $this->actingAs($user)->get(route('email.create'))->assertStatus(403);
    }

    public function test_event_admin_can_access_event_email_pages(): void
    {
        $owner = User::factory()->create();
        $event = Event::factory()->create(['user_id' => $owner->id]);
        $role = $event->roles()->first() ?: Role::factory()->create();

        $response = $this->actingAs($owner)->get(route('event.email.index', [
            'subdomain' => $role->subdomain,
            'hash' => \App\Utils\UrlUtils::encodeId($event->id),
        ]));

        $response->assertStatus(200);
    }

    public function test_public_subscribe_form_for_event_is_visible(): void
    {
        $event = Event::factory()->create();

        $response = $this->get(route('public.subscribe.event', [
            'hash' => \App\Utils\UrlUtils::encodeId($event->id),
        ]));

        $response->assertStatus(200);
        $response->assertSeeText('Stay in the loop for');
        $response->assertSeeText('Join the event mailing list for schedule updates and important announcements.');
    }

    public function test_settings_mail_update_stores_mass_email_settings(): void
    {
        $admin = $this->createManagerWithPermission('settings.manage');

        $payload = [
            'mail_mailer' => 'smtp',
            'mail_host' => 'smtp.example.test',
            'mail_port' => 587,
            'mail_username' => 'user',
            'mail_password' => 'secret',
            'mail_encryption' => 'tls',
            'mail_from_address' => 'no-reply@example.test',
            'mail_from_name' => 'Planify',
            'mail_disable_delivery' => false,
            'mass_email_provider' => 'sendgrid',
            'mass_email_api_key' => 'sg-secret',
            'mass_email_sending_domain' => 'mail.example.test',
            'mass_email_webhook_secret' => 'whsec-secret',
            'mass_email_from_name' => 'Planify',
            'mass_email_from_email' => 'no-reply@example.test',
            'mass_email_reply_to' => 'reply@example.test',
            'mass_email_batch_size' => 250,
            'mass_email_rate_limit' => 1500,
            'mass_email_unsubscribe_footer' => 'Unsubscribe: {{unsubscribeUrl}} | {{physicalAddress}}',
            'mass_email_physical_address' => '123 Test St',
            'mass_email_retry_attempts' => 4,
            'mass_email_retry_backoff' => '60,300',
        ];

        $response = $this->actingAs($admin)->patch(route('settings.mail.update'), $payload);
        $response->assertRedirect(route('settings.email'));

        $stored = Setting::forGroup('mass_email');
        $this->assertSame('sendgrid', $stored['provider'] ?? null);
        $this->assertSame('sg-secret', $stored['api_key'] ?? null);
        $this->assertSame('mail.example.test', $stored['sending_domain'] ?? null);
        $this->assertSame('whsec-secret', $stored['webhook_secret'] ?? null);
        $this->assertSame('Planify', $stored['from_name'] ?? null);
        $this->assertSame('no-reply@example.test', $stored['from_email'] ?? null);
        $this->assertSame('reply@example.test', $stored['reply_to'] ?? null);
        $this->assertSame('250', $stored['batch_size'] ?? null);
        $this->assertSame('1500', $stored['rate_limit_per_minute'] ?? null);
        $this->assertSame('Unsubscribe: {{unsubscribeUrl}} | {{physicalAddress}}', $stored['unsubscribe_footer'] ?? null);
        $this->assertSame('123 Test St', $stored['physical_address'] ?? null);
        $this->assertSame('4', $stored['retry_attempts'] ?? null);
        $this->assertSame('60,300', $stored['retry_backoff_seconds'] ?? null);
    }

    public function test_admin_can_opt_out_subscriber(): void
    {
        $admin = $this->createManagerWithPermission('settings.manage');
        $subscriber = \App\Models\EmailSubscriber::query()->create(['email' => 'optout@example.com']);

        $response = $this->actingAs($admin)->patch(route('email.subscribers.update', ['subscriber' => $subscriber->id]), [
            'marketing_status' => 'opt_out',
            'list_id' => '',
            'list_status' => '',
        ]);

        $response->assertRedirect(route('email.subscribers.show', ['subscriber' => $subscriber->id]));
        $this->assertNotNull($subscriber->fresh()->marketing_unsubscribed_at);
    }

    public function test_admin_can_bulk_opt_out_subscribers(): void
    {
        $admin = $this->createManagerWithPermission('settings.manage');
        $subscriberOne = \App\Models\EmailSubscriber::query()->create(['email' => 'bulk1@example.com']);
        $subscriberTwo = \App\Models\EmailSubscriber::query()->create(['email' => 'bulk2@example.com']);

        $response = $this->actingAs($admin)->patch(route('email.subscribers.bulk'), [
            'subscriber_ids' => [$subscriberOne->id, $subscriberTwo->id],
            'action' => 'marketing',
            'marketing_status' => 'opt_out',
            'list_id' => '',
            'list_status' => '',
        ]);

        $response->assertRedirect(route('email.subscribers.index'));
        $this->assertNotNull($subscriberOne->fresh()->marketing_unsubscribed_at);
        $this->assertNotNull($subscriberTwo->fresh()->marketing_unsubscribed_at);
    }

    public function test_admin_can_bulk_update_list_status(): void
    {
        $admin = $this->createManagerWithPermission('settings.manage');
        $subscriber = \App\Models\EmailSubscriber::query()->create(['email' => 'listbulk@example.com']);
        $list = \App\Models\EmailList::query()->create([
            'type' => \App\Models\EmailList::TYPE_GLOBAL,
            'name' => 'Global Updates',
            'key' => 'GLOBAL_TEST',
        ]);

        \App\Models\EmailSubscription::query()->create([
            'subscriber_id' => $subscriber->id,
            'list_id' => $list->id,
            'status' => 'pending',
        ]);

        $response = $this->actingAs($admin)->patch(route('email.subscribers.bulk'), [
            'subscriber_ids' => [$subscriber->id],
            'action' => 'list',
            'marketing_status' => '',
            'list_id' => $list->id,
            'list_status' => 'subscribed',
        ]);

        $response->assertRedirect(route('email.subscribers.index'));
        $this->assertDatabaseHas('email_subscriptions', [
            'subscriber_id' => $subscriber->id,
            'list_id' => $list->id,
            'status' => 'subscribed',
        ]);
    }

    public function test_admin_can_add_and_remove_subscriber_from_list(): void
    {
        $admin = $this->createManagerWithPermission('settings.manage');
        $list = \App\Models\EmailList::query()->create([
            'type' => \App\Models\EmailList::TYPE_GLOBAL,
            'name' => 'Global Updates',
            'key' => 'GLOBAL_TEST',
        ]);

        $response = $this->actingAs($admin)->post(route('email.subscribers.add'), [
            'email' => 'newlist@example.com',
            'first_name' => 'New',
            'last_name' => 'List',
            'list_id' => $list->id,
            'intent' => 'subscribe',
        ]);

        $response->assertRedirect(route('email.subscribers.index'));

        $subscriber = \App\Models\EmailSubscriber::query()->where('email', 'newlist@example.com')->first();
        $this->assertNotNull($subscriber);
        $this->assertDatabaseHas('email_subscriptions', [
            'subscriber_id' => $subscriber->id,
            'list_id' => $list->id,
            'status' => 'subscribed',
        ]);

        $removeResponse = $this->actingAs($admin)->delete(route('email.subscribers.remove_list', [
            'subscriber' => $subscriber->id,
            'list' => $list->id,
        ]));

        $removeResponse->assertRedirect(route('email.subscribers.show', ['subscriber' => $subscriber->id]));
        $this->assertDatabaseMissing('email_subscriptions', [
            'subscriber_id' => $subscriber->id,
            'list_id' => $list->id,
        ]);
    }

    public function test_event_admin_can_add_and_remove_event_list_subscriber(): void
    {
        $owner = User::factory()->create();
        $event = Event::factory()->create(['user_id' => $owner->id]);
        $role = Role::factory()->create();

        $list = app(EmailListService::class)->getEventList($event);

        $addResponse = $this->actingAs($owner)->post(route('event.email.subscribers.update', [
            'subdomain' => $role->subdomain,
            'hash' => \App\Utils\UrlUtils::encodeId($event->id),
        ]), [
            'action' => 'add',
            'email' => 'eventlist@example.com',
            'first_name' => 'Event',
            'last_name' => 'Subscriber',
            'intent' => 'subscribe',
        ]);

        $addResponse->assertRedirect(route('event.email.index', [
            'subdomain' => $role->subdomain,
            'hash' => \App\Utils\UrlUtils::encodeId($event->id),
        ]));

        $subscription = \App\Models\EmailSubscription::query()
            ->where('list_id', $list->id)
            ->whereHas('subscriber', function ($query) {
                $query->where('email', 'eventlist@example.com');
            })
            ->first();

        $this->assertNotNull($subscription);

        $removeResponse = $this->actingAs($owner)->post(route('event.email.subscribers.update', [
            'subdomain' => $role->subdomain,
            'hash' => \App\Utils\UrlUtils::encodeId($event->id),
        ]), [
            'action' => 'remove',
            'subscription_id' => $subscription->id,
        ]);

        $removeResponse->assertRedirect(route('event.email.index', [
            'subdomain' => $role->subdomain,
            'hash' => \App\Utils\UrlUtils::encodeId($event->id),
        ]));

        $this->assertDatabaseMissing('email_subscriptions', [
            'id' => $subscription->id,
        ]);
    }

    public function test_admin_can_manage_suppressions(): void
    {
        $admin = $this->createManagerWithPermission('settings.manage');

        $response = $this->actingAs($admin)->post(route('email.suppressions.store'), [
            'email' => 'suppressed@example.com',
            'reason' => 'manual',
        ]);

        $response->assertRedirect(route('email.suppressions.index'));
        $this->assertDatabaseHas('email_suppressions', [
            'email' => 'suppressed@example.com',
            'reason' => 'manual',
        ]);

        $suppression = \App\Models\EmailSuppression::query()->where('email', 'suppressed@example.com')->first();
        $this->assertNotNull($suppression);

        $deleteResponse = $this->actingAs($admin)->delete(route('email.suppressions.destroy', [
            'suppression' => $suppression->id,
        ]));

        $deleteResponse->assertRedirect(route('email.suppressions.index'));
        $this->assertDatabaseMissing('email_suppressions', [
            'id' => $suppression->id,
        ]);
    }

    public function test_admin_can_save_global_template_from_campaign(): void
    {
        $admin = $this->createManagerWithPermission('settings.manage');

        $response = $this->actingAs($admin)->post(route('email.store'), [
            'subject' => 'Template Subject',
            'from_name' => 'Planify',
            'from_email' => 'no-reply@example.test',
            'reply_to' => '',
            'email_type' => 'marketing',
            'content_markdown' => 'Hello {{firstName}}',
            'scheduled_at' => null,
            'action' => 'draft',
            'save_template' => true,
            'template_name' => 'Global Template',
        ]);

        $response->assertRedirect();
        $this->assertDatabaseHas('email_campaign_templates', [
            'name' => 'Global Template',
            'scope' => \App\Models\EmailCampaignTemplate::SCOPE_GLOBAL,
        ]);
    }

    public function test_event_admin_can_save_event_template_from_campaign(): void
    {
        $owner = User::factory()->create();
        $event = Event::factory()->create(['user_id' => $owner->id]);
        $role = Role::factory()->create();

        $response = $this->actingAs($owner)->post(route('event.email.store', [
            'subdomain' => $role->subdomain,
            'hash' => \App\Utils\UrlUtils::encodeId($event->id),
        ]), [
            'subject' => 'Event Template',
            'from_name' => 'Planify',
            'from_email' => 'no-reply@example.test',
            'reply_to' => '',
            'email_type' => 'marketing',
            'content_markdown' => 'Hello {{firstName}}',
            'scheduled_at' => null,
            'action' => 'draft',
            'save_template' => true,
            'template_name' => 'Event Template',
        ]);

        $response->assertRedirect();
        $this->assertDatabaseHas('email_campaign_templates', [
            'name' => 'Event Template',
            'scope' => \App\Models\EmailCampaignTemplate::SCOPE_EVENT,
            'event_id' => $event->id,
        ]);
    }

    public function test_admin_can_export_subscribers(): void
    {
        $admin = $this->createManagerWithPermission('settings.manage');
        $list = \App\Models\EmailList::query()->create([
            'type' => \App\Models\EmailList::TYPE_GLOBAL,
            'name' => 'Global Updates',
            'key' => 'GLOBAL_EXPORT',
        ]);

        $subscriber = \App\Models\EmailSubscriber::query()->create(['email' => 'export@example.com']);
        \App\Models\EmailSubscription::query()->create([
            'subscriber_id' => $subscriber->id,
            'list_id' => $list->id,
            'status' => 'subscribed',
        ]);

        $response = $this->actingAs($admin)->get(route('email.subscribers.export', ['format' => 'csv', 'list_id' => $list->id]));

        $response->assertStatus(200);
        $this->assertStringContainsString('text/csv', $response->headers->get('Content-Type'));
    }

    public function test_event_admin_can_export_event_subscribers(): void
    {
        $owner = User::factory()->create();
        $event = Event::factory()->create(['user_id' => $owner->id]);
        $role = Role::factory()->create();

        $list = app(EmailListService::class)->getEventList($event);
        $subscriber = \App\Models\EmailSubscriber::query()->create(['email' => 'eventexport@example.com']);
        \App\Models\EmailSubscription::query()->create([
            'subscriber_id' => $subscriber->id,
            'list_id' => $list->id,
            'status' => 'subscribed',
        ]);

        $response = $this->actingAs($owner)->get(route('event.email.export', [
            'subdomain' => $role->subdomain,
            'hash' => \App\Utils\UrlUtils::encodeId($event->id),
            'format' => 'csv',
        ]));

        $response->assertStatus(200);
        $this->assertStringContainsString('text/csv', $response->headers->get('Content-Type'));
    }

    public function test_admin_can_validate_sendgrid_provider_settings(): void
    {
        Http::fake([
            'https://api.sendgrid.com/v3/scopes' => Http::response(['scopes' => []], 200),
            'https://api.sendgrid.com/v3/verified_senders' => Http::response([
                'results' => [
                    ['from_email' => 'no-reply@example.test'],
                ],
            ], 200),
        ]);

        $admin = $this->createManagerWithPermission('settings.manage');

        $response = $this->actingAs($admin)->post(route('settings.mail.mass_email.test'), [
            'mass_email_provider' => 'sendgrid',
            'mass_email_api_key' => 'sg-test-key',
            'mass_email_sending_domain' => '',
            'mass_email_webhook_secret' => '',
            'mass_email_webhook_public_key' => '',
            'mass_email_from_name' => 'Planify',
            'mass_email_from_email' => 'no-reply@example.test',
            'mass_email_reply_to' => '',
            'mass_email_batch_size' => 100,
            'mass_email_rate_limit' => 1000,
            'mass_email_unsubscribe_footer' => '',
            'mass_email_physical_address' => '',
            'mass_email_retry_attempts' => 3,
            'mass_email_retry_backoff' => '60,300',
            'mass_email_sendgrid_unsubscribe_group_id' => '',
        ]);

        $response->assertOk();
        $response->assertJson(['status' => 'success']);
    }

    public function test_admin_can_validate_mailgun_provider_settings(): void
    {
        Http::fake([
            'https://api.mailgun.net/v3/domains/example.test' => Http::response([
                'domain' => ['state' => 'active'],
            ], 200),
        ]);

        $admin = $this->createManagerWithPermission('settings.manage');

        $response = $this->actingAs($admin)->post(route('settings.mail.mass_email.test'), [
            'mass_email_provider' => 'mailgun',
            'mass_email_api_key' => 'mg-test-key',
            'mass_email_sending_domain' => 'example.test',
            'mass_email_webhook_secret' => 'whsec',
            'mass_email_webhook_public_key' => '',
            'mass_email_from_name' => 'Planify',
            'mass_email_from_email' => 'no-reply@example.test',
            'mass_email_reply_to' => '',
            'mass_email_batch_size' => 100,
            'mass_email_rate_limit' => 1000,
            'mass_email_unsubscribe_footer' => '',
            'mass_email_physical_address' => '',
            'mass_email_retry_attempts' => 3,
            'mass_email_retry_backoff' => '60,300',
            'mass_email_sendgrid_unsubscribe_group_id' => '',
        ]);

        $response->assertOk();
        $response->assertJson(['status' => 'success']);
    }

    public function test_admin_can_validate_mailchimp_provider_settings(): void
    {
        Http::fake([
            'https://mandrillapp.com/api/1.0/users/ping.json' => Http::response('PONG!', 200),
            'https://mandrillapp.com/api/1.0/senders/list.json' => Http::response([
                [
                    'email' => 'no-reply@example.test',
                    'domain' => 'example.test',
                    'status' => 'verified',
                ],
            ], 200),
        ]);

        $admin = $this->createManagerWithPermission('settings.manage');

        $response = $this->actingAs($admin)->post(route('settings.mail.mass_email.test'), [
            'mass_email_provider' => 'mailchimp',
            'mass_email_api_key' => 'mc-test-key',
            'mass_email_sending_domain' => '',
            'mass_email_webhook_secret' => '',
            'mass_email_webhook_public_key' => '',
            'mass_email_from_name' => 'Planify',
            'mass_email_from_email' => 'no-reply@example.test',
            'mass_email_reply_to' => '',
            'mass_email_batch_size' => 100,
            'mass_email_rate_limit' => 1000,
            'mass_email_unsubscribe_footer' => '',
            'mass_email_physical_address' => '',
            'mass_email_retry_attempts' => 3,
            'mass_email_retry_backoff' => '60,300',
            'mass_email_sendgrid_unsubscribe_group_id' => '',
        ]);

        $response->assertOk();
        $response->assertJson(['status' => 'success']);
    }

    public function test_settings_email_page_includes_provider_hints(): void
    {
        $admin = $this->createManagerWithPermission('settings.manage');

        $response = $this->actingAs($admin)->get(route('settings.email'));

        $response->assertStatus(200);
        $response->assertSeeText('Requires a SendGrid API key');
        $response->assertSeeText('Requires a Mailgun API key and verified sending domain.');
        $response->assertSeeText('Uses Mailchimp Transactional (Mandrill) API key.');
        $response->assertSeeText('Uses the configured SMTP mailer settings above.');
    }

    public function test_settings_email_page_contains_provider_visibility_flags(): void
    {
        $admin = $this->createManagerWithPermission('settings.manage');

        $response = $this->actingAs($admin)->get(route('settings.email'));

        $response->assertStatus(200);
        $response->assertSee('x-show="mailer === \'smtp\'"', false);
        $response->assertSee('x-show="massProvider !== \'laravel_mail\'"', false);
        $response->assertSee('x-show="massProvider === \'sendgrid\'"', false);
        $response->assertSee('x-show="massProvider === \'mailgun\'"', false);
    }

    protected function createManagerWithPermission(string $permissionKey): User
    {
        $permission = Permission::query()->firstOrCreate(
            ['key' => $permissionKey],
            ['description' => 'Test permission']
        );

        $role = SystemRole::query()->firstOrCreate(['slug' => 'admin'], ['name' => 'Admin']);
        $role->permissions()->syncWithoutDetaching([$permission->id]);

        $user = User::factory()->create();
        $user->systemRoles()->attach($role);

        app(AuthorizationService::class)->warmUserPermissions($user);

        return $user;
    }
}
