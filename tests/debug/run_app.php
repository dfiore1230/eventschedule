<?php

require __DIR__ . '/../../vendor/autoload.php';

putenv('DB_CONNECTION=sqlite');
putenv('DB_DATABASE=:memory:');
$_ENV['DB_CONNECTION'] = 'sqlite';
$_ENV['DB_DATABASE'] = ':memory:';

fwrite(STDERR, "DEBUG: before require app.php\n");
$app = require __DIR__ . '/../../bootstrap/app.php';
fwrite(STDERR, "DEBUG: after require app.php\n");

fwrite(STDERR, "DEBUG: about to bootstrap kernel\n");
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
fwrite(STDERR, "DEBUG: kernel bootstrap complete\n");

fwrite(STDERR, "DEBUG: about to run migrations\n");
// Run migrations to ensure schema exists
try {
    $app->make(Illuminate\Contracts\Console\Kernel::class)->call('migrate', ['--force' => true]);
    fwrite(STDERR, "DEBUG: migrations complete\n");
} catch (Throwable $e) {
    fwrite(STDERR, "DEBUG: migrate failed: " . $e->getMessage() . "\n");
}

fwrite(STDERR, "DEBUG: about to create event via factory\n");
try {
    $event = App\Models\Event::factory()->create(['starts_at' => now()->addDay()]);
    fwrite(STDERR, "DEBUG: event created id=" . $event->id . "\n");
} catch (Throwable $e) {
    fwrite(STDERR, "DEBUG: event create failed: " . $e->getMessage() . "\n");
    fwrite(STDERR, $e->getTraceAsString() . "\n");
}

fwrite(STDERR, "DEBUG: done\n");
