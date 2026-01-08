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

        $response = $this->postJson('/api/tickets/scan', ['code' => 'sale-ABC', 'location' => 'door-1']);

        $response->assertStatus(200);
        $response->assertJson(['data' => ['sale_id' => $sale->id]]);

        \Illuminate\Support\Facades\Log::shouldHaveReceived('info')->withArgs(function ($message, $context) use ($sale) {
            return $message === 'scan_by_code: created_entry' && isset($context['sale_id']) && $context['sale_id'] === $sale->id;
        });
    }

    public function test_rejects_scan_outside_event_time_based_on_event_timezone()
    {
        \Illuminate\Support\Facades\Log::spy();

        $event = Event::factory()->create(['starts_at' => now()->subDays(10)]);
        $sale = Sale::factory()->create(['secret' => 'old-sale', 'event_id' => $event->id]);

        $response = $this->postJson('/api/tickets/scan', ['code' => 'old-sale', 'location' => 'door-1']);

        $response->assertStatus(400);
        $this->assertArrayHasKey('error', $response->json());

        \Illuminate\Support\Facades\Log::shouldHaveReceived('info')->withArgs(function ($message, $context) use ($sale) {
            return $message === 'scan_by_code: date_mismatch' && isset($context['sale_id']) && $context['sale_id'] === $sale->id;
        });
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
