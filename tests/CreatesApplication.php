<?php

namespace Tests;

use Illuminate\Contracts\Console\Kernel;

trait CreatesApplication
{
    public function createApplication()
    {
        // Ensure test process uses sqlite in-memory unless explicitly configured otherwise.
        // This must happen before the application is bootstrapped so environment overrides take effect early.
        putenv('DB_CONNECTION=sqlite');
        putenv('DB_DATABASE=:memory:');
        $_ENV['DB_CONNECTION'] = 'sqlite';
        $_ENV['DB_DATABASE'] = ':memory:';
        $_SERVER['DB_CONNECTION'] = 'sqlite';
        $_SERVER['DB_DATABASE'] = ':memory:';

        fwrite(STDERR, "CREATES_APP: about to require app.php\n");
        $app = require __DIR__.'/../bootstrap/app.php';

        fwrite(STDERR, "CREATES_APP: about to bootstrap Kernel\n");
        $app->make(Kernel::class)->bootstrap();
        fwrite(STDERR, "CREATES_APP: kernel bootstrap complete\n");

        return $app;
    }
}
