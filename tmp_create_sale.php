<?php
require __DIR__ . '/vendor/autoload.php';
$app = require __DIR__ . '/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
putenv('DB_CONNECTION=sqlite');
putenv('DB_DATABASE=:memory:');
config(['database.default' => 'sqlite', 'database.connections.sqlite.database' => ':memory:']);
Artisan::call('migrate:fresh');
try {
    $sale = \App\Models\Sale::factory()->create();
    echo "Sale created: {$sale->id}\n";
} catch (\Throwable $e) {
    echo $e->__toString();
}
