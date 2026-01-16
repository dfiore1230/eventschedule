<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class EmailCampaignRecipient extends Model
{
    public const STATUS_ACCEPTED = 'accepted';
    public const STATUS_SUPPRESSED = 'suppressed';
    public const STATUS_BOUNCED = 'bounced';
    public const STATUS_COMPLAINT = 'complaint';

    protected $fillable = [
        'campaign_id',
        'subscriber_id',
        'list_id',
        'email',
        'status',
        'suppression_reason',
        'provider_message_id',
        'sent_at',
        'bounced_at',
        'complained_at',
    ];

    protected $casts = [
        'sent_at' => 'datetime',
        'bounced_at' => 'datetime',
        'complained_at' => 'datetime',
    ];

    public function campaign(): BelongsTo
    {
        return $this->belongsTo(EmailCampaign::class, 'campaign_id');
    }

    public function subscriber(): BelongsTo
    {
        return $this->belongsTo(EmailSubscriber::class, 'subscriber_id');
    }

    public function list(): BelongsTo
    {
        return $this->belongsTo(EmailList::class, 'list_id');
    }
}
