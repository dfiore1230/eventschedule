<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class EventInvite extends Model
{
    use HasFactory;

    protected $fillable = [
        'event_id',
        'email',
        'token',
        'used_at',
    ];

    protected $casts = [
        'used_at' => 'datetime',
    ];

    public function event(): BelongsTo
    {
        return $this->belongsTo(Event::class);
    }

    public function getInviteUrl(?string $subdomain = null): string
    {
        $event = $this->event;

        if (! $event) {
            return '';
        }

        if (! $subdomain) {
            $subdomain = $event->getGuestUrlData()['subdomain'] ?? null;
        }

        if (! $subdomain) {
            return '';
        }

        return route('event.invite', [
            'subdomain' => $subdomain,
            'token' => $this->token,
        ]);
    }
}
