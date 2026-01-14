<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Mail\ConfirmSubscriptionMail;
use App\Models\EmailList;
use App\Models\EmailSubscription;
use App\Services\Email\EmailSubscriptionService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\URL;

class ApiEmailListController extends Controller
{
    public function addSubscriber(Request $request, int $listId, EmailSubscriptionService $subscriptionService)
    {
        $user = $request->user();
        $list = EmailList::query()->with('event')->findOrFail($listId);

        if ($list->type === EmailList::TYPE_GLOBAL) {
            if (! $user || ! $user->isAdmin()) {
                return response()->json(['error' => 'Unauthorized'], 403);
            }
        } elseif ($list->event) {
            if (! $user || ! $user->canEditEvent($list->event)) {
                return response()->json(['error' => 'Unauthorized'], 403);
            }
        } else {
            return response()->json(['error' => 'Invalid list'], 400);
        }

        $validated = $request->validate([
            'email' => ['required', 'string', 'email', 'max:255'],
            'first_name' => ['nullable', 'string', 'max:255'],
            'last_name' => ['nullable', 'string', 'max:255'],
            'intent' => ['required', 'string', 'in:subscribe,invite'],
        ]);

        $subscriber = $subscriptionService->upsertSubscriber(
            $validated['email'],
            $validated['first_name'] ?? null,
            $validated['last_name'] ?? null,
            'admin'
        );

        $status = $validated['intent'] === 'subscribe'
            ? EmailSubscription::STATUS_SUBSCRIBED
            : EmailSubscription::STATUS_PENDING;

        $subscriptionService->upsertSubscription(
            $subscriber,
            $list,
            $status,
            'admin',
            'user:' . $user->getKey(),
            ['marketing_opt_in' => true]
        );

        if ($status === EmailSubscription::STATUS_PENDING) {
            $confirmUrl = $this->buildConfirmUrl($subscriber->getKey(), $list->getKey());
            Mail::to($subscriber->email)->send(new ConfirmSubscriptionMail($confirmUrl, $list->name));
        }

        return response()->json(['status' => 'ok']);
    }

    private function buildConfirmUrl(int $subscriberId, int $listId): string
    {
        $ttlMinutes = (int) config('mass_email.confirmation_token_ttl_minutes', 10080);

        return URL::temporarySignedRoute('public.confirm', now()->addMinutes($ttlMinutes), [
            'subscriber' => $subscriberId,
            'list' => $listId,
        ]);
    }
}
