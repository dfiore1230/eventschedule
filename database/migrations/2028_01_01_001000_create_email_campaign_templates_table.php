<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('email_campaign_templates', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('scope');
            $table->unsignedBigInteger('event_id')->nullable();
            $table->unsignedBigInteger('created_by')->nullable();
            $table->string('subject');
            $table->string('from_name');
            $table->string('from_email');
            $table->string('reply_to')->nullable();
            $table->string('email_type');
            $table->text('content_markdown');
            $table->timestamps();

            $table->index(['scope', 'event_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('email_campaign_templates');
    }
};
