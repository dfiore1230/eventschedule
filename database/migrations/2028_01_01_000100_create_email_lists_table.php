<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('email_lists', function (Blueprint $table) {
            $table->id();
            $table->string('type');
            $table->foreignId('event_id')->nullable()->constrained('events')->nullOnDelete();
            $table->string('name');
            $table->string('key')->nullable();
            $table->timestamps();

            $table->unique(['type', 'event_id']);
            $table->unique('key');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('email_lists');
    }
};
