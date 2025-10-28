<?php

namespace Tests\Feature;

use App\Models\Role;
use App\Models\User;
use App\Repos\EventRepo;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Notification;
use Tests\TestCase;

class EventRepoTest extends TestCase
{
    use RefreshDatabase;

    public function test_save_event_allows_editing_existing_event(): void
    {
        Mail::fake();
        Notification::fake();

        $user = User::factory()->create();

        $role = Role::create([
            'user_id' => $user->id,
            'subdomain' => 'test-role',
            'type' => 'talent',
            'background' => 'gradient',
            'accent_color' => '#007bff',
            'background_colors' => json_encode(['#000000', '#ffffff']),
            'background_rotation' => 0,
            'font_color' => '#ffffff',
            'font_family' => 'Roboto',
            'name' => 'Test Role',
            'email' => 'role@example.com',
            'timezone' => 'America/New_York',
            'language_code' => 'en',
            'country_code' => 'US',
        ]);

        $role->users()->attach($user->id, ['level' => 'owner']);
        $this->actingAs($user);

        /** @var EventRepo $repo */
        $repo = app(EventRepo::class);

        $createRequest = Request::create('/events', 'POST', [
            'name' => 'Original Event',
            'schedule_type' => 'single',
            'starts_at' => '2024-10-10 12:00:00',
            'tickets_enabled' => '0',
            'members' => [],
            'curators' => [],
            'curator_groups' => [],
        ]);
        $createRequest->setUserResolver(fn () => $user);
        app()->instance('request', $createRequest);

        $event = $repo->saveEvent($role, $createRequest);

        $this->assertNotNull($event->id);
        $this->assertSame('Original Event', $event->name);

        $updateRequest = Request::create('/events', 'POST', [
            'name' => 'Updated Event',
            'slug' => $event->slug,
            'schedule_type' => 'single',
            'starts_at' => '2024-11-11 15:00:00',
            'tickets_enabled' => '0',
            'members' => [],
            'curators' => [],
            'curator_groups' => [],
        ]);
        $updateRequest->setUserResolver(fn () => $user);
        app()->instance('request', $updateRequest);

        $updatedEvent = $repo->saveEvent($role, $updateRequest, $event);

        $this->assertSame('Updated Event', $updatedEvent->fresh()->name);
    }
}
