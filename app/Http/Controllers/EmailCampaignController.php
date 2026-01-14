<?php

namespace App\Http\Controllers;

use App\Jobs\SendEmailCampaignJob;
use App\Models\EmailCampaign;
use App\Models\EmailCampaignRecipient;
use App\Models\EmailSubscriber;
use App\Services\Email\EmailListService;
use App\Services\Email\EmailProviderInterface;
use App\Utils\MarkdownUtils;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Http\RedirectResponse;
use Illuminate\View\View;

class EmailCampaignController extends Controller
{
    public function index(Request $request, EmailListService $listService): View
    {
        $user = $request->user();
        $this->authorizeGlobalAccess($user);

        $globalList = $listService->getGlobalList();

        $campaigns = EmailCampaign::query()
            ->with(['lists', 'stats'])
            ->whereHas('lists', function ($query) use ($globalList) {
                $query->where('email_lists.id', $globalList->id);
            })
            ->latest()
            ->paginate(20);

        return view('email.index', [
            'campaigns' => $campaigns,
            'globalList' => $globalList,
        ]);
    }

    public function create(Request $request, EmailListService $listService): View
    {
        $user = $request->user();
        $this->authorizeGlobalAccess($user);

        return view('email.create', [
            'globalList' => $listService->getGlobalList(),
            'defaults' => $this->campaignDefaults(),
        ]);
    }

    public function store(Request $request, EmailProviderInterface $provider, EmailListService $listService): RedirectResponse
    {
        $user = $request->user();
        $this->authorizeGlobalAccess($user);

        $validated = $request->validate([
            'subject' => ['required', 'string', 'max:255'],
            'from_name' => ['required', 'string', 'max:255'],
            'from_email' => ['required', 'string', 'email', 'max:255'],
            'reply_to' => ['nullable', 'string', 'email', 'max:255'],
            'email_type' => ['required', 'string', 'in:marketing,notification'],
            'content_markdown' => ['required', 'string', 'max:65000'],
            'scheduled_at' => ['nullable', 'date'],
            'action' => ['required', 'string', 'in:draft,send'],
        ]);

        if (! $provider->validateFromAddress($validated['from_email'])) {
            return redirect()->back()->withErrors(['from_email' => 'From address is not validated by the provider.'])->withInput();
        }

        $markdown = $validated['content_markdown'];
        $html = MarkdownUtils::convertToHtml($markdown);

        $campaign = EmailCampaign::query()->create([
            'created_by' => $user->getKey(),
            'email_type' => $validated['email_type'],
            'subject' => $validated['subject'],
            'from_name' => $validated['from_name'],
            'from_email' => $validated['from_email'],
            'reply_to' => $validated['reply_to'] ?? null,
            'content_markdown' => $markdown,
            'content_html' => $html,
            'content_text' => $markdown,
            'status' => EmailCampaign::STATUS_DRAFT,
        ]);

        $globalList = $listService->getGlobalList();
        $campaign->lists()->sync([$globalList->id]);

        if ($validated['action'] === 'send') {
            $campaign->scheduled_at = $validated['scheduled_at'] ?? null;
            $campaign->status = $campaign->scheduled_at ? EmailCampaign::STATUS_SCHEDULED : EmailCampaign::STATUS_SENDING;
            $campaign->save();

            $job = SendEmailCampaignJob::dispatch($campaign->id);
            if ($campaign->scheduled_at) {
                $job->delay($campaign->scheduled_at);
            }
        }

        Log::info('Global email campaign saved', [
            'campaign_id' => $campaign->id,
            'action' => $validated['action'],
        ]);

        return redirect()->route('email.campaigns.show', ['campaign' => $campaign->id]);
    }

    public function show(Request $request, EmailCampaign $campaign): View
    {
        $user = $request->user();
        $this->authorizeGlobalAccess($user);

        $campaign->load(['lists', 'stats']);

        $recipients = EmailCampaignRecipient::query()
            ->where('campaign_id', $campaign->id)
            ->latest('id')
            ->paginate(25);

        return view('email.show', [
            'campaign' => $campaign,
            'recipients' => $recipients,
        ]);
    }

    public function subscribers(Request $request): View
    {
        $user = $request->user();
        $this->authorizeGlobalAccess($user);

        $subscribers = EmailSubscriber::query()
            ->with(['subscriptions.list'])
            ->orderBy('created_at', 'desc')
            ->paginate(25);

        return view('email.subscribers', [
            'subscribers' => $subscribers,
        ]);
    }

    public function subscriberShow(Request $request, EmailSubscriber $subscriber): View
    {
        $user = $request->user();
        $this->authorizeGlobalAccess($user);

        $subscriber->load(['subscriptions.list']);

        $recipientStats = EmailCampaignRecipient::query()
            ->where('subscriber_id', $subscriber->id)
            ->with('campaign')
            ->latest('id')
            ->paginate(25);

        return view('email.subscriber-show', [
            'subscriber' => $subscriber,
            'recipientStats' => $recipientStats,
        ]);
    }

    protected function authorizeGlobalAccess($user): void
    {
        if (! $user || ! $user->isAdmin()) {
            abort(403);
        }
    }

    protected function campaignDefaults(): array
    {
        return [
            'from_name' => config('mass_email.default_from_name'),
            'from_email' => config('mass_email.default_from_email'),
            'reply_to' => config('mass_email.default_reply_to'),
        ];
    }
}
