<?php

namespace Tests\Browser;

use Illuminate\Foundation\Testing\DatabaseTruncation;
use Laravel\Dusk\Browser;
use Tests\DuskTestCase;
use Tests\Browser\Traits\AccountSetupTrait;
use App\Models\User;

class TicketTest extends DuskTestCase
{
    use DatabaseTruncation;
    use AccountSetupTrait;

    /**
     * A basic test for ticket functionality.
     */
    public function testBasicTicketFunctionality(): void
    {
        $name = 'John Doe';
        $email = 'test@gmail.com';
        $password = 'password';

        $this->browse(function (Browser $browser) use ($name, $email, $password) {
            // Set up account using the trait
            $this->setupTestAccount($browser, $name, $email, $password);
            
            // Create test data using the trait
            $this->createTestVenue($browser);
            $this->createTestTalent($browser);
            $this->createTestEventWithTickets($browser);

            $talentSlug = $this->getRoleSlug('talent', 'Talent');

            // Purchase ticket
            $browser->visit('/' . $talentSlug . '/venue')
                    ->click('@buy-tickets-button')
                    ->select('#ticket-0', '1')
                    ->scrollIntoView('button[type="submit"]')
                    ->click('@checkout-button')
                    ->waitForText(__('messages.number_of_attendees'), 5)
                    ->assertSee($name);
        });
    }
}
