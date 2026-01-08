<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('payment_url')->nullable();
            $table->string('payment_secret')->nullable();
        });

        // For SQLite, take a minimal, trigger-safe path: rename the column and add a new one with the relaxed enum.
        // We leave the old column in place to avoid SQLite drop-column rebuilds that were failing in CI.
        if (config('database.default') === 'sqlite') {
            $this->sqliteRenameAndCopy('events');
            $this->sqliteRenameAndCopy('sales');
        } else {
            // For other databases, use ALTER TABLE
            DB::statement("ALTER TABLE events MODIFY COLUMN payment_method ENUM('cash', 'stripe', 'invoiceninja', 'payment_url') DEFAULT 'cash'");
            DB::statement("ALTER TABLE sales MODIFY COLUMN payment_method ENUM('cash', 'stripe', 'invoiceninja', 'payment_url') DEFAULT 'cash'");
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['payment_url', 'payment_secret']);
        });

        if (config('database.default') === 'sqlite') {
            // Revert to the prior enum by keeping the safer rename path; map payment_url back to cash
            $this->sqliteRenameAndCopy('events', rollback: true);
            $this->sqliteRenameAndCopy('sales', rollback: true);
        } else {
            // For other databases, use ALTER TABLE
            DB::statement("ALTER TABLE events MODIFY COLUMN payment_method ENUM('cash', 'stripe', 'invoiceninja') DEFAULT 'cash'");
            DB::statement("ALTER TABLE sales MODIFY COLUMN payment_method ENUM('cash', 'stripe', 'invoiceninja') DEFAULT 'cash'");
        }
    }

    /**
     * Rebuild a SQLite table replacing the given column with a new definition.
     */
    protected function sqliteRenameAndCopy(string $table, bool $rollback = false): void
    {
        // Temporarily disable FK checks to avoid transient rename issues
        DB::statement('PRAGMA foreign_keys = OFF');

        // If the helper already ran, skip to idempotent state
        $columns = DB::select("PRAGMA table_info('$table')");
        $names = array_map(fn($c) => $c->name, $columns);
        if (in_array('payment_method_old', $names, true) && in_array('payment_method', $names, true)) {
            // We already have both columns; just normalize values on rollback
            if ($rollback) {
                DB::statement("UPDATE $table SET payment_method_old = CASE WHEN payment_method = 'payment_url' THEN 'cash' ELSE payment_method END");
            }
            DB::statement('PRAGMA foreign_keys = ON');
            return;
        }

        // Rename the existing column so we can add a fresh one with the new enum semantics
        DB::statement("ALTER TABLE $table RENAME COLUMN payment_method TO payment_method_old");

        Schema::table($table, function (Blueprint $tableDef) use ($rollback) {
            $default = $rollback ? 'cash' : 'cash';
            $tableDef->string('payment_method')->default($default);
        });

        if ($rollback) {
            DB::statement("UPDATE $table SET payment_method = CASE WHEN payment_method_old = 'payment_url' THEN 'cash' ELSE payment_method_old END");
        } else {
            DB::statement("UPDATE $table SET payment_method = payment_method_old");
        }

        DB::statement('PRAGMA foreign_keys = ON');
    }
};
