<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class EmailCampaignRecipientStat extends Model
{
    protected $fillable = [
        'campaign_id',
        'targeted_count',
        'suppressed_count',
        'provider_accepted_count',
        'delivered_count',
        'bounced_count',
    ];

    public function campaign(): BelongsTo
    {
        return $this->belongsTo(EmailCampaign::class, 'campaign_id');
    }
}
