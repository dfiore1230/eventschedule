<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

class EmailCampaign extends Model
{
    public const TYPE_MARKETING = 'marketing';
    public const TYPE_NOTIFICATION = 'notification';

    public const STATUS_DRAFT = 'draft';
    public const STATUS_SCHEDULED = 'scheduled';
    public const STATUS_SENDING = 'sending';
    public const STATUS_SENT = 'sent';
    public const STATUS_FAILED = 'failed';
    public const STATUS_CANCELLED = 'cancelled';

    protected $fillable = [
        'created_by',
        'email_type',
        'subject',
        'from_name',
        'from_email',
        'reply_to',
        'content_html',
        'content_text',
        'content_markdown',
        'status',
        'scheduled_at',
        'metadata',
    ];

    protected $casts = [
        'scheduled_at' => 'datetime',
        'metadata' => 'array',
    ];

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function lists(): BelongsToMany
    {
        return $this->belongsToMany(EmailList::class, 'email_campaign_lists', 'campaign_id', 'list_id');
    }

    public function stats(): HasOne
    {
        return $this->hasOne(EmailCampaignRecipientStat::class, 'campaign_id');
    }

    public function recipients()
    {
        return $this->hasMany(EmailCampaignRecipient::class, 'campaign_id');
    }
}
