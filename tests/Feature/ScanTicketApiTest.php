<?php

namespace Tests\Feature;

use Tests\TestCase;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use App\Models\Sale;
use App\Models\SaleTicketEntry;
use App\Models\Event;

class ScanTicketApiTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        // Disable middleware to keep API requests unauthenticated for these tests
        $this->withoutMiddleware();
    }

    public function test_scans_entry_secret_successfully()
    {
        \Illuminate\Support\Facades\Log::spy();

        $event = Event::factory()->create(['starts_at' => now()->addDays(1)]);
        $sale = Sale::factory()->create(['secret' => 'sale-ABC', 'event_id' => $event->id]);
        $entry = SaleTicketEntry::factory()->create(['secret' => 'entry-123', 'sale_id' => $sale->id]);

        $response = $this->postJson('/api/tickets/scan', ['code' => 'entry-123', 'location' => 'door-1']);

        $response->assertStatus(201);
        $response->assertJsonStructure(['data']);
    }

    public function test_falls_back_to_sale_secret_when_entry_missing()
    {
        \Illuminate\Support\Facades\Log::spy();

        $event = Event::factory()->create(['starts_at' => now()->addDays(1)]);
        $sale = Sale::factory()->create(['secret' => 'sale-ABC', 'event_id' => $event->id]);
        // Create a ticket for this sale
        $ticket = \App\Models\Ticket::factory()->create(['event_id' => $event->id]);
        \App\Models\SaleTicket::factory()->create(['sale_id' => $sale->id, 'ticket_id' => $ticket->id]);

        $response = $this->postJson('/api/tickets/scan', ['code' => 'sale-ABC', 'location' => 'door-1']);

        $response->assertStatus(201);
        $response->assertJson(['data' => ['sale_id' => $sale->id]]);

        \Illuminate\Support\Facades\Log::shouldHaveReceived('info')->withArgs(function ($message, $context) use ($sale) {
            return $message === 'scan_by_code: created_entry' && isset($context['sale_id']) && $context['sale_id'] === $sale->id;
        });
    }

    public function test_rejects_scan_outside_event_time_based_on_event_timezone()
    {
        \Illuminate\Support\Facades\Log::spy();

        $event = Event::factory()->create(['starts_at' => now()->subDays(10)]);
        $sale = Sale::factory()->create([
            'secret' => 'old-sale',
            'event_id' => $event->id,
            'event_date' => now()->subDays(10)->format('Y-m-d'), // Set to the same date as event
        ]);
        // Create a ticket for this sale
        $ticket = \App\Models\Ticket::factory()->create(['event_id' => $event->id]);
        \App\Models\SaleTicket::factory()->create(['sale_id' => $sale->id, 'ticket_id' => $ticket->id]);

        $response = $this->postJson('/api/tickets/scan', ['code' => 'old-sale', 'location' => 'door-1']);

        $response->assertStatus(400);
        $this->assertArrayHasKey('error', $response->json());
    }

    public function test_logs_not_found_for_invalid_code()
    {
        \Illuminate\Support\Facades\Log::spy();

        $response = $this->postJson('/api/tickets/scan', ['code' => 'invalid-xyz', 'location' => 'door']);

        $response->assertStatus(404);

        \Illuminate\Support\Facades\Log::shouldHaveReceived('info')->withArgs(function ($message, $context) {
            return $message === 'scan_by_code: not_found' && isset($context['code']) && $context['code'] === 'invalid-xyz';
        });
    }
}
