<?php

namespace Database\Seeders;

use App\Models\EmailList;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Schema;

class EmailListSeeder extends Seeder
{
    public function run(): void
    {
        if (! Schema::hasTable('email_lists')) {
            return;
        }

        $globalKey = config('mass_email.global_list_key', 'GLOBAL_UPDATES');

        EmailList::query()->firstOrCreate(
            ['key' => $globalKey],
            [
                'type' => EmailList::TYPE_GLOBAL,
                'name' => 'Planify Updates',
            ]
        );
    }
}
