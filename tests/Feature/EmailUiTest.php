<?php

namespace Tests\Feature;

use App\Models\Permission;
use App\Models\SystemRole;
use App\Models\User;
use App\Models\Event;
use App\Models\Role;
use App\Models\Setting;
use App\Services\Authorization\AuthorizationService;
use Illuminate\Foundation\Testing\RefreshDatabase;
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
            'mail_from_name' => 'EventSchedule',
            'mail_disable_delivery' => false,
            'mass_email_provider' => 'sendgrid',
            'mass_email_api_key' => 'sg-secret',
            'mass_email_sending_domain' => 'mail.example.test',
            'mass_email_webhook_secret' => 'whsec-secret',
            'mass_email_from_name' => 'EventSchedule',
            'mass_email_from_email' => 'no-reply@example.test',
            'mass_email_reply_to' => 'reply@example.test',
            'mass_email_batch_size' => 250,
            'mass_email_rate_limit' => 1500,
        ];

        $response = $this->actingAs($admin)->patch(route('settings.mail.update'), $payload);
        $response->assertRedirect(route('settings.email'));

        $stored = Setting::forGroup('mass_email');
        $this->assertSame('sendgrid', $stored['provider'] ?? null);
        $this->assertSame('sg-secret', $stored['api_key'] ?? null);
        $this->assertSame('mail.example.test', $stored['sending_domain'] ?? null);
        $this->assertSame('whsec-secret', $stored['webhook_secret'] ?? null);
        $this->assertSame('EventSchedule', $stored['from_name'] ?? null);
        $this->assertSame('no-reply@example.test', $stored['from_email'] ?? null);
        $this->assertSame('reply@example.test', $stored['reply_to'] ?? null);
        $this->assertSame('250', $stored['batch_size'] ?? null);
        $this->assertSame('1500', $stored['rate_limit_per_minute'] ?? null);
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
