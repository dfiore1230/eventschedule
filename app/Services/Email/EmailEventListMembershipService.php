<?php

namespace App\Services\Email;

use App\Models\EmailSubscription;
use App\Models\Sale;

class EmailEventListMembershipService
{
    public function __construct(
        protected EmailListService $listService,
        protected EmailSubscriptionService $subscriptionService
    ) {
    }

    public function handleSalePaid(Sale $sale): void
    {
        $event = $sale->event;
        if (! $event || ! $sale->email) {
            return;
        }

        $subscriber = $this->subscriptionService->upsertSubscriber(
            $sale->email,
            $sale->name,
            null,
            'ticket_purchase'
        );

        $list = $this->listService->getEventList($event);

        $metadata = [
            'ticket_status' => 'paid',
            'marketing_opt_in' => (bool) ($sale->marketing_opt_in ?? false),
        ];

        $this->subscriptionService->upsertSubscription(
            $subscriber,
            $list,
            EmailSubscription::STATUS_SUBSCRIBED,
            'ticket_purchase',
            'system',
            $metadata
        );
    }

    public function handleSaleRefunded(Sale $sale): void
    {
        $event = $sale->event;
        if (! $event || ! $sale->email) {
            return;
        }

        $policy = config('mass_email.event_list_membership_on_refund', 'retain');
        $subscriber = $this->subscriptionService->upsertSubscriber(
            $sale->email,
            $sale->name,
            null,
            'ticket_refund'
        );

        $list = $this->listService->getEventList($event);

        if ($policy === 'remove') {
            $subscription = EmailSubscription::query()
                ->where('subscriber_id', $subscriber->getKey())
                ->where('list_id', $list->getKey())
                ->first();

            if ($subscription) {
                $this->subscriptionService->markSubscriptionStatus($subscription, EmailSubscription::STATUS_UNSUBSCRIBED, 'system');
            }

            return;
        }

        $subscription = EmailSubscription::query()->firstOrNew([
            'subscriber_id' => $subscriber->getKey(),
            'list_id' => $list->getKey(),
        ]);

        if (! $subscription->exists) {
            $subscription->status = EmailSubscription::STATUS_SUBSCRIBED;
            $subscription->status_updated_at = now();
            $subscription->status_updated_by = 'system';
        }

        $existing = $subscription->metadata ?? [];
        $subscription->metadata = array_merge($existing, ['ticket_status' => 'refunded']);
        $subscription->source = 'ticket_refund';
        $subscription->save();
    }
}
