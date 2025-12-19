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
                    'venue_id' => $venue->id,
                    'name' => "E2E Event {$i}",
                ]);
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
                'venue_id' => $venue->id,
                'name' => 'E2E Recurring',
            ]);

            // create an admin user for admin flow tests
            $adminPassword = 'password';
            $admin = \App\Models\User::factory()->create([
                'email' => 'e2e-admin@example.test',
                'password' => bcrypt($adminPassword),
            ]);

            // assign ownership of first few events to admin so admin can manage them
            if (! empty($createdEventObjects)) {
                foreach (array_slice($createdEventObjects, 0, 3) as $ev) {
                    $ev->user_id = $admin->id;
                    $ev->save();
                }
            }

            $sale = Sale::factory()->create(['secret' => 'sale-secret-ABC', 'event_id' => $createdEventObjects[0]->id]);
            $entry = SaleTicketEntry::factory()->create(['secret' => 'entry-secret-123', 'sale_id' => $sale->id]);

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
                'sale_secret' => $sale->secret,
                'entry_secret' => $entry->secret,
                'created_event_ids' => array_map(fn($e) => $e['id'], $events),
                'created_sale_ids' => [$sale->id],
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
