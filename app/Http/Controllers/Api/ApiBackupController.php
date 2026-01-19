<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\BackupService;
use Illuminate\Http\Request;

class ApiBackupController extends Controller
{
    public function index(BackupService $service)
    {
        return response()->json([
            'data' => $service->listBackups(),
        ]);
    }

    public function store(BackupService $service)
    {
        $backup = $service->createBackup();

        return response()->json([
            'message' => 'Backup created.',
            'data' => $backup,
        ]);
    }

    public function restore(Request $request, BackupService $service)
    {
        $request->validate([
            'confirm' => ['required', 'boolean'],
            'filename' => ['nullable', 'string'],
            'backup' => ['nullable', 'file'],
        ]);

        if (! $request->boolean('confirm')) {
            return response()->json([
                'message' => 'Restore confirmation required.',
            ], 422);
        }

        $backupPath = $request->input('filename');
        if ($request->hasFile('backup')) {
            $meta = $service->storeUploadedBackup($request->file('backup'));
            $backupPath = $meta['name'] ?? null;
        }

        if (! $backupPath) {
            return response()->json([
                'message' => 'Backup file is required.',
            ], 422);
        }

        $service->restoreBackup($backupPath);

        return response()->json([
            'message' => 'Restore completed.',
        ]);
    }
}
