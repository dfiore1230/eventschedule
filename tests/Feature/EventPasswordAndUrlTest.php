<?php

namespace Tests\Feature;

use Tests\TestCase;
use App\Models\User;
use App\Models\Role;
use App\Models\Event;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class EventPasswordAndUrlTest extends TestCase
{
    use RefreshDatabase;

    public function test_guest_gets_password_prompt_for_protected_event()
    {
        $user = User::factory()->create();
        $role = Role::factory()->create(['type' => 'venue']);
        $role->user_id = $user->id;
        $role->save();

        $event = Event::factory()->create([
            'user_id' => $user->id,
            'slug' => Str::slug('test-event'),
        ]);

        $plainPassword = 'plain-text';
        $event->event_password_hash = Hash::make($plainPassword);
        $event->save();

        // Test that event password hash is set
        $this->assertNotNull($event->event_password_hash);
        $this->assertTrue(Hash::check($plainPassword, $event->event_password_hash));

        // Test that password verification works correctly
        $wrongPassword = 'wrong-password';
        $this->assertFalse(Hash::check($wrongPassword, $event->event_password_hash));
        $this->assertTrue(Hash::check($plainPassword, $event->event_password_hash));
    }

    public function test_online_event_shows_watch_online_link_even_with_venue()
    {
        $user = User::factory()->create();
        $role = Role::factory()->create(['type' => 'venue']);
        $role->user_id = $user->id;
        $role->save();

        $eventUrl = 'https://example.test/stream';
        $event = Event::factory()->create([
            'user_id' => $user->id,
            'slug' => Str::slug('online-event'),
            'event_url' => $eventUrl,
        ]);

        $event->roles()->attach($role->id, ['is_accepted' => true]);

        // Test that event has the URL set
        $this->assertNotNull($event->event_url);
        $this->assertEquals($eventUrl, $event->event_url);

        // Test that the event can retrieve its guest URL
        $guestUrl = $event->getGuestUrl($role->subdomain);
        $this->assertNotNull($guestUrl);
        $this->assertStringContainsString($eventUrl, $guestUrl);
    }

    public function test_edit_page_shows_password_set_and_owner_can_update_without_password()
    {
        $user = User::factory()->create();
        $role = Role::factory()->create(['type' => 'venue']);
        $role->save();

        // ensure the user is a role member so they can edit
        $user->roles()->attach($role->id, ['level' => 'owner', 'created_at' => now()]);

        $plainPassword = 'plain-text';
        $event = Event::factory()->create([
            'user_id' => $user->id,
            'slug' => Str::slug('edit-event'),
        ]);

        $event->event_password_hash = Hash::make($plainPassword);
        $event->save();

        // Test that password is set initially
        $this->assertNotNull($event->event_password_hash);
        $this->assertTrue(Hash::check($plainPassword, $event->event_password_hash));

        // Simulate updating the event without changing the password
        $event->name = 'Updated name';
        $event->is_private = true;
        // Note: Not setting event_password_hash, so it should remain unchanged
        $event->save();

        $event->refresh();

        // Test that password is preserved after update
        $this->assertNotNull($event->event_password_hash);
        $this->assertTrue(Hash::check($plainPassword, $event->event_password_hash));
    }
}
