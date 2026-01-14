<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('email_campaign_lists', function (Blueprint $table) {
            $table->id();
            $table->foreignId('campaign_id')->constrained('email_campaigns')->cascadeOnDelete();
            $table->foreignId('list_id')->constrained('email_lists')->cascadeOnDelete();
            $table->timestamps();

            $table->unique(['campaign_id', 'list_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('email_campaign_lists');
    }
};
