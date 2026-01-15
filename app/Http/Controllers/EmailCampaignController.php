<?php

namespace App\Http\Controllers;

use App\Jobs\SendEmailCampaignJob;
use App\Models\EmailCampaign;
use App\Models\EmailCampaignRecipient;
use App\Models\EmailCampaignTemplate;
use App\Models\EmailList;
use App\Models\EmailSubscriber;
use App\Models\EmailSubscription;
use App\Models\EmailSuppression;
use App\Mail\ConfirmSubscriptionMail;
use App\Services\Email\EmailListService;
use App\Services\Email\EmailProviderInterface;
use App\Services\Email\EmailSubscriptionService;
use App\Utils\MarkdownUtils;
use App\Utils\SimpleSpreadsheetExporter;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\URL;
use Illuminate\Http\RedirectResponse;
use Symfony\Component\HttpFoundation\BinaryFileResponse;
use Symfony\Component\HttpFoundation\StreamedResponse;
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
            'summary' => $this->buildSummaryMetrics(),
        ]);
    }

    public function create(Request $request, EmailListService $listService): View
    {
        $user = $request->user();
        $this->authorizeGlobalAccess($user);

        $templates = EmailCampaignTemplate::query()
            ->where('scope', EmailCampaignTemplate::SCOPE_GLOBAL)
            ->latest('id')
            ->get();

        $selectedTemplate = null;
        if ($request->filled('template_id')) {
            $templateId = (int) $request->query('template_id');
            $selectedTemplate = $templates->firstWhere('id', $templateId)
                ?? EmailCampaignTemplate::query()
                    ->where('scope', EmailCampaignTemplate::SCOPE_GLOBAL)
                    ->find($templateId);
        }

        return view('email.create', [
            'globalList' => $listService->getGlobalList(),
            'defaults' => $this->campaignDefaults($selectedTemplate),
            'templates' => $templates,
            'selectedTemplate' => $selectedTemplate,
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
            'save_template' => ['nullable', 'boolean'],
            'template_name' => ['nullable', 'string', 'max:255', 'required_if:save_template,1'],
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

        if ($request->boolean('save_template') && ! empty($validated['template_name'])) {
            EmailCampaignTemplate::query()->create([
                'name' => $validated['template_name'],
                'scope' => EmailCampaignTemplate::SCOPE_GLOBAL,
                'created_by' => $user->getKey(),
                'subject' => $validated['subject'],
                'from_name' => $validated['from_name'],
                'from_email' => $validated['from_email'],
                'reply_to' => $validated['reply_to'] ?? null,
                'email_type' => $validated['email_type'],
                'content_markdown' => $markdown,
            ]);
        }

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
            'lists' => EmailList::query()->with('event')->orderBy('type')->orderBy('name')->get(),
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

    public function subscriberUpdate(Request $request, EmailSubscriber $subscriber): RedirectResponse
    {
        $user = $request->user();
        $this->authorizeGlobalAccess($user);

        $validated = $request->validate([
            'marketing_status' => ['required', 'string', 'in:opt_in,opt_out,unchanged'],
            'list_id' => ['nullable', 'integer'],
            'list_status' => ['nullable', 'string', 'in:subscribed,unsubscribed,pending'],
        ]);

        if ($validated['marketing_status'] === 'opt_out') {
            $subscriber->marketing_unsubscribed_at = now();
        } elseif ($validated['marketing_status'] === 'opt_in') {
            $subscriber->marketing_unsubscribed_at = null;
        }

        $subscriber->save();

        if (! empty($validated['list_id']) && ! empty($validated['list_status'])) {
            EmailSubscription::query()
                ->where('subscriber_id', $subscriber->id)
                ->where('list_id', $validated['list_id'])
                ->update([
                    'status' => $validated['list_status'],
                    'status_updated_at' => now(),
                    'status_updated_by' => 'admin:' . $user->getKey(),
                ]);
        }

        return redirect()->route('email.subscribers.show', ['subscriber' => $subscriber->id]);
    }

    public function subscriberBulkUpdate(Request $request): RedirectResponse
    {
        $user = $request->user();
        $this->authorizeGlobalAccess($user);

        $validated = $request->validate([
            'subscriber_ids' => ['required', 'array', 'min:1'],
            'subscriber_ids.*' => ['integer'],
            'action' => ['required', 'string', 'in:marketing,list'],
            'marketing_status' => ['nullable', 'string', 'in:opt_in,opt_out'],
            'list_id' => ['nullable', 'integer'],
            'list_status' => ['nullable', 'string', 'in:subscribed,unsubscribed,pending'],
        ]);

        if ($validated['action'] === 'marketing' && empty($validated['marketing_status'])) {
            return redirect()->route('email.subscribers.index')->withErrors([
                'marketing_status' => 'Select a marketing status for bulk update.',
            ]);
        }

        if ($validated['action'] === 'list' && (empty($validated['list_id']) || empty($validated['list_status']))) {
            return redirect()->route('email.subscribers.index')->withErrors([
                'list_status' => 'Select a list and status for bulk update.',
            ]);
        }

        if ($validated['action'] === 'marketing') {
            $query = EmailSubscriber::query()->whereIn('id', $validated['subscriber_ids']);

            if ($validated['marketing_status'] === 'opt_out') {
                $query->update(['marketing_unsubscribed_at' => now()]);
            } else {
                $query->update(['marketing_unsubscribed_at' => null]);
            }
        }

        if ($validated['action'] === 'list') {
            EmailSubscription::query()
                ->whereIn('subscriber_id', $validated['subscriber_ids'])
                ->where('list_id', $validated['list_id'])
                ->update([
                    'status' => $validated['list_status'],
                    'status_updated_at' => now(),
                    'status_updated_by' => 'admin:' . $user->getKey(),
                ]);
        }

        return redirect()->route('email.subscribers.index');
    }

    public function subscriberAdd(Request $request, EmailSubscriptionService $subscriptionService): RedirectResponse
    {
        $user = $request->user();
        $this->authorizeGlobalAccess($user);

        $validated = $request->validate([
            'email' => ['required', 'string', 'email', 'max:255'],
            'first_name' => ['nullable', 'string', 'max:255'],
            'last_name' => ['nullable', 'string', 'max:255'],
            'list_id' => ['required', 'integer', 'exists:email_lists,id'],
            'intent' => ['required', 'string', 'in:subscribe,invite'],
        ]);

        $list = EmailList::query()->findOrFail($validated['list_id']);

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
            'user:' . $user->getKey(),
            ['marketing_opt_in' => $validated['intent'] === 'subscribe']
        );

        if ($status === EmailSubscription::STATUS_PENDING) {
            try {
                $confirmUrl = $this->buildConfirmUrl($subscriber, $list);
                Mail::to($subscriber->email)->send(new ConfirmSubscriptionMail($confirmUrl, $list->name));
            } catch (\Throwable $e) {
                Log::warning('Admin invite confirmation email skipped due to mail transport issue', [
                    'email' => $subscriber->email,
                    'list_id' => $list->id,
                    'error' => $e->getMessage(),
                ]);

                $subscriptionService->markSubscriptionStatus($subscription, EmailSubscription::STATUS_SUBSCRIBED, 'system');
            }
        }

        return redirect()->route('email.subscribers.index');
    }

    public function subscriberRemoveList(Request $request, EmailSubscriber $subscriber, EmailList $list): RedirectResponse
    {
        $user = $request->user();
        $this->authorizeGlobalAccess($user);

        EmailSubscription::query()
            ->where('subscriber_id', $subscriber->id)
            ->where('list_id', $list->id)
            ->delete();

        return redirect()->route('email.subscribers.show', ['subscriber' => $subscriber->id]);
    }

    public function templates(Request $request): View
    {
        $user = $request->user();
        $this->authorizeGlobalAccess($user);

        $templates = EmailCampaignTemplate::query()
            ->where('scope', EmailCampaignTemplate::SCOPE_GLOBAL)
            ->latest('id')
            ->paginate(20);

        return view('email.templates', [
            'templates' => $templates,
        ]);
    }

    public function templateDestroy(Request $request, EmailCampaignTemplate $template): RedirectResponse
    {
        $user = $request->user();
        $this->authorizeGlobalAccess($user);

        if ($template->scope !== EmailCampaignTemplate::SCOPE_GLOBAL) {
            abort(404);
        }

        $template->delete();

        return redirect()->route('email.templates.index');
    }

    public function suppressions(Request $request): View
    {
        $user = $request->user();
        $this->authorizeGlobalAccess($user);

        $query = EmailSuppression::query()->orderBy('created_at', 'desc');
        $search = trim((string) $request->query('email'));

        if ($search !== '') {
            $query->where('email', 'like', '%' . EmailSubscriber::normalizeEmail($search) . '%');
        }

        $suppressions = $query->paginate(25)->withQueryString();

        return view('email.suppressions', [
            'suppressions' => $suppressions,
            'search' => $search,
        ]);
    }

    public function suppressionStore(Request $request): RedirectResponse
    {
        $user = $request->user();
        $this->authorizeGlobalAccess($user);

        $validated = $request->validate([
            'email' => ['required', 'string', 'email', 'max:255'],
            'reason' => ['required', 'string', 'in:bounce,complaint,manual'],
        ]);

        EmailSuppression::query()->updateOrCreate(
            ['email' => $validated['email']],
            ['reason' => $validated['reason']]
        );

        return redirect()->route('email.suppressions.index');
    }

    public function suppressionDestroy(Request $request, EmailSuppression $suppression): RedirectResponse
    {
        $user = $request->user();
        $this->authorizeGlobalAccess($user);

        $suppression->delete();

        return redirect()->route('email.suppressions.index');
    }

    public function exportSubscribers(Request $request, string $format): StreamedResponse|BinaryFileResponse
    {
        $user = $request->user();
        $this->authorizeGlobalAccess($user);

        if (! in_array($format, ['csv', 'xlsx'], true)) {
            abort(404);
        }

        $validated = $request->validate([
            'list_id' => ['nullable', 'integer', 'exists:email_lists,id'],
        ]);

        $query = EmailSubscription::query()
            ->with(['subscriber', 'list.event'])
            ->orderBy('id');

        if (! empty($validated['list_id'])) {
            $query->where('list_id', $validated['list_id']);
        }

        $rows = [
            [
                'Email',
                'First Name',
                'Last Name',
                'List Type',
                'List Name',
                'Event Name',
                'Status',
                'Status Updated',
                'Source',
                'Marketing Opt-Out',
                'Subscriber Created',
            ],
        ];

        foreach ($query->get() as $subscription) {
            $subscriber = $subscription->subscriber;
            $list = $subscription->list;
            $eventName = $list && $list->event ? ($list->event->translatedName() ?? $list->event->name) : '';
            $rows[] = [
                $subscriber?->email ?? '',
                $subscriber?->first_name ?? '',
                $subscriber?->last_name ?? '',
                $list?->type ?? '',
                $list?->name ?? '',
                $eventName,
                $subscription->status,
                $subscription->status_updated_at?->toDateTimeString(),
                $subscription->source ?? '',
                $subscriber?->marketing_unsubscribed_at?->toDateTimeString(),
                $subscriber?->created_at?->toDateTimeString(),
            ];
        }

        $filename = 'subscribers-' . now()->format('Ymd-His') . '.' . $format;

        if ($format === 'csv') {
            return SimpleSpreadsheetExporter::downloadCsv($rows, $filename);
        }

        return SimpleSpreadsheetExporter::downloadXlsx($rows, $filename, 'Subscribers');
    }

    protected function authorizeGlobalAccess($user): void
    {
        if (! $user) {
            abort(403);
        }

        if ($user->isAdmin()) {
            return;
        }

        if ($user->hasPermission('email.manage') || $user->hasPermission('email.send') || $user->hasPermission('email.view')) {
            return;
        }

        abort(403);
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

    protected function buildSummaryMetrics(): array
    {
        $thirtyDaysAgo = now()->subDays(30);

        return [
            'subscribers' => EmailSubscriber::query()->count(),
            'marketing_opt_outs' => EmailSubscriber::query()->whereNotNull('marketing_unsubscribed_at')->count(),
            'suppressions' => EmailSuppression::query()->count(),
            'sent_last_30_days' => EmailCampaignRecipient::query()->whereNotNull('sent_at')->where('sent_at', '>=', $thirtyDaysAgo)->count(),
            'bounced_last_30_days' => EmailCampaignRecipient::query()->whereNotNull('bounced_at')->where('bounced_at', '>=', $thirtyDaysAgo)->count(),
            'complaints_last_30_days' => EmailCampaignRecipient::query()->whereNotNull('complained_at')->where('complained_at', '>=', $thirtyDaysAgo)->count(),
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
