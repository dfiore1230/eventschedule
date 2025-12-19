<?php

namespace App\Http\Controllers\Test;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\Role;
use App\Models\Event;
use App\Models\Sale;
use App\Models\SaleTicketEntry;

class TestHelpersController extends Controller
{
    public function seedE2eData(Request $request)
    {
        if (! app()->environment(['local', 'testing'])) {
            return response()->json(['error' => 'Not allowed'], 403);
        }

        try {
            $venue = Role::factory()->create(['type' => 'venue']);

            // create a batch of events to support pagination tests
            $events = [];
            $createdEventObjects = [];
            $baseDate = now()->startOfMonth()->addDays(1)->setTime(18, 0);
            for ($i = 1; $i <= 15; $i++) {
                $dt = $baseDate->copy()->addDays($i % 28);
                $ev = Event::factory()->create([
                    'starts_at' => $dt,
                    'name' => "E2E Event {$i}",
                ]);

                // Attach the venue relationship via the event_role pivot (migrations
                // may remove the `venue_id` column from `events`). This keeps the
                // seeding compatible with either schema.
                try {
                    $ev->roles()->attach($venue->id, ['is_accepted' => true]);
                } catch (\Throwable $e) {
                    // If attaching fails (older schema that still has columns), set
                    // the column directly as a fallback.
                    try { $ev->venue_id = $venue->id; $ev->save(); } catch (\Throwable $_) {}
                }

                $createdEventObjects[] = $ev;
                $events[] = [
                    'id' => $ev->id,
                    'name' => $ev->translatedName(),
                    'starts_at' => $ev->starts_at ? $ev->getStartDateTime(null, true) : null,
                    'guest_url' => $ev->getGuestUrl(false, true),
                ];
            }

            $recurring = Event::factory()->create([
                'days_of_week' => '0100000', // Monday
                'name' => 'E2E Recurring',
            ]);

            try {
                $recurring->roles()->attach($venue->id, ['is_accepted' => true]);
            } catch (\Throwable $e) {
                try { $recurring->venue_id = $venue->id; $recurring->save(); } catch (\Throwable $_) {}
            }

            // create an admin user for admin flow tests (use firstOrCreate to be idempotent in CI)
            $adminPassword = 'password';
            try {
                $admin = \App\Models\User::firstOrCreate(
                    ['email' => 'e2e-admin@example.test'],
                    ['name' => 'E2E Admin', 'password' => bcrypt($adminPassword), 'timezone' => config('app.timezone', 'UTC')]
                );
            } catch (\Throwable $e) {
                // Be tolerant of race conditions or duplicate insert errors in CI; poll briefly for an existing user before failing
                \Log::warning('E2E seed: firstOrCreate for admin failed, polling for existing user', ['exception' => $e]);
                $admin = null;
                $attempts = 0;
                while ($attempts < 10 && ! $admin) {
                    $admin = \App\Models\User::where('email', 'e2e-admin@example.test')->first();
                    if ($admin) {
                        break;
                    }
                    usleep(100 * 1000); // 100ms
                    $attempts++;
                }

                if (! $admin) {
                    // Last resort: try a direct insert ignoring exceptions to avoid flakiness in CI
                    try {
                        $admin = \App\Models\User::create(['email' => 'e2e-admin@example.test', 'name' => 'E2E Admin', 'password' => bcrypt($adminPassword), 'timezone' => config('app.timezone', 'UTC')]);
                    } catch (\Throwable $_e) {
                        \Log::error('E2E seed: unable to resolve admin user after duplicate error', ['exception' => $_e]);
                        throw $e;
                    }
                }
            }

            // assign ownership of first few events to admin so admin can manage them
            if (! empty($createdEventObjects)) {
                foreach (array_slice($createdEventObjects, 0, 3) as $ev) {
                    $ev->user_id = $admin->id;
                    $ev->save();
                }
            }

            // Create a sale & entry when possible; skip gracefully if factories are not present
            try {
                if (method_exists(Sale::class, 'factory')) {
                    $sale = Sale::factory()->create(['secret' => 'sale-secret-ABC', 'event_id' => $createdEventObjects[0]->id]);
                } else {
                    // create a minimal ticket and sale manually
                    $ticket = \App\Models\Ticket::create(['event_id' => $createdEventObjects[0]->id, 'type' => 'general', 'quantity' => 100, 'price' => 0]);
                    $sale = Sale::create(['ticket_id' => $ticket->id, 'event_id' => $createdEventObjects[0]->id, 'name' => 'E2E Buyer', 'email' => 'e2e-buyer@example.test', 'secret' => 'sale-secret-ABC', 'quantity' => 1]);
                }

                if (method_exists(SaleTicketEntry::class, 'factory')) {
                    $entry = SaleTicketEntry::factory()->create(['secret' => 'entry-secret-123', 'sale_id' => $sale->id]);
                } else {
                    // fallback manual entry
                    $entry = \App\Models\SaleTicketEntry::create(['sale_id' => $sale->id, 'secret' => 'entry-secret-123']);
                }
            } catch (\Throwable $e) {
                // make seed tolerant to missing factories or schema differences
                $sale = null;
                $entry = null;
                \Log::warning('E2E seed: could not create sale/entry', ['exception' => $e]);
            }

            // compute next few occurrences for the recurring event
            $occurrences = [];
            $start = now()->startOfMonth();
            $end = now()->endOfMonth();
            $d = $start->copy();
            while ($d->lte($end) && count($occurrences) < 5) {
                if ($recurring->matchesDate($d)) {
                    $occurrences[] = $d->format('Y-m-d');
                }
                $d->addDay();
            }

            $response = [
                'venue_id' => $venue->id,
                'events' => $events,
                'recurring_id' => $recurring->id,
                'recurring_name' => $recurring->translatedName(),
                'recurring_occurrences' => $occurrences,
                'sale_secret' => $sale ? $sale->secret : null,
                'entry_secret' => $entry ? $entry->secret : null,
                'created_event_ids' => array_map(fn($e) => $e['id'], $events),
                'created_sale_ids' => $sale ? [$sale->id] : [],
            ];

            $response['admin_email'] = $admin->email;
            $response['admin_password'] = $adminPassword;
            $response['created_user_ids'] = [$admin->id];

            return response()->json($response);
        } catch (\Throwable $e) {
            // Provide detailed error payload for debug runs in CI
            \Log::error('E2E seed error', ['exception' => $e]);
            return response()->json(['message' => $e->getMessage(), 'trace' => $e->getTraceAsString()], 500);
        }
    }

    public function teardownE2eData(Request $request)
    {
        if (! app()->environment(['local', 'testing'])) {
            return response()->json(['error' => 'Not allowed'], 403);
        }

        $eventIds = (array) $request->input('event_ids', []);
        $saleIds = (array) $request->input('sale_ids', []);

        if ($saleIds) {
            \App\Models\SaleTicketEntry::whereIn('sale_id', $saleIds)->delete();
            \App\Models\Sale::whereIn('id', $saleIds)->delete();
        }

        if ($eventIds) {
            \App\Models\Event::whereIn('id', $eventIds)->delete();
        }

        $userIds = (array) $request->input('user_ids', []);
        if ($userIds) {
            \App\Models\User::whereIn('id', $userIds)->delete();
        }

        return response()->json(['deleted_event_ids' => $eventIds, 'deleted_sale_ids' => $saleIds]);
    }
}
