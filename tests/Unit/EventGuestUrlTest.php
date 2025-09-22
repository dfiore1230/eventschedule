<?php

namespace Tests\Unit;

use App\Models\Event;
use App\Models\Role;
use App\Models\User;
use App\Repos\EventRepo;
use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class EventGuestUrlTest extends TestCase
{
    use RefreshDatabase;

    public function test_guest_urls_prefer_event_slug_and_support_legacy_role_links(): void
    {
        config([
            'app.hosted' => false,
            'app.timezone' => 'UTC',
        ]);

        $user = User::factory()->create();

        $venue = new Role([
            'type' => 'venue',
            'name' => 'Legacy Venue',
            'email' => 'venue@example.com',
            'timezone' => 'UTC',
        ]);
        $venue->subdomain = 'legacy-venue';
        $venue->user_id = $user->id;
        $venue->email_verified_at = now();
        $venue->save();

        $talent = new Role([
            'type' => 'talent',
            'name' => 'Legacy Talent',
            'email' => 'talent@example.com',
            'timezone' => 'UTC',
        ]);
        $talent->subdomain = 'legacy-talent';
        $talent->user_id = $user->id;
        $talent->email_verified_at = now();
        $talent->save();

        $event = new Event([
            'name' => 'Slugged Event',
            'slug' => 'slugged-event',
            'starts_at' => Carbon::now()->addDay()->setTimezone('UTC')->format('Y-m-d H:i:s'),
            'duration' => 60,
        ]);
        $event->user_id = $user->id;
        $event->creator_role_id = $talent->id;
        $event->save();

        $event->roles()->attach($venue->id, ['is_accepted' => true]);
        $event->roles()->attach($talent->id, ['is_accepted' => true]);

        $event = $event->fresh(['roles']);

        $urlData = $event->getGuestUrlData();

        $this->assertSame('slugged-event', $urlData['slug']);
        $this->assertSame($talent->subdomain, $urlData['subdomain']);

        $guestUrl = $event->getGuestUrl();
        $this->assertStringContainsString('/' . $urlData['subdomain'] . '/' . $urlData['slug'], $guestUrl);

        $eventRepo = new EventRepo();

        $resolvedBySlug = $eventRepo->getEvent($urlData['subdomain'], $urlData['slug']);
        $this->assertNotNull($resolvedBySlug);
        $this->assertTrue($event->is($resolvedBySlug));

        $legacyResolved = $eventRepo->getEvent($venue->subdomain, $talent->subdomain);
        $this->assertNotNull($legacyResolved);
        $this->assertTrue($event->is($legacyResolved));
    }
}
