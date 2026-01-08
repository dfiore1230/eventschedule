<?php

namespace Database\Factories;

use App\Models\Sale;
use App\Models\Event;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends \Illuminate\Database\Eloquent\Factories\Factory<\App\Models\Sale>
 */
class SaleFactory extends Factory
{
    protected $model = Sale::class;

    public function definition(): array
    {
        try {
            return [
                'event_id' => function () { return Event::factory()->create()->id; },
                'name' => $this->faker->name(),
                'email' => $this->faker->safeEmail(),
                'secret' => \Illuminate\Support\Str::random(16),
                'event_date' => now()->format('Y-m-d'),
                'status' => 'paid',
                'subdomain' => 'test-subdomain',
            ];
        } catch (\Throwable $e) {
            error_log("SaleFactory failed: " . $e->getMessage());
            error_log(print_r(debug_backtrace(DEBUG_BACKTRACE_IGNORE_ARGS), true));
            throw $e;
        }
    }
}
