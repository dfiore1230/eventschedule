<?php

namespace App\Services;

use Illuminate\Http\UploadedFile;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;

class BackupService
{
    private const BACKUP_PREFIX = 'planify-backup-';

    public function listBackups(): array
    {
        $dir = $this->ensureBackupDir();
        $files = glob($dir . '/*.tar.gz') ?: [];
        $backups = [];

        foreach ($files as $file) {
            if (! is_file($file)) {
                continue;
            }
            $backups[] = $this->buildBackupMeta($file);
        }

        usort($backups, fn ($a, $b) => strcmp($b['created_at'], $a['created_at']));

        return $backups;
    }

    public function createBackup(): array
    {
        $dir = $this->ensureBackupDir();
        $timestamp = Carbon::now('UTC')->format('Ymd-His');
        $backupFile = $dir . '/' . self::BACKUP_PREFIX . $timestamp . '.tar.gz';
        $workDir = $this->makeWorkDir($timestamp);

        $envPath = base_path('.env');
        if (is_file($envPath)) {
            copy($envPath, $workDir . '/.env');
        }

        $this->createStorageArchive($workDir . '/storage.tar.gz');
        $this->createPublicImagesArchive($workDir . '/public-images.tar.gz');
        $this->createDatabaseDump($workDir . '/db.sql');

        $this->createBundleArchive($workDir, $backupFile);
        $this->cleanupDir($workDir);

        return $this->buildBackupMeta($backupFile);
    }

    public function storeUploadedBackup(UploadedFile $file): array
    {
        $dir = $this->ensureBackupDir();
        $timestamp = Carbon::now('UTC')->format('Ymd-His');
        $safeName = Str::slug(pathinfo($file->getClientOriginalName(), PATHINFO_FILENAME));
        $safeName = $safeName ?: 'upload';
        $target = $dir . '/' . self::BACKUP_PREFIX . $timestamp . '-' . $safeName . '.tar.gz';
        $file->move($dir, basename($target));

        return $this->buildBackupMeta($target);
    }

    public function restoreBackup(string $backupFile): void
    {
        $path = $this->resolveBackupPath($backupFile);
        if (! $path) {
            throw new \RuntimeException('Backup file not found.');
        }

        $workDir = $this->makeWorkDir('restore');
        $this->extractArchive($path, $workDir);

        $envFile = $workDir . '/.env';
        if (is_file($envFile)) {
            copy($envFile, base_path('.env'));
        }

        $storageTar = $workDir . '/storage.tar.gz';
        if (is_file($storageTar)) {
            $this->extractArchive($storageTar, base_path());
        }

        $publicImagesTar = $workDir . '/public-images.tar.gz';
        if (is_file($publicImagesTar)) {
            $this->extractArchive($publicImagesTar, base_path());
        }

        $dbDump = $workDir . '/db.sql';
        if (is_file($dbDump)) {
            $this->restoreDatabase($dbDump);
        }

        $this->fixPermissions();
        $this->cleanupDir($workDir);
    }

    private function ensureBackupDir(): string
    {
        $dir = storage_path('backups');
        if (! is_dir($dir)) {
            mkdir($dir, 0755, true);
        }
        return $dir;
    }

    private function buildBackupMeta(string $path): array
    {
        return [
            'name' => basename($path),
            'path' => $path,
            'size' => filesize($path) ?: 0,
            'created_at' => Carbon::createFromTimestamp(filemtime($path))->toDateTimeString(),
        ];
    }

    private function makeWorkDir(string $suffix): string
    {
        $base = storage_path('app/tmp');
        if (! is_dir($base)) {
            mkdir($base, 0755, true);
        }
        $dir = $base . '/backup-' . $suffix . '-' . Str::random(8);
        mkdir($dir, 0755, true);
        return $dir;
    }

    private function cleanupDir(string $dir): void
    {
        if (! is_dir($dir)) {
            return;
        }
        $items = new \RecursiveIteratorIterator(
            new \RecursiveDirectoryIterator($dir, \FilesystemIterator::SKIP_DOTS),
            \RecursiveIteratorIterator::CHILD_FIRST
        );
        foreach ($items as $item) {
            $item->isDir() ? rmdir($item->getPathname()) : unlink($item->getPathname());
        }
        rmdir($dir);
    }

    private function createStorageArchive(string $target): void
    {
        $storagePath = base_path('storage');
        if (! is_dir($storagePath)) {
            return;
        }

        $this->createTarFromPaths($target, base_path(), ['storage'], [
            'storage/backups',
            'storage/app/tmp',
        ]);
    }

    private function createPublicImagesArchive(string $target): void
    {
        $imagesPath = base_path('public/images');
        if (! is_dir($imagesPath)) {
            return;
        }

        $this->createTarFromPaths($target, base_path(), ['public/images'], []);
    }

    private function createDatabaseDump(string $target): void
    {
        $dumpBin = $this->findBinary(['mariadb-dump', 'mysqldump']);
        if (! $dumpBin) {
            return;
        }

        $dbHost = env('DB_HOST', '127.0.0.1');
        $dbPort = env('DB_PORT', '3306');
        $dbName = env('DB_DATABASE', 'planify');
        $dbUser = env('DB_USERNAME', 'planify');
        $dbPass = env('DB_PASSWORD', 'change_me');

        $cmd = [
            $dumpBin,
            '-h', $dbHost,
            '-P', $dbPort,
            '-u', $dbUser,
            $dbName,
        ];

        $this->runCommand($cmd, null, ['MYSQL_PWD' => $dbPass], $target);
    }

    private function restoreDatabase(string $dumpPath): void
    {
        $restoreBin = $this->findBinary(['mariadb', 'mysql']);
        if (! $restoreBin) {
            return;
        }

        $dbHost = env('DB_HOST', '127.0.0.1');
        $dbPort = env('DB_PORT', '3306');
        $dbName = env('DB_DATABASE', 'planify');
        $dbUser = env('DB_USERNAME', 'planify');
        $dbPass = env('DB_PASSWORD', 'change_me');

        $cmd = [
            $restoreBin,
            '-h', $dbHost,
            '-P', $dbPort,
            '-u', $dbUser,
            $dbName,
        ];

        $this->runCommand($cmd, null, ['MYSQL_PWD' => $dbPass], null, $dumpPath);
    }

    private function createBundleArchive(string $workDir, string $target): void
    {
        $this->createTarFromPaths($target, $workDir, ['.'], []);
    }

    private function extractArchive(string $archive, string $dest): void
    {
        $tarBin = $this->findBinary(['tar']);
        if ($tarBin) {
            $this->runCommand([$tarBin, '-xzf', $archive, '-C', $dest]);
            return;
        }

        if (! class_exists(\PharData::class)) {
            throw new \RuntimeException('No archive support available.');
        }

        $phar = new \PharData($archive);
        $phar->extractTo($dest, null, true);
    }

    private function createTarFromPaths(string $target, string $baseDir, array $paths, array $excludes): void
    {
        $tarBin = $this->findBinary(['tar']);
        if ($tarBin) {
            $cmd = [$tarBin, '-czf', $target, '-C', $baseDir];
            foreach ($excludes as $exclude) {
                $cmd[] = '--exclude=' . $exclude;
            }
            foreach ($paths as $path) {
                $cmd[] = $path;
            }
            $this->runCommand($cmd);
            return;
        }

        if (! class_exists(\PharData::class)) {
            throw new \RuntimeException('No archive support available.');
        }

        $tarPath = str_replace('.gz', '', $target);
        $phar = new \PharData($tarPath);
        foreach ($paths as $path) {
            $full = $baseDir . '/' . $path;
            if (is_dir($full)) {
                $iterator = new \RecursiveIteratorIterator(
                    new \RecursiveDirectoryIterator($full, \FilesystemIterator::SKIP_DOTS)
                );
                foreach ($iterator as $file) {
                    $relative = ltrim(str_replace($baseDir . '/', '', $file->getPathname()), '/');
                    if ($this->isExcluded($relative, $excludes)) {
                        continue;
                    }
                    $phar->addFile($file->getPathname(), $relative);
                }
            } elseif (is_file($full)) {
                $relative = ltrim(str_replace($baseDir . '/', '', $full), '/');
                if (! $this->isExcluded($relative, $excludes)) {
                    $phar->addFile($full, $relative);
                }
            }
        }
        $phar->compress(\Phar::GZ);
        unset($phar);
        if (is_file($tarPath)) {
            unlink($tarPath);
        }
    }

    private function isExcluded(string $relative, array $excludes): bool
    {
        foreach ($excludes as $exclude) {
            if (str_starts_with($relative, $exclude)) {
                return true;
            }
        }
        return false;
    }

    public function resolveBackupPath(string $backupFile): ?string
    {
        $dir = $this->ensureBackupDir();
        if (str_contains($backupFile, DIRECTORY_SEPARATOR)) {
            $real = realpath($backupFile);
        } else {
            $real = realpath($dir . '/' . $backupFile);
        }
        if (! $real || ! str_starts_with($real, realpath($dir))) {
            return null;
        }
        return $real;
    }

    private function findBinary(array $names): ?string
    {
        foreach ($names as $name) {
            $paths = ['/usr/bin/' . $name, '/bin/' . $name, '/usr/local/bin/' . $name];
            foreach ($paths as $path) {
                if (is_executable($path)) {
                    return $path;
                }
            }
        }
        return null;
    }

    private function runCommand(array $cmd, ?string $cwd = null, array $env = [], ?string $stdoutFile = null, ?string $stdinFile = null): void
    {
        $descriptors = [
            0 => ['pipe', 'r'],
            1 => $stdoutFile ? ['file', $stdoutFile, 'w'] : ['pipe', 'w'],
            2 => ['pipe', 'w'],
        ];

        $baseEnv = [];
        foreach ($_ENV as $key => $value) {
            if (is_scalar($value) || $value === null) {
                $baseEnv[$key] = (string) $value;
            }
        }
        foreach ($env as $key => $value) {
            if (is_scalar($value) || $value === null) {
                $baseEnv[$key] = (string) $value;
            }
        }

        $process = proc_open($cmd, $descriptors, $pipes, $cwd, $baseEnv, ['bypass_shell' => true]);
        if (! is_resource($process)) {
            throw new \RuntimeException('Failed to start backup command.');
        }

        if ($stdinFile) {
            $in = fopen($stdinFile, 'r');
            if ($in) {
                stream_copy_to_stream($in, $pipes[0]);
                fclose($in);
            }
        }
        fclose($pipes[0]);

        if (! $stdoutFile) {
            stream_get_contents($pipes[1]);
        }
        fclose($pipes[1]);

        $stderr = stream_get_contents($pipes[2]);
        fclose($pipes[2]);

        $status = proc_close($process);
        if ($status !== 0) {
            throw new \RuntimeException(trim($stderr) ?: 'Backup command failed.');
        }
    }

    private function fixPermissions(): void
    {
        $paths = [
            base_path('storage'),
            base_path('public/images'),
        ];
        foreach ($paths as $path) {
            if (is_dir($path)) {
                @chmod($path, 0775);
            }
        }
    }
}
