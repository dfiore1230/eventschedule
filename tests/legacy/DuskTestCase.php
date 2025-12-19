<?php

namespace Tests;

use App\Models\Setting;
use Facebook\WebDriver\Chrome\ChromeOptions;
use Facebook\WebDriver\Remote\DesiredCapabilities;
use Facebook\WebDriver\Remote\RemoteWebDriver;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Schema;
use Laravel\Dusk\TestCase as BaseTestCase;
use PHPUnit\Framework\Attributes\AfterClass;
use PHPUnit\Framework\Attributes\BeforeClass;

abstract class DuskTestCase extends BaseTestCase
{
    /**
     * Prepare the base application configuration for browser tests.
     */
    protected function setUp(): void
    {
        $this->applyBrowserEnvironmentOverrides();

        parent::setUp();

        // Ensure feature gates relying on the "testing" flag stay open even when
        // the Dusk environment reuses the base .env without APP_TESTING enabled.
        $this->app['config']->set('app.is_testing', true);
        $this->app['config']->set('app.browser_testing', true);
        $this->app['config']->set('app.debug', true);
        $this->app['config']->set('app.load_vite_assets', false);

        $this->app['config']->set('mail.default', 'log');
        $this->app['config']->set('mail.mailers.smtp.transport', 'log');
        $this->app['config']->set(
            'mail.mailers.smtp.channel',
            $this->app['config']->get('mail.mailers.log.channel')
        );

        if (Schema::hasTable('settings')) {
            Setting::setGroup('mail', [
                'mailer' => 'log',
                'disable_delivery' => true,
            ]);
        }
    }

    /**
     * Prepare for Dusk test execution.
     */
    #[BeforeClass]
    public static function prepare(): void
    {
        static::synchronizeDuskEnvironmentOverrides();
        static::ensureBrowserTestingFlagFile();

        if (! static::runningInSail()) {
            static::startChromeDriver(['--port=9515']);
        }
    }

    #[AfterClass]
    public static function cleanup(): void
    {
        static::removeBrowserTestingFlagFile();
    }

    /**
     * Ensure the browser tests consistently run with the expected environment overrides.
     */
    private function applyBrowserEnvironmentOverrides(): void
    {
        foreach ([
            'APP_TESTING' => 'true',
            'BROWSER_TESTING' => 'true',
            'APP_DEBUG' => 'true',
            'LOAD_VITE_ASSETS' => 'false',
        ] as $key => $value) {
            putenv("{$key}={$value}");
            $_ENV[$key] = $value;
            $_SERVER[$key] = $value;
        }
    }

    /**
     * Persist the environment overrides to the Dusk environment file so that the
     * HTTP server process that services browser requests sees the same values.
     */
    private static function synchronizeDuskEnvironmentOverrides(): void
    {
        $path = dirname(__DIR__) . DIRECTORY_SEPARATOR . '.env.dusk.local';

        if (! is_file($path)) {
            file_put_contents($path, '');
        }

        $contents = file_get_contents($path);
        $contents = is_string($contents) ? $contents : '';

        foreach ([
            'APP_TESTING' => 'true',
            'BROWSER_TESTING' => 'true',
            'APP_DEBUG' => 'true',
            'LOAD_VITE_ASSETS' => 'false',
        ] as $key => $value) {
            $pattern = "/^{$key}=.*$/m";

            if (preg_match($pattern, $contents)) {
                $contents = (string) preg_replace($pattern, "{$key}={$value}", $contents);
            } else {
                $contents = rtrim($contents, "\r\n");

                if ($contents !== '') {
                    $contents .= PHP_EOL;
                }

                $contents .= "{$key}={$value}" . PHP_EOL;
            }
        }

        file_put_contents($path, $contents);
    }

    private static function ensureBrowserTestingFlagFile(): void
    {
        $path = static::browserTestingFlagPath();
        $directory = dirname($path);

        if (! is_dir($directory)) {
            mkdir($directory, 0777, true);
        }

        file_put_contents($path, '1');
    }

    private static function removeBrowserTestingFlagFile(): void
    {
        $path = static::browserTestingFlagPath();

        if (is_file($path)) {
            @unlink($path);
        }
    }

    /**
     * Capture browser screenshot and page source for diagnostics.
     */
    protected function captureBrowserState(?\Laravel\Dusk\Browser $browser, string $name): void
    {
        if (! $browser) {
            return;
        }

        $dir = __DIR__ . DIRECTORY_SEPARATOR . 'Browser' . DIRECTORY_SEPARATOR . 'screenshots';

        if (! is_dir($dir)) {
            @mkdir($dir, 0777, true);
        }

        // Prefer using the WebDriver's takeScreenshot method so we can write directly
        // write a small marker that capture started (helps CI confirm invocation)
        try {
            file_put_contents($dir . DIRECTORY_SEPARATOR . 'dusk-' . $name . '-capture-attempt.txt', date('c') . " - capture started\n", FILE_APPEND);
            @file_put_contents('php://stderr', "DUSK: capture start {$name} to {$dir}\n");
        } catch (\Throwable $_) {
            // ignore marker errors
        }

        try {
            $screenshotPath = $dir . DIRECTORY_SEPARATOR . 'dusk-' . $name . '.png';

            if (method_exists($browser->driver, 'takeScreenshot')) {
                try {
                    // php-webdriver's takeScreenshot() returns a base64 string; write it to disk explicitly
                    $screenshotData = $browser->driver->takeScreenshot();

                    if (is_string($screenshotData) && strlen($screenshotData) > 0) {
                        file_put_contents($screenshotPath, base64_decode($screenshotData));
                    }

                    if (is_file($screenshotPath)) {
                        $size = filesize($screenshotPath);
                        file_put_contents($dir . DIRECTORY_SEPARATOR . 'dusk-' . $name . '-screenshot-saved.txt', date('c') . " - saved ({$size} bytes)\n", FILE_APPEND);
                        @file_put_contents('php://stderr', "DUSK: screenshot saved {$screenshotPath} ({$size} bytes)\n");
                    }
                } catch (\Throwable $e) {
                    // fallback to $browser->screenshot
                    try {
                        $browser->screenshot($name);

                        if (is_file($screenshotPath)) {
                            $size = filesize($screenshotPath);
                            file_put_contents($dir . DIRECTORY_SEPARATOR . 'dusk-' . $name . '-screenshot-saved.txt', date('c') . " - saved via fallback ({$size} bytes)\n", FILE_APPEND);
                            @file_put_contents('php://stderr', "DUSK: screenshot fallback saved {$screenshotPath} ({$size} bytes)\n");
                        }
                    } catch (\Throwable $__) {
                        // ignore screenshot errors
                        @file_put_contents('php://stderr', "DUSK: screenshot failed for {$name}: {$e->getMessage()}\n");
                    }
                }
            } else {
                // fallback to the Dusk helper
                try {
                    $browser->screenshot($name);

                    if (is_file($screenshotPath)) {
                        $size = filesize($screenshotPath);
                        file_put_contents($dir . DIRECTORY_SEPARATOR . 'dusk-' . $name . '-screenshot-saved.txt', date('c') . " - saved via helper ({$size} bytes)\n", FILE_APPEND);
                        @file_put_contents('php://stderr', "DUSK: screenshot helper saved {$screenshotPath} ({$size} bytes)\n");
                    }
                } catch (\Throwable $__) {
                    // ignore screenshot errors
                    @file_put_contents('php://stderr', "DUSK: screenshot helper failed for {$name}: {$__->getMessage()}\n");
                }
            }
        } catch (\Throwable $e) {
            // ignore screenshot errors
            @file_put_contents('php://stderr', "DUSK: screenshot top-level error for {$name}: {$e->getMessage()}\n");
        }

        try {
            $source = $browser->driver->getPageSource();
            $path = $dir . DIRECTORY_SEPARATOR . 'dusk-' . $name . '.html';

            file_put_contents($path, $source);

            if (is_file($path)) {
                $size = filesize($path);
                file_put_contents($dir . DIRECTORY_SEPARATOR . 'dusk-' . $name . '-html-saved.txt', date('c') . " - saved ({$size} bytes)\n", FILE_APPEND);
                @file_put_contents('php://stderr', "DUSK: html saved {$path} ({$size} bytes)\n");
            }
        } catch (\Throwable $e) {
            // ignore page source errors
            @file_put_contents('php://stderr', "DUSK: html capture failed for {$name}: {$e->getMessage()}\n");
        }
    }

    private static function browserTestingFlagPath(): string
    {
        return dirname(__DIR__) . DIRECTORY_SEPARATOR . 'storage'
            . DIRECTORY_SEPARATOR . 'framework'
            . DIRECTORY_SEPARATOR . 'browser-testing.flag';
    }

    /**
     * Create the RemoteWebDriver instance.
     */
    protected function driver(): RemoteWebDriver
    {
        $options = (new ChromeOptions)->addArguments(collect([
            $this->shouldStartMaximized() ? '--start-maximized' : '--window-size=1920,1080',
            '--disable-search-engine-choice-screen',
        ])->unless($this->hasHeadlessDisabled(), function (Collection $items) {
            return $items->merge([
                '--disable-gpu',
                '--headless=new',
            ]);
        })->all());

        return RemoteWebDriver::create(
            $_ENV['DUSK_DRIVER_URL'] ?? env('DUSK_DRIVER_URL') ?? 'http://localhost:9515',
            DesiredCapabilities::chrome()->setCapability(
                ChromeOptions::CAPABILITY, $options
            )
        );
    }
}
