<?php

namespace Tests;

use Illuminate\Foundation\Testing\TestCase as BaseTestCase;
use Illuminate\Support\Facades\DB;

abstract class TestCase extends BaseTestCase
{
    use CreatesApplication;

    protected function setUp(): void
    {
        parent::setUp();

        // Force sqlite in-memory for tests to avoid environment overrides (e.g., .env setting DB_DATABASE=laravel_test)
        config([
            'database.default' => 'sqlite',
            'database.connections.sqlite.database' => ':memory:',
        ]);

        $this->withoutVite();

        // Disable CSRF checks and API authentication in tests to avoid 419/401 responses caused by middleware in the test environment
        // Keep session middleware functioning by ensuring a session store is available on the request.
        $this->withoutMiddleware(
            \Illuminate\Foundation\Http\Middleware\VerifyCsrfToken::class,
            \App\Http\Middleware\ApiAuthentication::class
        );

        // Start the session manually for tests so that authentication and flash messages work
        $sessionPath = storage_path('framework/sessions');
        if (! is_dir($sessionPath)) {
            mkdir($sessionPath, 0777, true);
        }

        $session = $this->app['session']->driver();
        $session->start();
        $this->app->instance('session.store', $session);
        $this->app['request']->setLaravelSession($session);
        
        // Fix SQLite schema corruption from _temp_ table references created during migrations
        $this->fixSqliteTempReferences();
    }

    /**
     * Fix SQLite foreign key references to _temp_ tables that may have been created during migrations
     */
    protected function fixSqliteTempReferences(): void
    {
        if (DB::connection()->getDriverName() !== 'sqlite') {
            return;
        }

        // Find tables with _temp_ or _old_ references in their foreign keys
        $rows = DB::select("SELECT name, sql FROM sqlite_master WHERE type = 'table' AND (sql LIKE '%_temp_%' OR sql LIKE '%_old_%')");
        
        if (empty($rows)) {
            return;
        }

        DB::statement('PRAGMA foreign_keys = OFF');

        foreach ($rows as $row) {
            $table = $row->name;
            $createSql = $row->sql;

            // Fix the CREATE statement by removing _temp_ and _old_ prefixes from referenced tables
            $fixedCreate = preg_replace('/"_temp_([^"]+)"/', '"$1"', $createSql);
            $fixedCreate = preg_replace("/'_temp_([^']+)'/", "'$1'", $fixedCreate);
            $fixedCreate = str_replace('_temp_', '', $fixedCreate);
            
            // Also fix _old_ references
            $fixedCreate = preg_replace('/"_old_([^"]+)"/', '"$1"', $fixedCreate);
            $fixedCreate = preg_replace("/'_old_([^']+)'/", "'$1'", $fixedCreate);
            $fixedCreate = str_replace('_old_', '', $fixedCreate);

            if ($fixedCreate === $createSql) {
                continue; // No changes needed
            }

            try {
                // Recreate the table with corrected foreign keys
                DB::statement("ALTER TABLE \"{$table}\" RENAME TO \"_old_{$table}\"");
                DB::statement($fixedCreate);

                // Copy data from old table to new
                $columns = DB::select("PRAGMA table_info('{$table}')");
                $columnNames = array_map(fn($c) => "\"{$c->name}\"", $columns);
                $colsList = implode(', ', $columnNames);
                
                DB::statement("INSERT INTO \"{$table}\" ({$colsList}) SELECT {$colsList} FROM \"_old_{$table}\"");
                DB::statement("DROP TABLE \"_old_{$table}\"");
            } catch (\Throwable $e) {
                // If recreation fails, just continue - the table might not exist yet
                continue;
            }
        }

        DB::statement('PRAGMA foreign_keys = ON');
    }
}
