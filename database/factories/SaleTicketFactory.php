<?php

namespace Database\Factories;

use App\Models\SaleTicket;
use App\Models\Sale;
use App\Models\Ticket;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends \Illuminate\Database\Eloquent\Factories\Factory<\App\Models\SaleTicket>
 */
class SaleTicketFactory extends Factory
{
    protected $model = SaleTicket::class;

    public function definition(): array
    {
        return [
            'sale_id' => Sale::factory(),
            'ticket_id' => Ticket::factory(),
            'quantity' => $this->faker->numberBetween(1, 4),
        ];
    }
}
