<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('event_notification_settings', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('event_id');
            $table->json('settings')->nullable();
            $table->timestamps();

            $table->unique('event_id');
            $table->foreign('event_id')->references('id')->on('events')->onDelete('cascade');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('event_notification_settings');
    }
};
