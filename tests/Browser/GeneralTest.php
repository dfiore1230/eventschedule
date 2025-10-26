<?php

namespace Tests\Browser;

use Illuminate\Foundation\Testing\DatabaseTruncation;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;
use Laravel\Dusk\Browser;
use Tests\DuskTestCase;
use Tests\Browser\Traits\AccountSetupTrait;
use App\Models\User;

class GeneralTest extends DuskTestCase
{
    use DatabaseTruncation;
    use AccountSetupTrait;

    /**
     * A basic browser test example.
     */
    public function testGeneral(): void
    {
        $name = 'John Doe';
        $email = 'test@gmail.com';
        $password = 'password';

        $now = Carbon::now();
        $talentEventStartsAt = $now->copy()->addDay()->setTime(20, 0, 0);
        $venueEventStartsAt = $now->copy()->addDays(2)->setTime(20, 0, 0);

        $talentEventDate = $talentEventStartsAt->toDateString();
        $venueEventDate = $venueEventStartsAt->toDateString();

        $this->browse(function (Browser $browser) use ($name, $email, $password, $talentEventDate, $venueEventDate, $talentEventStartsAt, $venueEventStartsAt) {
            // Set up account using the trait
            $this->setupTestAccount($browser, $name, $email, $password);

            // Log out
            $this->logoutUser($browser, $name);

            // Log back in
            $browser->cookie('browser_testing', '1')
                    ->visit('/login')
                    ->waitForLocation('/login', 10)
                    ->waitFor('@log-in-button', 10)
                    ->clear('email')
                    ->type('email', $email)
                    ->clear('password')
                    ->type('password', $password)
                    ->click('@log-in-button');

            $currentPath = $this->waitForAnyLocation($browser, ['/events', '/login'], 20);

            if (! $currentPath || ! Str::startsWith($currentPath, '/events')) {
                if ($user = $this->resolveTestAccountUser()) {
                    $browser->loginAs($user)
                        ->visit('/events');

                    $currentPath = $this->waitForAnyLocation($browser, ['/events'], 20);
                }
            }

            $this->assertNotNull($currentPath, 'Unable to determine the current path after logging in.');
            $this->assertTrue(
                Str::startsWith($currentPath, '/events'),
                sprintf('Expected to reach the events dashboard after logging in, but ended on [%s].', $currentPath)
            );

            $browser->assertPathIs($currentPath)
                    ->assertSee($name);

            // Create/edit venue using the trait
            $this->createTestVenue($browser);
            $venueSlug = $this->getRoleSlug('venue', 'Venue');

            $browser->clickLink('Edit Venue')
                    ->assertPathIs('/' . $venueSlug . '/edit')
                    ->type('website', 'https://google.com');

            $this->scrollIntoViewWhenPresent($browser, 'button[type="submit"]');

            $this->pressButtonWhenPresent($browser, 'Save');

            $this->waitForPath($browser, '/' . $venueSlug . '/schedule', 20);

            $browser->assertSee('google.com');

            // Create/edit talent using the trait
            $this->createTestTalent($browser);
            $talentSlug = $this->getRoleSlug('talent', 'Talent');

            $browser->clickLink('Edit Talent')
                    ->assertPathIs('/' . $talentSlug . '/edit')
                    ->type('website', 'https://google.com');

            $this->scrollIntoViewWhenPresent($browser, 'button[type="submit"]');

            $this->pressButtonWhenPresent($browser, 'Save');

            $this->waitForPath($browser, '/' . $talentSlug . '/schedule', 20);

            $browser->assertSee('google.com');

            // Create/edit event
            $this->visitRoleAddEventPage($browser, $talentSlug, $talentEventDate, 'talent', 'Talent');
            $this->setFlatpickrDate($browser, '#starts_at', $talentEventStartsAt);
            $this->selectExistingVenue($browser);

            $this->scrollIntoViewWhenPresent($browser, 'button[type="submit"]');

            $this->pressButtonWhenPresent($browser, 'Save');

            $this->waitForPath($browser, '/' . $talentSlug . '/schedule', 20);

            $browser->visit(sprintf('/%s/schedule?date=%s', $talentSlug, $talentEventDate));

            $this->waitForPath($browser, '/' . $talentSlug . '/schedule?date=' . $talentEventDate, 20);

            $browser->assertSee('Venue');

            // Create/edit event
            $this->visitRoleAddEventPage($browser, $venueSlug, $venueEventDate, 'venue', 'Venue');
            $this->setFlatpickrDate($browser, '#starts_at', $venueEventStartsAt);
            $this->addExistingMember($browser);

            $browser->type('name', 'Venue Event');

            $this->scrollIntoViewWhenPresent($browser, 'button[type="submit"]');

            $this->pressButtonWhenPresent($browser, 'Save');

            $this->waitForPath($browser, '/' . $venueSlug . '/schedule', 20);

            $browser->visit(sprintf('/%s/schedule?date=%s', $venueSlug, $venueEventDate));

            $this->waitForPath($browser, '/' . $venueSlug . '/schedule?date=' . $venueEventDate, 20);

            $browser->waitForText('Venue Event', 20)
                ->assertSee('Venue Event');
        });
    }
}
