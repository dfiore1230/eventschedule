<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class EmailSuppression extends Model
{
    public const REASON_BOUNCE = 'bounce';
    public const REASON_COMPLAINT = 'complaint';
    public const REASON_MANUAL = 'manual';

    protected $fillable = [
        'email',
        'reason',
    ];

    protected static function booted(): void
    {
        static::saving(function (self $suppression) {
            $suppression->email = EmailSubscriber::normalizeEmail($suppression->email);
        });
    }
}
