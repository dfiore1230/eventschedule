<?php

namespace Tests\Feature;

use App\Models\Event;
use App\Models\EventInvite;
use App\Models\User;
use App\Notifications\EventInviteNotification;
use App\Utils\UrlUtils;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Notification;
use Illuminate\Support\Str;
use Tests\TestCase;

class EventInvitesTest extends TestCase
{
    use RefreshDatabase;

    public function test_event_invites_can_be_sent(): void
    {
        Notification::fake();

        $user = User::factory()->create();
        $event = Event::factory()->create(['user_id' => $user->id]);

        $response = $this->actingAs($user)->post(route('event.invites.send', [
            'hash' => UrlUtils::encodeId($event->id),
        ]), [
            'invite_emails' => "first@example.com, second@example.com\nthird@example.com",
        ]);

        $response->assertRedirect();

        $this->assertSame(3, EventInvite::where('event_id', $event->id)->count());
        Notification::assertSentOnDemandTimes(EventInviteNotification::class, 3);
    }

    public function test_private_event_invite_is_single_use(): void
    {
        $event = Event::factory()->create([
            'event_password_hash' => Hash::make('secret'),
        ]);

        $invite = EventInvite::create([
            'event_id' => $event->id,
            'email' => 'guest@example.com',
            'token' => Str::random(40),
        ]);

        $subdomain = 'demo';

        $response = $this->get(route('event.invite', [
            'subdomain' => $subdomain,
            'token' => $invite->token,
        ]));

        $response->assertRedirect($event->getGuestUrl($subdomain));
        $invite->refresh();
        $this->assertNotNull($invite->used_at);

        $response = $this->get(route('event.invite', [
            'subdomain' => $subdomain,
            'token' => $invite->token,
        ]));

        $response->assertRedirect($event->getGuestUrl($subdomain));
        $response->assertSessionHas('error', __('messages.invite_already_used'));
    }

    public function test_public_event_invite_is_reusable(): void
    {
        $event = Event::factory()->create([
            'event_password_hash' => null,
        ]);

        $invite = EventInvite::create([
            'event_id' => $event->id,
            'email' => 'guest@example.com',
            'token' => Str::random(40),
        ]);

        $subdomain = 'demo';

        $response = $this->get(route('event.invite', [
            'subdomain' => $subdomain,
            'token' => $invite->token,
        ]));

        $response->assertRedirect($event->getGuestUrl($subdomain));
        $invite->refresh();
        $this->assertNull($invite->used_at);

        $response = $this->get(route('event.invite', [
            'subdomain' => $subdomain,
            'token' => $invite->token,
        ]));

        $response->assertRedirect($event->getGuestUrl($subdomain));
        $response->assertSessionMissing('error');
    }
}
