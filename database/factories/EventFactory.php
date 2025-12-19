<?php

namespace Database\Factories;

use App\Models\Event;
use App\Models\Role;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/**
 * @extends \Illuminate\Database\Eloquent\Factories\Factory<\App\Models\Event>
 */
class EventFactory extends Factory
{
    protected $model = Event::class;

    public function definition(): array
    {
        $user = User::factory();
        $venue = Role::factory()->ofType('venue');
        $role = Role::factory()->ofType('talent');
        $name = fake()->unique()->sentence(3);

        // Note: historical schema included `role_id` and `venue_id` on the `events` table.
        // Recent migrations move these relations into the `event_role` pivot table.
        // To avoid inserting unknown columns during tests, we attach roles after
        // the event is created via the `afterCreating` callback below.
        $attrs = [
            'user_id' => $user,
            'name' => $name,
            'slug' => Str::slug($name) . '-' . fake()->unique()->numberBetween(100, 999),
            'starts_at' => now()->addWeek(),
            'timezone' => config('app.timezone', 'UTC'),
            'duration' => 2.5,
            'description' => fake()->sentence(),
            'description_html' => '<p>' . fake()->sentence() . '</p>',
            'tickets_enabled' => false,
            'total_tickets_mode' => 'unlimited',
            'payment_method' => 'free',
        ];

        $this->afterCreating(function (Event $event) use ($role, $venue) {
            // Create role and venue records and attach them to the event via pivot
            $roleModel = $role->create();
            $venueModel = $venue->create();

            try {
                $event->roles()->attach($roleModel->id, ['is_accepted' => true]);
                $event->roles()->attach($venueModel->id, ['is_accepted' => true]);
            } catch (\Throwable $e) {
                // If attaching fails (older schema that still has columns), ignore
                // to keep factories usable across schema versions in CI.
            }
        });

        return $attrs;
    }
}
