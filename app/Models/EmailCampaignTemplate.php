<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class EmailCampaignTemplate extends Model
{
    public const SCOPE_GLOBAL = 'global';
    public const SCOPE_EVENT = 'event';

    protected $fillable = [
        'name',
        'scope',
        'event_id',
        'created_by',
        'subject',
        'from_name',
        'from_email',
        'reply_to',
        'email_type',
        'content_markdown',
    ];

    protected $casts = [
        'event_id' => 'integer',
        'created_by' => 'integer',
    ];

    public function event(): BelongsTo
    {
        return $this->belongsTo(Event::class);
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }
}
