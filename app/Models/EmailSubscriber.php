<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;

class EmailSubscriber extends Model
{
    protected $fillable = [
        'email',
        'first_name',
        'last_name',
        'source',
        'marketing_unsubscribed_at',
    ];

    protected $casts = [
        'marketing_unsubscribed_at' => 'datetime',
    ];

    protected static function booted(): void
    {
        static::saving(function (self $subscriber) {
            $subscriber->email = self::normalizeEmail($subscriber->email);
        });
    }

    public static function normalizeEmail(string $email): string
    {
        return strtolower(trim($email));
    }

    public function subscriptions(): HasMany
    {
        return $this->hasMany(EmailSubscription::class, 'subscriber_id');
    }

    public function lists(): BelongsToMany
    {
        return $this->belongsToMany(EmailList::class, 'email_subscriptions', 'subscriber_id', 'list_id');
    }
}
