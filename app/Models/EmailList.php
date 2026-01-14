<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;

class EmailList extends Model
{
    public const TYPE_GLOBAL = 'global';
    public const TYPE_EVENT = 'event';

    protected $fillable = [
        'type',
        'event_id',
        'name',
        'key',
    ];

    public function event(): BelongsTo
    {
        return $this->belongsTo(Event::class);
    }

    public function subscriptions(): HasMany
    {
        return $this->hasMany(EmailSubscription::class, 'list_id');
    }

    public function subscribers(): BelongsToMany
    {
        return $this->belongsToMany(EmailSubscriber::class, 'email_subscriptions', 'list_id', 'subscriber_id');
    }
}
