<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        if (config('database.default') !== 'sqlite') {
            return;
        }

        // Disable foreign key checks while we rebuild tables to avoid transient references to _temp_* tables
        DB::statement('PRAGMA foreign_keys = OFF');

        // Iteratively find and fix tables that reference transient table names (_temp_ or _old_)
        while (true) {
            $rows = DB::select("SELECT name, sql FROM sqlite_master WHERE type = 'table' AND (sql LIKE '%_temp_%' OR sql LIKE '%_old_%')");
            if (empty($rows)) {
                break;
            }

            foreach ($rows as $row) {
            $table = $row->name;
            $createSql = $row->sql;

            // Build fixed CREATE statement by removing _temp_ occurrences in referenced table names
            // Replace any occurrences of _temp_ in referenced table names (cover quoted and unquoted forms)
            $fixedCreate = str_replace('"_temp_', '"', $createSql);
            $fixedCreate = str_replace("'_temp_", "'", $fixedCreate);
            $fixedCreate = str_replace('_temp_', '', $fixedCreate);
            // Also fix references to _old_ which we may have created while repairing other tables
            $fixedCreate = str_replace('_old_', '', $fixedCreate);

            // Rename old table and create new one with corrected foreign keys
            DB::statement("ALTER TABLE {$table} RENAME TO _old_{$table}");
            DB::statement($fixedCreate);

            // Copy data: copy columns that exist in both tables
            $oldCols = DB::select("PRAGMA table_info('_old_{$table}')");
            $newCols = DB::select("PRAGMA table_info('{$table}')");

            $oldNames = array_map(fn($c) => '"' . $c->name . '"', $oldCols);
            $newNames = array_map(fn($c) => '"' . $c->name . '"', $newCols);

            // Intersect column names preserving order from new table
            $intersect = array_intersect($newNames, $oldNames);
            if (!empty($intersect)) {
                $colsList = implode(', ', $intersect);
                DB::statement("INSERT INTO {$table} ({$colsList}) SELECT {$colsList} FROM _old_{$table}");
            }

            // Drop the old table
            DB::statement("DROP TABLE _old_{$table}");

            // Recreate indexes for this table (best-effort): copy any indexes that referenced the old create SQL
            $indexes = DB::select("SELECT name, sql FROM sqlite_master WHERE type = 'index' AND tbl_name = '{$table}' AND sql NOT NULL");
            foreach ($indexes as $idx) {
                // Recreate index SQL (it should already be present after create, but ensure it exists)
                try {
                    DB::statement($idx->sql);
                } catch (\Throwable $e) {
                    // ignore failures; index may already exist
                }
            }
        }

        // Re-enable foreign key checks
        DB::statement('PRAGMA foreign_keys = ON');
    }

    public function down(): void
    {
        // no-op
    }
};
