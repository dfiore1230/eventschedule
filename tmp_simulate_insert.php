<?php
require __DIR__ . '/vendor/autoload.php';
$app = require __DIR__ . '/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
putenv('DB_CONNECTION=sqlite');
putenv('DB_DATABASE=:memory:');
config(['database.default' => 'sqlite', 'database.connections.sqlite.database' => ':memory:']);
Artisan::call('migrate:fresh');
// Create an event via factory
$event = App\Models\Event::factory()->create();
print_r(DB::select("PRAGMA table_info(events)"));
print_r(DB::select("select name, type, sql from sqlite_master where type in ('table','index')"));
// Try inserting into tickets directly
try {
    DB::statement("INSERT INTO tickets (event_id, type, quantity, sold, price, description, updated_at, created_at) VALUES (?, ?, ?, ?, ?, ?, datetime('now'), datetime('now'))", [$event->id, 'general', 100, json_encode([]), 0, 'desc']);
    echo "Insert succeeded\n";
} catch (\Throwable $e) {
    echo "Insert failed: " . $e->getMessage() . "\n";
    echo $e->getTraceAsString();
}
