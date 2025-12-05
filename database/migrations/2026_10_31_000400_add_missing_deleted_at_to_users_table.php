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
        if (! Schema::hasColumn('users', 'deleted_at')) {
            return;
        }

        if ($this->deletedAtColumnPreexisted()) {
            return;
        }

        Schema::table('users', function (Blueprint $table) {
            $table->dropSoftDeletes();
        });
    }

    private function deletedAtColumnPreexisted(): bool
    {
        if (! Schema::hasTable('migrations')) {
            return false;
        }

        $priorSoftDeleteMigrations = [
            '2026_10_20_000100_add_status_and_soft_deletes_to_users_table',
            '2026_10_25_000200_add_soft_deletes_column_to_users_table',
            '2026_10_30_000300_add_deleted_at_to_users_table',
        ];

        return DB::table('migrations')
            ->whereIn('migration', $priorSoftDeleteMigrations)
            ->exists();
    }
};
