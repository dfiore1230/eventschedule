<?php

// This bootstrap runs before tests. We ensure we're running sqlite in-memory
// then run a targeted repair migration to fix any lingering CREATE statements
// that reference transient `_temp_` tables left behind by past SQLite migrations.

use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;

// Only run in testing with sqlite to be safe
// NOTE: Do NOT run the repair migration class here — it will be executed during
// `artisan migrate` and may run before dependent tables are created, causing
// ALTER TABLE errors. The repair routine runs in `TestCase::setUp()` after
// migrations so it's safe to run there instead.
if ((env('DB_CONNECTION') ?? 'sqlite') === 'sqlite') {
    // Intentionally left blank — repair logic runs after migrations in TestCase::setUp().
}
