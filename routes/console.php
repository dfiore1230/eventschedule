<?php

use Illuminate\Support\Facades\Schedule;
use Illuminate\Support\Facades\Artisan;

Schedule::call(function () {
    Artisan::call('app:release-tickets');
})->hourly()->appendOutputTo(storage_path('logs/scheduler.log'));

Schedule::call(function () {
    Artisan::call('app:translate');
})->hourly()->appendOutputTo(storage_path('logs/scheduler.log'));

Schedule::call(function () {
    Artisan::call('google:refresh-webhooks');
})->daily()->appendOutputTo(storage_path('logs/scheduler.log'));
