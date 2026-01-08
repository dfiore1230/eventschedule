<?php
require __DIR__ . '/../vendor/autoload.php';
$app = require_once __DIR__ . '/../bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

use App\Models\User;
use Illuminate\Support\Facades\DB;

$user = User::latest()->first();
echo "User ID: " . ($user ? $user->id : 'none') . PHP_EOL;
echo "Exists slug admin: " . (int) $user->systemRoles()->where('slug', 'admin')->exists() . PHP_EOL;
$sql = $user->systemRoles()->toSql();
$bindings = $user->systemRoles()->getBindings();
echo "SQL: \n" . $sql . PHP_EOL;
echo "Bindings: \n"; print_r($bindings);
$ids = $user->systemRoles()->pluck('auth_roles.id')->toArray();
echo "Plucked IDs: \n"; print_r($ids);

echo "User roles raw: \n";
$raw = DB::select("select * from auth_roles");
print_r(array_map(function($r){return (array)$r;}, $raw));

$raw2 = DB::select("select * from user_roles");
print_r(array_map(function($r){return (array)$r;}, $raw2));
