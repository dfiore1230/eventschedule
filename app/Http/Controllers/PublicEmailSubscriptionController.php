<?php

namespace App\Http\Controllers;

use App\Mail\ConfirmSubscriptionMail;
use App\Models\EmailList;
use App\Models\EmailSubscriber;
use App\Models\EmailSubscription;
use App\Models\Event;
use App\Services\Email\EmailListService;
use App\Services\Email\EmailSubscriptionService;
use App\Utils\UrlUtils;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\URL;

class PublicEmailSubscriptionController extends Controller
{
    public function subscribe(Request $request, EmailListService $listService, EmailSubscriptionService $subscriptionService)
    {
        $validated = $request->validate([
            'email' => ['required', 'string', 'email', 'max:255'],
            'first_name' => ['nullable', 'string', 'max:255'],
            'last_name' => ['nullable', 'string', 'max:255'],
            'list_id' => ['nullable', 'integer'],
            'event_id' => ['nullable'],
        ]);

        $list = $this->resolveList($validated, $listService);
        $subscriber = $subscriptionService->upsertSubscriber(
            $validated['email'],
            $validated['first_name'] ?? null,
            $validated['last_name'] ?? null,
            'public'
        );

        $doubleOptIn = (bool) config('mass_email.double_opt_in_marketing', true);
        $deliveryDisabled = (bool) config('mail.disable_delivery', false);

        $status = $doubleOptIn ? EmailSubscription::STATUS_PENDING : EmailSubscription::STATUS_SUBSCRIBED;

        // If delivery is disabled, skip double opt-in to avoid transport errors
        if ($deliveryDisabled) {
            $status = EmailSubscription::STATUS_SUBSCRIBED;
        }

        $subscription = $subscriptionService->upsertSubscription(
            $subscriber,
            $list,
            $status,
            'public',
            'subscriber',
            ['marketing_opt_in' => true]
        );

        if ($status === EmailSubscription::STATUS_PENDING) {
            try {
                $confirmUrl = $this->buildConfirmUrl($subscriber, $list);
                Mail::to($subscriber->email)->send(new ConfirmSubscriptionMail($confirmUrl, $list->name));
            } catch (\Throwable $e) {
                Log::warning('Public subscribe confirmation email skipped due to mail transport issue', [
                    'email' => $subscriber->email,
                    'list_id' => $list->id,
                    'error' => $e->getMessage(),
                ]);

                // Fail open: mark subscribed so signups work even when mail is disabled
                $subscriptionService->markSubscriptionStatus($subscription, EmailSubscription::STATUS_SUBSCRIBED, 'system');
            }
        }

        $message = $status === EmailSubscription::STATUS_PENDING
            ? 'If this email is eligible, a confirmation email will be sent shortly.'
            : 'You are subscribed. Thank you!';

        if ($request->expectsJson() || $request->wantsJson() || $request->ajax()) {
            return response()->json([
                'status' => 'ok',
                'message' => $message,
            ], 200);
        }

        return redirect()->back()->with('subscription_status', $message);
    }

    public function confirm(Request $request, EmailSubscriptionService $subscriptionService)
    {
        $subscriberId = (int) $request->query('subscriber');
        $listId = (int) $request->query('list');

        $subscription = EmailSubscription::query()
            ->where('subscriber_id', $subscriberId)
            ->where('list_id', $listId)
            ->first();

        if ($subscription) {
            $subscriptionService->markSubscriptionStatus($subscription, EmailSubscription::STATUS_SUBSCRIBED, 'subscriber');
        }

        return view('public.confirm_subscription');
    }

    public function unsubscribe(Request $request, EmailSubscriptionService $subscriptionService)
    {
        $subscriberId = (int) $request->query('subscriber');
        $listId = (int) $request->query('list');
        $scope = (string) $request->query('scope', 'list');

        $subscriber = EmailSubscriber::query()->find($subscriberId);

        if ($subscriber && $scope === 'all') {
            $subscriptionService->markAllMarketingUnsubscribed($subscriber);
        }

        if ($subscriber && $scope !== 'all' && $listId) {
            $subscription = EmailSubscription::query()
                ->where('subscriber_id', $subscriberId)
                ->where('list_id', $listId)
                ->first();

            if ($subscription) {
                $subscriptionService->markSubscriptionStatus($subscription, EmailSubscription::STATUS_UNSUBSCRIBED, 'subscriber');
            }
        }

        return view('public.unsubscribe');
    }

    private function resolveList(array $validated, EmailListService $listService): EmailList
    {
        if (! empty($validated['list_id'])) {
            $list = EmailList::query()->find($validated['list_id']);
            if ($list) {
                return $list;
            }
        }

        if (! empty($validated['event_id'])) {
            $eventId = $validated['event_id'];
            $decoded = is_numeric($eventId) ? (int) $eventId : UrlUtils::decodeId((string) $eventId);

            if ($decoded) {
                $event = Event::query()->find($decoded);
                if ($event) {
                    return $listService->getEventList($event);
                }
            }
        }

        return $listService->getGlobalList();
    }

    private function buildConfirmUrl(EmailSubscriber $subscriber, EmailList $list): string
    {
        $ttlMinutes = (int) config('mass_email.confirmation_token_ttl_minutes', 10080);

        return URL::temporarySignedRoute('public.confirm', now()->addMinutes($ttlMinutes), [
            'subscriber' => $subscriber->getKey(),
            'list' => $list->getKey(),
        ]);
    }
}
