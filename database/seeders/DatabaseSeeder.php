<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Database\Seeders\EmailListSeeder;

class DatabaseSeeder extends Seeder
{
    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        $this->call(AuthorizationSeeder::class);
        $this->call(HeaderMediaSeeder::class);
        $this->call(EmailListSeeder::class);
    }
}
