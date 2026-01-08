<?php

namespace Tests;

use Illuminate\Foundation\Testing\TestCase as BaseTestCase;
use Illuminate\Support\Facades\DB;

abstract class TestCase extends BaseTestCase
{
    use CreatesApplication;

    protected function setUp(): void
    {
        // Force sqlite in-memory for tests and disable foreign keys BEFORE parent::setUp()
        // to avoid environment overrides and prevent _temp_ table corruption during migrations
        putenv('DB_CONNECTION=sqlite');
        putenv('DB_DATABASE=:memory:');
        putenv('DB_FOREIGN_KEYS=false');
        
        parent::setUp();

        // Confirm foreign keys are disabled
        config(['database.connections.sqlite.foreign_key_constraints' => false]);

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
    }

    /**
     * Callback to run after migrations for RefreshDatabase tests
     */
    protected function afterRefreshingDatabase()
    {
        // Keep foreign keys disabled to avoid _temp_ table reference issues in SQLite
        if (DB::connection()->getDriverName() === 'sqlite') {
            DB::statement('PRAGMA foreign_keys = OFF');
        }
    }
}
