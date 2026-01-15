<?php

namespace App\Http\Controllers;

use App\Jobs\SendEmailCampaignJob;
use App\Mail\ConfirmSubscriptionMail;
use App\Models\EmailCampaign;
use App\Models\EmailCampaignRecipient;
use App\Models\EmailCampaignTemplate;
use App\Models\EmailList;
use App\Models\EmailSubscriber;
use App\Models\Event;
use App\Models\EmailSubscription;
use App\Models\Role;
use App\Services\Email\EmailListService;
use App\Services\Email\EmailProviderInterface;
use App\Services\Email\EmailSubscriptionService;
use App\Utils\MarkdownUtils;
use App\Utils\SimpleSpreadsheetExporter;
use App\Utils\UrlUtils;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\URL;
use Symfony\Component\HttpFoundation\BinaryFileResponse;
use Symfony\Component\HttpFoundation\StreamedResponse;
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

        $templates = EmailCampaignTemplate::query()
            ->where('scope', EmailCampaignTemplate::SCOPE_EVENT)
            ->where('event_id', $event->id)
            ->latest('id')
            ->get();

        return view('event.email', [
            'event' => $event,
            'role' => $role,
            'subdomain' => $subdomain,
            'list' => $list,
            'campaigns' => $campaigns,
            'subscriptions' => $subscriptions,
            'templates' => $templates,
        ]);
    }

    public function create(Request $request, string $subdomain, string $hash, EmailListService $listService): View
    {
        [$event, $role] = $this->resolveEvent($request, $subdomain, $hash);

        $templates = EmailCampaignTemplate::query()
            ->where('scope', EmailCampaignTemplate::SCOPE_EVENT)
            ->where('event_id', $event->id)
            ->latest('id')
            ->get();

        $selectedTemplate = null;
        if ($request->filled('template_id')) {
            $templateId = (int) $request->query('template_id');
            $selectedTemplate = $templates->firstWhere('id', $templateId)
                ?? EmailCampaignTemplate::query()
                    ->where('scope', EmailCampaignTemplate::SCOPE_EVENT)
                    ->where('event_id', $event->id)
                    ->find($templateId);
        }

        return view('event.email-create', [
            'event' => $event,
            'role' => $role,
            'subdomain' => $subdomain,
            'list' => $listService->getEventList($event),
            'defaults' => $this->campaignDefaults($selectedTemplate),
            'templates' => $templates,
            'selectedTemplate' => $selectedTemplate,
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
            'save_template' => ['nullable', 'boolean'],
            'template_name' => ['nullable', 'string', 'max:255', 'required_if:save_template,1'],
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

        if ($request->boolean('save_template') && ! empty($validated['template_name'])) {
            EmailCampaignTemplate::query()->create([
                'name' => $validated['template_name'],
                'scope' => EmailCampaignTemplate::SCOPE_EVENT,
                'event_id' => $event->id,
                'created_by' => $request->user()->getKey(),
                'subject' => $validated['subject'],
                'from_name' => $validated['from_name'],
                'from_email' => $validated['from_email'],
                'reply_to' => $validated['reply_to'] ?? null,
                'email_type' => $validated['email_type'],
                'content_markdown' => $markdown,
            ]);
        }

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

    public function updateSubscribers(
        Request $request,
        string $subdomain,
        string $hash,
        EmailListService $listService,
        EmailSubscriptionService $subscriptionService
    ): RedirectResponse {
        [$event, $role] = $this->resolveEvent($request, $subdomain, $hash);

        $validated = $request->validate([
            'action' => ['required', 'string', 'in:add,remove'],
            'email' => ['nullable', 'string', 'email', 'max:255'],
            'first_name' => ['nullable', 'string', 'max:255'],
            'last_name' => ['nullable', 'string', 'max:255'],
            'intent' => ['nullable', 'string', 'in:subscribe,invite'],
            'subscription_id' => ['nullable', 'integer'],
        ]);

        $list = $listService->getEventList($event);

        if ($validated['action'] === 'add') {
            $request->validate([
                'email' => ['required', 'string', 'email', 'max:255'],
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

            $subscription = $subscriptionService->upsertSubscription(
                $subscriber,
                $list,
                $status,
                'admin',
                'user:' . $request->user()->getKey(),
                ['marketing_opt_in' => $validated['intent'] === 'subscribe']
            );

            if ($status === EmailSubscription::STATUS_PENDING) {
                try {
                    $confirmUrl = $this->buildConfirmUrl($subscriber, $list);
                    Mail::to($subscriber->email)->send(new ConfirmSubscriptionMail($confirmUrl, $list->name));
                } catch (\Throwable $e) {
                    Log::warning('Event invite confirmation email skipped due to mail transport issue', [
                        'email' => $subscriber->email,
                        'list_id' => $list->id,
                        'event_id' => $event->id,
                        'error' => $e->getMessage(),
                    ]);

                    $subscriptionService->markSubscriptionStatus($subscription, EmailSubscription::STATUS_SUBSCRIBED, 'system');
                }
            }
        }

        if ($validated['action'] === 'remove') {
            $request->validate([
                'subscription_id' => ['required', 'integer'],
            ]);

            EmailSubscription::query()
                ->where('id', $validated['subscription_id'])
                ->where('list_id', $list->id)
                ->delete();
        }

        return redirect()->route('event.email.index', [
            'subdomain' => $subdomain,
            'hash' => UrlUtils::encodeId($event->id),
        ]);
    }

    public function exportSubscribers(
        Request $request,
        string $subdomain,
        string $hash,
        string $format,
        EmailListService $listService
    ): StreamedResponse|BinaryFileResponse {
        [$event] = $this->resolveEvent($request, $subdomain, $hash);

        if (! in_array($format, ['csv', 'xlsx'], true)) {
            abort(404);
        }

        $list = $listService->getEventList($event);

        $rows = [
            [
                'Email',
                'First Name',
                'Last Name',
                'Status',
                'Status Updated',
                'Source',
                'Marketing Opt-Out',
                'Subscriber Created',
            ],
        ];

        $subscriptions = EmailSubscription::query()
            ->with('subscriber')
            ->where('list_id', $list->id)
            ->orderBy('id')
            ->get();

        foreach ($subscriptions as $subscription) {
            $subscriber = $subscription->subscriber;
            $rows[] = [
                $subscriber?->email ?? '',
                $subscriber?->first_name ?? '',
                $subscriber?->last_name ?? '',
                $subscription->status,
                $subscription->status_updated_at?->toDateTimeString(),
                $subscription->source ?? '',
                $subscriber?->marketing_unsubscribed_at?->toDateTimeString(),
                $subscriber?->created_at?->toDateTimeString(),
            ];
        }

        $filename = 'event-' . $event->id . '-subscribers-' . now()->format('Ymd-His') . '.' . $format;

        if ($format === 'csv') {
            return SimpleSpreadsheetExporter::downloadCsv($rows, $filename);
        }

        return SimpleSpreadsheetExporter::downloadXlsx($rows, $filename, 'Event Subscribers');
    }

    public function templateDestroy(Request $request, string $subdomain, string $hash, EmailCampaignTemplate $template): RedirectResponse
    {
        [$event] = $this->resolveEvent($request, $subdomain, $hash);

        if ($template->scope !== EmailCampaignTemplate::SCOPE_EVENT || $template->event_id !== $event->id) {
            abort(404);
        }

        $template->delete();

        return redirect()->route('event.email.index', [
            'subdomain' => $subdomain,
            'hash' => UrlUtils::encodeId($event->id),
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

    protected function campaignDefaults(?EmailCampaignTemplate $template = null): array
    {
        return [
            'from_name' => $template?->from_name ?? config('mass_email.default_from_name'),
            'from_email' => $template?->from_email ?? config('mass_email.default_from_email'),
            'reply_to' => $template?->reply_to ?? config('mass_email.default_reply_to'),
            'subject' => $template?->subject,
            'content_markdown' => $template?->content_markdown,
            'email_type' => $template?->email_type ?? 'marketing',
        ];
    }

    protected function buildConfirmUrl(EmailSubscriber $subscriber, EmailList $list): string
    {
        $ttlMinutes = (int) config('mass_email.confirmation_token_ttl_minutes', 10080);

        return URL::temporarySignedRoute('public.confirm', now()->addMinutes($ttlMinutes), [
            'subscriber' => $subscriber->getKey(),
            'list' => $list->getKey(),
        ]);
    }
}
