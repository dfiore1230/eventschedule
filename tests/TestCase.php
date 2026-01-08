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
    }
}
