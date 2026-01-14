<?php

namespace App\Services\Email;

use App\Models\EmailList;
use App\Models\EmailSubscriber;
use App\Models\EmailSubscription;

class EmailSubscriptionService
{
    public function upsertSubscriber(
        string $email,
        ?string $firstName = null,
        ?string $lastName = null,
        ?string $source = null
    ): EmailSubscriber {
        $normalized = EmailSubscriber::normalizeEmail($email);

        $subscriber = EmailSubscriber::query()->firstOrNew(['email' => $normalized]);
        $subscriber->first_name = $firstName ?: $subscriber->first_name;
        $subscriber->last_name = $lastName ?: $subscriber->last_name;
        $subscriber->source = $source ?: $subscriber->source;
        $subscriber->save();

        return $subscriber;
    }

    public function upsertSubscription(
        EmailSubscriber $subscriber,
        EmailList $list,
        string $status,
        string $source,
        string $updatedBy,
        array $metadata = []
    ): EmailSubscription {
        $subscription = EmailSubscription::query()->firstOrNew([
            'subscriber_id' => $subscriber->getKey(),
            'list_id' => $list->getKey(),
        ]);

        $subscription->status = $status;
        $subscription->status_updated_at = now();
        $subscription->status_updated_by = $updatedBy;
        $subscription->source = $source;

        if ($metadata !== []) {
            $existing = $subscription->metadata ?? [];
            $subscription->metadata = array_merge($existing, $metadata);
        }

        $subscription->save();

        return $subscription;
    }

    public function markSubscriptionStatus(EmailSubscription $subscription, string $status, string $updatedBy): EmailSubscription
    {
        $subscription->status = $status;
        $subscription->status_updated_at = now();
        $subscription->status_updated_by = $updatedBy;
        $subscription->save();

        return $subscription;
    }

    public function markAllMarketingUnsubscribed(EmailSubscriber $subscriber): void
    {
        $subscriber->marketing_unsubscribed_at = now();
        $subscriber->save();
    }
}
