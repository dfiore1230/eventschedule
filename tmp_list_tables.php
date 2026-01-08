<?php
require __DIR__ . '/vendor/autoload.php';
$app = require __DIR__ . '/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
putenv('DB_CONNECTION=sqlite');
putenv('DB_DATABASE=:memory:');
config(['database.default' => 'sqlite', 'database.connections.sqlite.database' => ':memory:']);
Artisan::call('migrate:fresh');
$rows = DB::select("select name, type, sql from sqlite_master where type in ('table','index')");
foreach ($rows as $r) {
    echo $r->name . "\t" . $r->type . "\n";
}
