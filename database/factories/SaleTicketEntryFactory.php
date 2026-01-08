<?php

namespace Database\Factories;

use App\Models\SaleTicketEntry;
use App\Models\SaleTicket;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends \Illuminate\Database\Eloquent\Factories\Factory<\App\Models\SaleTicketEntry>
 */
class SaleTicketEntryFactory extends Factory
{
    protected $model = SaleTicketEntry::class;

    public function definition(): array
    {
        return [
            'sale_ticket_id' => SaleTicket::factory(),
            'secret' => \Illuminate\Support\Str::random(12),
            'seat_number' => null,
            'scanned_at' => null,
        ];
    }

    public function configure(): self
    {
        return $this->afterMaking(function (SaleTicketEntry $entry) {
            // Support legacy factory input: 'sale_id' => <id>
            // Find or create a matching SaleTicket and map it to sale_ticket_id
            if ($entry->getAttribute('sale_id')) {
                $saleId = $entry->getAttribute('sale_id');
                $saleTicket = \App\Models\SaleTicket::where('sale_id', $saleId)->first();
                if (! $saleTicket) {
                    // Create a minimal sale_ticket for this sale
                    $saleTicket = \App\Models\SaleTicket::factory()->create(['sale_id' => $saleId]);
                }

                $entry->sale_ticket_id = $saleTicket->id;
                // Remove legacy attribute so it's not included in the INSERT
                $entry->offsetUnset('sale_id');
            }
        });
    }
}
