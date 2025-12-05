<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            if (! Schema::hasColumn('users', 'status')) {
                $table->string('status')->default('active')->after('language_code');
            }

            if (! Schema::hasColumn('users', 'deleted_at')) {
                $table->softDeletes();
            }
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        $priorStatusAndSoftDeletesMigrationRan = DB::table('migrations')
            ->where('migration', '2026_10_20_000100_add_status_and_soft_deletes_to_users_table')
            ->exists();

        if (! $priorStatusAndSoftDeletesMigrationRan) {
            Schema::table('users', function (Blueprint $table) {
                if (Schema::hasColumn('users', 'deleted_at')) {
                    $table->dropSoftDeletes();
                }

                if (Schema::hasColumn('users', 'status')) {
                    $table->dropColumn('status');
                }
            });
        }
    }
};
