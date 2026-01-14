<?php

namespace App\Http\Controllers;

use App\Models\EmailCampaignRecipientStat;
use App\Models\EmailSubscriber;
use App\Models\EmailSubscription;
use App\Models\EmailSuppression;
use App\Services\Email\EmailProviderInterface;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

class EmailProviderWebhookController extends Controller
{
    public function handle(Request $request, EmailProviderInterface $provider)
    {
        $result = $provider->parseWebhook($request);

        $this->handleSuppressionEvents($result->bounces, EmailSuppression::REASON_BOUNCE, true);
        $this->handleSuppressionEvents($result->complaints, EmailSuppression::REASON_COMPLAINT, false);
        $this->handleUnsubscribeEvents($result->unsubscribes);

        return response()->json(['status' => 'ok']);
    }

    private function handleSuppressionEvents(array $events, string $reason, bool $incrementBounce): void
    {
        foreach ($events as $event) {
            $email = $event['email'] ?? null;
            $campaignId = $event['campaign_id'] ?? null;

            if (! $email) {
                continue;
            }

            EmailSuppression::query()->updateOrCreate(
                ['email' => EmailSubscriber::normalizeEmail($email)],
                ['reason' => $reason]
            );

            if ($campaignId && $incrementBounce) {
                $stats = EmailCampaignRecipientStat::query()->firstOrCreate(['campaign_id' => $campaignId]);
                $stats->bounced_count += 1;
                $stats->save();
            }
        }
    }

    private function handleUnsubscribeEvents(array $events): void
    {
        foreach ($events as $event) {
            $email = $event['email'] ?? null;
            $listId = $event['list_id'] ?? null;
            $unsubscribeAll = (bool) ($event['unsubscribe_all'] ?? false);

            if (! $email) {
                continue;
            }

            $subscriber = EmailSubscriber::query()->where('email', EmailSubscriber::normalizeEmail($email))->first();

            if (! $subscriber) {
                continue;
            }

            if ($unsubscribeAll) {
                $subscriber->marketing_unsubscribed_at = now();
                $subscriber->save();
                continue;
            }

            if ($listId) {
                EmailSubscription::query()
                    ->where('subscriber_id', $subscriber->getKey())
                    ->where('list_id', $listId)
                    ->update([
                        'status' => EmailSubscription::STATUS_UNSUBSCRIBED,
                        'status_updated_at' => now(),
                        'status_updated_by' => 'provider',
                    ]);
            }
        }

        if ($events !== []) {
            Log::info('Processed email provider unsubscribe events', ['count' => count($events)]);
        }
    }
}
