<?php
require __DIR__ . '/vendor/autoload.php';
$app = require __DIR__ . '/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
putenv('DB_CONNECTION=sqlite');
putenv('DB_DATABASE=:memory:');
config(['database.default' => 'sqlite', 'database.connections.sqlite.database' => ':memory:']);
Artisan::call('migrate:fresh');
$rows = DB::select("PRAGMA table_info('events')");
foreach ($rows as $r) {
    echo $r->cid . "\t" . $r->name . "\t" . $r->type . "\t" . $r->notnull . "\t" . $r->dflt_value . "\t" . $r->pk . "\n";
}
