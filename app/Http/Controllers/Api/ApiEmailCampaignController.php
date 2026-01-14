<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Jobs\SendEmailCampaignJob;
use App\Models\EmailCampaign;
use App\Models\EmailList;
use App\Services\Email\EmailProviderInterface;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

class ApiEmailCampaignController extends Controller
{
    public function store(Request $request, EmailProviderInterface $provider)
    {
        $user = $request->user();
        if (! $user) {
            return response()->json(['error' => 'Unauthorized'], 403);
        }

        $validated = $request->validate([
            'subject' => ['required', 'string', 'max:255'],
            'from_name' => ['nullable', 'string', 'max:255'],
            'from_email' => ['required', 'string', 'email', 'max:255'],
            'reply_to' => ['nullable', 'string', 'email', 'max:255'],
            'content_html' => ['nullable', 'string'],
            'content_text' => ['nullable', 'string'],
            'email_type' => ['required', 'string', 'in:marketing,notification'],
            'list_ids' => ['required', 'array', 'min:1'],
            'list_ids.*' => ['integer'],
        ]);

        if (! $validated['content_html'] && ! $validated['content_text']) {
            return response()->json(['error' => 'Content is required'], 422);
        }

        if (! $provider->validateFromAddress($validated['from_email'])) {
            return response()->json(['error' => 'Invalid from address'], 422);
        }

        $lists = EmailList::query()->with('event')->whereIn('id', $validated['list_ids'])->get();

        if ($lists->count() !== count($validated['list_ids'])) {
            return response()->json(['error' => 'Invalid list selection'], 422);
        }

        if (! $this->canSendToLists($user, $lists)) {
            return response()->json(['error' => 'Unauthorized'], 403);
        }

        $campaign = EmailCampaign::create([
            'created_by' => $user->getKey(),
            'email_type' => $validated['email_type'],
            'subject' => $validated['subject'],
            'from_name' => $validated['from_name'] ?: config('mass_email.default_from_name'),
            'from_email' => $validated['from_email'],
            'reply_to' => $validated['reply_to'] ?: config('mass_email.default_reply_to'),
            'content_html' => $validated['content_html'],
            'content_text' => $validated['content_text'],
            'status' => EmailCampaign::STATUS_DRAFT,
        ]);

        $campaign->lists()->sync($lists->pluck('id')->all());

        Log::info('Email campaign created', [
            'campaign_id' => $campaign->id,
            'created_by' => $campaign->created_by,
        ]);

        return response()->json(['data' => $campaign], 201);
    }

    public function send(Request $request, int $campaignId)
    {
        $user = $request->user();
        $campaign = EmailCampaign::with('lists.event')->findOrFail($campaignId);

        if (! $user || ! $this->canSendToLists($user, $campaign->lists)) {
            return response()->json(['error' => 'Unauthorized'], 403);
        }

        $validated = $request->validate([
            'scheduled_at' => ['nullable', 'date'],
        ]);

        $campaign->scheduled_at = $validated['scheduled_at'] ?? null;
        $campaign->status = $campaign->scheduled_at ? EmailCampaign::STATUS_SCHEDULED : EmailCampaign::STATUS_SENDING;
        $campaign->save();

        $job = SendEmailCampaignJob::dispatch($campaign->id);

        if ($campaign->scheduled_at) {
            $job->delay($campaign->scheduled_at);
        }

        return response()->json(['status' => 'ok']);
    }

    public function show(Request $request, int $campaignId)
    {
        $user = $request->user();
        $campaign = EmailCampaign::with(['lists.event', 'stats'])->findOrFail($campaignId);

        if (! $user || ! $this->canSendToLists($user, $campaign->lists)) {
            return response()->json(['error' => 'Unauthorized'], 403);
        }

        return response()->json(['data' => $campaign]);
    }

    private function canSendToLists($user, $lists): bool
    {
        foreach ($lists as $list) {
            if ($list->type === EmailList::TYPE_GLOBAL) {
                if (! $user->isAdmin()) {
                    return false;
                }
                continue;
            }

            if ($list->event && ! $user->canEditEvent($list->event)) {
                return false;
            }
        }

        return true;
    }
}
