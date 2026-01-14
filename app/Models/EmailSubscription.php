<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class EmailSubscription extends Model
{
    public const STATUS_SUBSCRIBED = 'subscribed';
    public const STATUS_UNSUBSCRIBED = 'unsubscribed';
    public const STATUS_PENDING = 'pending';

    protected $fillable = [
        'subscriber_id',
        'list_id',
        'status',
        'status_updated_at',
        'status_updated_by',
        'source',
        'metadata',
    ];

    protected $casts = [
        'status_updated_at' => 'datetime',
        'metadata' => 'array',
    ];

    public function subscriber(): BelongsTo
    {
        return $this->belongsTo(EmailSubscriber::class, 'subscriber_id');
    }

    public function list(): BelongsTo
    {
        return $this->belongsTo(EmailList::class, 'list_id');
    }
}
