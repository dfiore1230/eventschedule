<?php

namespace Tests\Feature;

use App\Models\Event;
use App\Models\User;
use App\Models\Role;
use App\Http\Middleware\EnsureAbility;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;
use App\Utils\UrlUtils;

class ApiEventNotificationSettingsTest extends TestCase
{
    use RefreshDatabase;

    public function test_can_fetch_notification_settings_and_templates(): void
    {
        $user = User::factory()->create();
        $event = Event::factory()->create(['user_id' => $user->id]);

        $this->withoutMiddleware();

        $response = $this->actingAs($user)
            ->getJson('/api/events/' . UrlUtils::encodeId($event->id) . '/notifications');

        $response->assertStatus(200)
            ->assertJsonStructure([
                'data' => [
                    'settings',
                    'templates',
                ],
            ]);
    }

    public function test_can_update_notification_settings_via_api(): void
    {
        $user = User::factory()->create();
        $event = Event::factory()->create(['user_id' => $user->id]);
        $role = Role::factory()->create(['type' => 'talent']);
        $event->roles()->attach($role->id, ['is_accepted' => true]);

        $this->withoutMiddleware();

        $payload = [
            'notification_settings' => [
                'channels' => [
                    'event_added' => ['mail' => false],
                ],
                'templates' => [
                    'event_added' => [
                        'subject' => 'Custom event added',
                    ],
                ],
            ],
        ];

        $response = $this->actingAs($user)
            ->patchJson('/api/events/' . UrlUtils::encodeId($event->id) . '/notifications', $payload);

        $response->assertStatus(200)
            ->assertJsonPath('data.settings.channels.event_added.mail', false)
            ->assertJsonPath('data.settings.templates.event_added.subject', 'Custom event added');
    }
}
