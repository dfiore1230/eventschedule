<?php

namespace App\Jobs;

use App\Models\EmailCampaign;
use App\Models\EmailCampaignRecipientStat;
use App\Models\EmailCampaignRecipient;
use App\Models\EmailSubscription;
use App\Models\EmailSuppression;
use App\Services\Email\EmailMessage;
use App\Services\Email\EmailProviderInterface;
use App\Services\Email\EmailTemplateRenderer;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\URL;
use Illuminate\Support\Str;

class SendEmailCampaignJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $tries;
    public array|int $backoff;

    public function __construct(public int $campaignId)
    {
        $this->tries = max((int) config('mass_email.retry_attempts', 3), 1);
        $this->backoff = $this->resolveBackoff(config('mass_email.retry_backoff_seconds', [60, 300, 900]));
    }

    public function handle(EmailProviderInterface $provider, EmailTemplateRenderer $renderer): void
    {
        $campaign = EmailCampaign::with(['lists.event', 'stats'])->find($this->campaignId);

        if (! $campaign) {
            return;
        }

        if (! in_array($campaign->status, [EmailCampaign::STATUS_SCHEDULED, EmailCampaign::STATUS_SENDING], true)) {
            return;
        }

        if ($campaign->scheduled_at && now()->lt($campaign->scheduled_at)) {
            $this->release($campaign->scheduled_at->diffInSeconds(now()));

            return;
        }

        if ($campaign->lists->isEmpty()) {
            $campaign->status = EmailCampaign::STATUS_FAILED;
            $campaign->save();
            Log::warning('Email campaign missing recipient lists', ['campaign_id' => $campaign->id]);

            return;
        }

        $campaign->status = EmailCampaign::STATUS_SENDING;
        $campaign->save();

        $batchSize = (int) config('mass_email.batch_size', 500);
        $rateLimit = max((int) config('mass_email.rate_limit_per_minute', 1200), 1);
        $sleepSeconds = ($batchSize / $rateLimit) * 60;

        $targetedCount = 0;
        $suppressedCount = 0;
        $acceptedCount = 0;
        $messages = [];
        $seenEmails = [];
        $providerUnsubscribes = [];

        $listIds = $campaign->lists->pluck('id')->all();

        $query = EmailSubscription::query()
            ->with(['subscriber', 'list.event'])
            ->whereIn('list_id', $listIds);

        if ($campaign->email_type === EmailCampaign::TYPE_MARKETING) {
            $query->where('status', EmailSubscription::STATUS_SUBSCRIBED);
        } else {
            $query->where('status', '!=', EmailSubscription::STATUS_PENDING);
        }

        $query->chunkById($batchSize, function ($subscriptions) use (
            $campaign,
            $provider,
            $renderer,
            $batchSize,
            $sleepSeconds,
            &$targetedCount,
            &$suppressedCount,
            &$acceptedCount,
            &$messages,
            &$seenEmails,
            &$providerUnsubscribes
        ) {
            $emails = $subscriptions
                ->pluck('subscriber.email')
                ->filter()
                ->map(fn ($email) => strtolower(trim((string) $email)))
                ->unique()
                ->values()
                ->all();

            $suppressed = EmailSuppression::query()
                ->whereIn('email', $emails)
                ->pluck('email')
                ->map(fn ($email) => strtolower(trim((string) $email)))
                ->flip();

            foreach ($subscriptions as $subscription) {
                $subscriber = $subscription->subscriber;

                if (! $subscriber || ! $subscriber->email) {
                    continue;
                }

                $email = strtolower(trim((string) $subscriber->email));

                if (isset($seenEmails[$email])) {
                    continue;
                }

                $seenEmails[$email] = true;
                $targetedCount++;

                $suppressionReason = null;

                if ($campaign->email_type === EmailCampaign::TYPE_MARKETING && $subscriber->marketing_unsubscribed_at) {
                    $suppressedCount++;
                    $suppressionReason = 'marketing_unsubscribed';
                    $providerUnsubscribes[$email] = true;
                }

                if ($campaign->email_type === EmailCampaign::TYPE_MARKETING && $suppressionReason === null) {
                    $marketingOptIn = $subscription->metadata['marketing_opt_in'] ?? true;
                    if ($marketingOptIn === false) {
                        $suppressedCount++;
                        $suppressionReason = 'marketing_opt_out';
                        $providerUnsubscribes[$email] = true;
                    }
                }

                if ($suppressionReason === null && $suppressed->has($email)) {
                    $suppressedCount++;
                    $suppressionReason = 'suppressed';
                }

                $list = $subscription->list;
                $event = $list?->event;

                $mergeData = [
                    'firstName' => $subscriber->first_name ?: 'there',
                    'lastName' => $subscriber->last_name ?: '',
                    'email' => $subscriber->email,
                    'eventName' => $event?->translatedName() ?? $event?->name ?? '',
                    'eventDate' => $event?->starts_at ?? '',
                ];

                if ($campaign->email_type === EmailCampaign::TYPE_MARKETING) {
                    $mergeData['unsubscribeUrl'] = $this->buildUnsubscribeUrl($subscriber->getKey(), $subscription->list_id);
                    $mergeData['unsubscribeAllUrl'] = $this->buildUnsubscribeAllUrl($subscriber->getKey());
                } else {
                    $mergeData['unsubscribeUrl'] = '';
                    $mergeData['unsubscribeAllUrl'] = '';
                }

                $subject = $renderer->render($campaign->subject, $mergeData);
                $html = $renderer->render($campaign->content_html, $mergeData);
                $text = $renderer->render($campaign->content_text, $mergeData);

                if ($campaign->email_type === EmailCampaign::TYPE_MARKETING) {
                    $html = $this->ensureUnsubscribeFooter($html, $mergeData['unsubscribeUrl'], $mergeData['unsubscribeAllUrl'], true);
                    $text = $this->ensureUnsubscribeFooter($text, $mergeData['unsubscribeUrl'], $mergeData['unsubscribeAllUrl'], false);
                }

                $headers = [
                    'X-ES-Email-Type' => $campaign->email_type,
                    'X-ES-Campaign-Id' => $campaign->id,
                    'X-ES-List-Id' => $subscription->list_id,
                    'X-ES-Event-Id' => $list?->event_id,
                ];

                if ($campaign->email_type === EmailCampaign::TYPE_MARKETING && $mergeData['unsubscribeUrl']) {
                    $headers['List-Unsubscribe'] = '<' . $mergeData['unsubscribeUrl'] . '>';
                    if (! empty($mergeData['unsubscribeAllUrl'])) {
                        $headers['List-Unsubscribe'] .= ', <' . $mergeData['unsubscribeAllUrl'] . '>';
                    }
                }

                $recipientAttributes = [
                    'campaign_id' => $campaign->id,
                    'subscriber_id' => $subscriber->getKey(),
                ];

                $recipientValues = [
                    'list_id' => $subscription->list_id,
                    'email' => $subscriber->email,
                    'status' => $suppressionReason ? EmailCampaignRecipient::STATUS_SUPPRESSED : EmailCampaignRecipient::STATUS_ACCEPTED,
                    'suppression_reason' => $suppressionReason,
                    'sent_at' => $suppressionReason ? null : now(),
                ];

                EmailCampaignRecipient::query()->updateOrCreate($recipientAttributes, $recipientValues);

                if ($suppressionReason) {
                    continue;
                }

                $messages[] = new EmailMessage(
                    $subscriber->email,
                    trim($subscriber->first_name . ' ' . $subscriber->last_name) ?: null,
                    $subject,
                    $campaign->from_email,
                    $campaign->from_name,
                    $campaign->reply_to,
                    $html ?: null,
                    $text ?: null,
                    $headers,
                    [
                        'campaign_id' => $campaign->id,
                        'list_id' => $subscription->list_id,
                        'event_id' => $list?->event_id,
                        'email_type' => $campaign->email_type,
                    ]
                );

                if (count($messages) >= $batchSize) {
                    $result = $provider->sendBatch($messages);
                    $acceptedCount += $result->acceptedCount;
                    $this->updateProviderMessageIds($campaign->id, $result->messageIds);
                    $messages = [];

                    if ($sleepSeconds > 0) {
                        usleep((int) ($sleepSeconds * 1000000));
                    }
                }
            }

            if ($providerUnsubscribes !== []) {
                $provider->syncSuppressions(array_keys($providerUnsubscribes), 'unsubscribe');
                $providerUnsubscribes = [];
            }
        });

        if ($messages !== []) {
            $result = $provider->sendBatch($messages);
            $acceptedCount += $result->acceptedCount;
            $this->updateProviderMessageIds($campaign->id, $result->messageIds);
        }

        $stats = $campaign->stats ?: new EmailCampaignRecipientStat(['campaign_id' => $campaign->id]);
        $stats->targeted_count = $targetedCount;
        $stats->suppressed_count = $suppressedCount;
        $stats->provider_accepted_count = $acceptedCount;
        $stats->save();

        $campaign->status = $targetedCount > 0 && $acceptedCount === 0
            ? EmailCampaign::STATUS_FAILED
            : EmailCampaign::STATUS_SENT;
        $campaign->save();

        Log::info('Email campaign sent', [
            'campaign_id' => $campaign->id,
            'targeted' => $targetedCount,
            'suppressed' => $suppressedCount,
            'accepted' => $acceptedCount,
        ]);
    }

    private function updateProviderMessageIds(int $campaignId, array $messageIds): void
    {
        foreach ($messageIds as $email => $messageId) {
            if (! $email || ! $messageId) {
                continue;
            }

            EmailCampaignRecipient::query()
                ->where('campaign_id', $campaignId)
                ->where('email', $email)
                ->update(['provider_message_id' => $messageId]);
        }
    }

    public function failed(\Throwable $exception): void
    {
        $campaign = EmailCampaign::query()->find($this->campaignId);

        if (! $campaign) {
            return;
        }

        $campaign->status = EmailCampaign::STATUS_FAILED;
        $campaign->save();

        Log::error('Email campaign failed', [
            'campaign_id' => $campaign->id,
            'error' => $exception->getMessage(),
        ]);
    }

    private function resolveBackoff(mixed $configValue): array|int
    {
        if (is_array($configValue)) {
            return $configValue;
        }

        if (is_numeric($configValue)) {
            return (int) $configValue;
        }

        $parts = array_filter(array_map('trim', explode(',', (string) $configValue)));

        if ($parts === []) {
            return 60;
        }

        return array_map(static fn ($part) => (int) $part, $parts);
    }

    private function buildUnsubscribeUrl(int $subscriberId, int $listId): string
    {
        $ttlMinutes = (int) config('mass_email.unsubscribe_token_ttl_minutes', 525600);

        return URL::temporarySignedRoute('public.unsubscribe', now()->addMinutes($ttlMinutes), [
            'subscriber' => $subscriberId,
            'list' => $listId,
            'scope' => 'list',
        ]);
    }

    private function buildUnsubscribeAllUrl(int $subscriberId): string
    {
        $ttlMinutes = (int) config('mass_email.unsubscribe_token_ttl_minutes', 525600);

        return URL::temporarySignedRoute('public.unsubscribe', now()->addMinutes($ttlMinutes), [
            'subscriber' => $subscriberId,
            'scope' => 'all',
        ]);
    }

    private function ensureUnsubscribeFooter(
        string $content,
        string $unsubscribeUrl,
        string $unsubscribeAllUrl,
        bool $isHtml
    ): string
    {
        if ($content === '') {
            return $content;
        }

        if ($unsubscribeUrl !== '' && Str::contains($content, $unsubscribeUrl)) {
            return $content;
        }

        $footer = (string) config('mass_email.unsubscribe_footer', '');
        $physicalAddress = (string) config('mass_email.physical_address', '');

        if ($footer === '') {
            $footer = 'Unsubscribe: ' . $unsubscribeUrl;
            if ($unsubscribeAllUrl !== '') {
                $footer .= ' | Unsubscribe from all: ' . $unsubscribeAllUrl;
            }
            if ($physicalAddress !== '') {
                $footer .= ' | ' . $physicalAddress;
            }
        } else {
            $footer = str_replace(
                ['{{unsubscribeUrl}}', '{{unsubscribeAllUrl}}', '{{physicalAddress}}'],
                [$unsubscribeUrl, $unsubscribeAllUrl, $physicalAddress],
                $footer
            );
        }

        if ($isHtml && Str::contains($content, '</body>')) {
            return Str::replaceLast('</body>', '<p>' . e($footer) . '</p></body>', $content);
        }

        if ($isHtml) {
            return $content . '<p>' . e($footer) . '</p>';
        }

        return $content . "\n\n" . $footer;
    }
}
