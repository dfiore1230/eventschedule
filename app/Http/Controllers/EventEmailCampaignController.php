<?php

namespace App\Http\Controllers;

use App\Jobs\SendEmailCampaignJob;
use App\Models\EmailCampaign;
use App\Models\EmailCampaignRecipient;
use App\Models\Event;
use App\Models\EmailSubscription;
use App\Models\Role;
use App\Services\Email\EmailListService;
use App\Services\Email\EmailProviderInterface;
use App\Utils\MarkdownUtils;
use App\Utils\UrlUtils;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\View\View;

class EventEmailCampaignController extends Controller
{
    public function index(Request $request, string $subdomain, string $hash, EmailListService $listService): View
    {
        [$event, $role] = $this->resolveEvent($request, $subdomain, $hash);
        $list = $listService->getEventList($event);
        $subscriptions = EmailSubscription::query()
            ->with('subscriber')
            ->where('list_id', $list->id)
            ->latest('id')
            ->take(15)
            ->get();

        $campaigns = EmailCampaign::query()
            ->with(['lists', 'stats'])
            ->whereHas('lists', function ($query) use ($list) {
                $query->where('email_lists.id', $list->id);
            })
            ->latest()
            ->paginate(20);

        return view('event.email', [
            'event' => $event,
            'role' => $role,
            'subdomain' => $subdomain,
            'list' => $list,
            'campaigns' => $campaigns,
            'subscriptions' => $subscriptions,
        ]);
    }

    public function create(Request $request, string $subdomain, string $hash, EmailListService $listService): View
    {
        [$event, $role] = $this->resolveEvent($request, $subdomain, $hash);

        return view('event.email-create', [
            'event' => $event,
            'role' => $role,
            'subdomain' => $subdomain,
            'list' => $listService->getEventList($event),
            'defaults' => $this->campaignDefaults(),
        ]);
    }

    public function store(Request $request, string $subdomain, string $hash, EmailProviderInterface $provider, EmailListService $listService): RedirectResponse
    {
        [$event, $role] = $this->resolveEvent($request, $subdomain, $hash);

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
            'created_by' => $request->user()->getKey(),
            'email_type' => $validated['email_type'],
            'subject' => $validated['subject'],
            'from_name' => $validated['from_name'],
            'from_email' => $validated['from_email'],
            'reply_to' => $validated['reply_to'] ?? null,
            'content_markdown' => $markdown,
            'content_html' => $html,
            'content_text' => $markdown,
            'status' => EmailCampaign::STATUS_DRAFT,
            'metadata' => ['event_id' => $event->id],
        ]);

        $list = $listService->getEventList($event);
        $campaign->lists()->sync([$list->id]);

        if ($validated['action'] === 'send') {
            $campaign->scheduled_at = $validated['scheduled_at'] ?? null;
            $campaign->status = $campaign->scheduled_at ? EmailCampaign::STATUS_SCHEDULED : EmailCampaign::STATUS_SENDING;
            $campaign->save();

            $job = SendEmailCampaignJob::dispatch($campaign->id);
            if ($campaign->scheduled_at) {
                $job->delay($campaign->scheduled_at);
            }
        }

        Log::info('Event email campaign saved', [
            'campaign_id' => $campaign->id,
            'event_id' => $event->id,
            'action' => $validated['action'],
        ]);

        return redirect()->route('event.email.show', [
            'subdomain' => $subdomain,
            'hash' => UrlUtils::encodeId($event->id),
            'campaign' => $campaign->id,
        ]);
    }

    public function show(Request $request, string $subdomain, string $hash, EmailCampaign $campaign, EmailListService $listService): View
    {
        [$event, $role] = $this->resolveEvent($request, $subdomain, $hash);

        $campaign->load(['lists', 'stats']);
        $list = $listService->getEventList($event);

        if (! $campaign->lists->contains('id', $list->id)) {
            abort(404);
        }

        $recipients = EmailCampaignRecipient::query()
            ->where('campaign_id', $campaign->id)
            ->latest('id')
            ->paginate(25);

        return view('event.email-show', [
            'event' => $event,
            'role' => $role,
            'subdomain' => $subdomain,
            'campaign' => $campaign,
            'recipients' => $recipients,
        ]);
    }

    protected function resolveEvent(Request $request, string $subdomain, string $hash): array
    {
        if (! is_hosted_or_admin()) {
            abort(403);
        }

        $eventId = UrlUtils::decodeId($hash);
        $event = Event::findOrFail($eventId);

        if (! $request->user()->canEditEvent($event)) {
            abort(403);
        }

        $role = Role::subdomain($subdomain)->firstOrFail();

        return [$event, $role];
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
