<x-app-admin-layout>
    <div class="py-12">
        <div class="max-w-6xl mx-auto space-y-6">
            <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
                <div>
                    <h1 class="text-2xl font-semibold text-gray-900 dark:text-white">Event Email</h1>
                    <p class="text-sm text-gray-600 dark:text-gray-400">{{ $event->name }}</p>
                </div>
                <div class="flex flex-wrap gap-2">
                    <a href="{{ route('event.email.create', ['subdomain' => $subdomain, 'hash' => \App\Utils\UrlUtils::encodeId($event->id)]) }}"
                        class="inline-flex items-center rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700">
                        New Event Campaign
                    </a>
                </div>
            </div>

            <div class="bg-white dark:bg-gray-800 shadow-sm sm:rounded-lg">
                <div class="p-4 sm:p-6">
                    <h2 class="text-lg font-semibold text-gray-900 dark:text-white">Campaigns</h2>
                    <p class="mt-1 text-sm text-gray-600 dark:text-gray-400">List: {{ $list->name }}</p>

                    <div class="mt-6 overflow-x-auto">
                        <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
                            <thead class="bg-gray-50 dark:bg-gray-900">
                                <tr>
                                    <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Subject</th>
                                    <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Type</th>
                                    <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Status</th>
                                    <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Scheduled</th>
                                    <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Stats</th>
                                    <th class="px-4 py-3"></th>
                                </tr>
                            </thead>
                            <tbody class="divide-y divide-gray-100 dark:divide-gray-700">
                                @forelse ($campaigns as $campaign)
                                    <tr>
                                        <td class="px-4 py-3 text-sm text-gray-900 dark:text-gray-100">{{ $campaign->subject }}</td>
                                        <td class="px-4 py-3 text-sm text-gray-600 dark:text-gray-300 capitalize">{{ $campaign->email_type }}</td>
                                        <td class="px-4 py-3 text-sm text-gray-600 dark:text-gray-300 capitalize">{{ $campaign->status }}</td>
                                        <td class="px-4 py-3 text-sm text-gray-600 dark:text-gray-300">{{ $campaign->scheduled_at ? $campaign->scheduled_at->toDateTimeString() : '—' }}</td>
                                        <td class="px-4 py-3 text-sm text-gray-600 dark:text-gray-300">
                                            @php($stats = $campaign->stats)
                                            Targeted: {{ $stats->targeted_count ?? 0 }}
                                            · Suppressed: {{ $stats->suppressed_count ?? 0 }}
                                            · Accepted: {{ $stats->provider_accepted_count ?? 0 }}
                                        </td>
                                        <td class="px-4 py-3 text-right text-sm">
                                            <a href="{{ route('event.email.show', ['subdomain' => $subdomain, 'hash' => \App\Utils\UrlUtils::encodeId($event->id), 'campaign' => $campaign->id]) }}" class="text-indigo-600 hover:text-indigo-800">View</a>
                                        </td>
                                    </tr>
                                @empty
                                    <tr>
                                        <td colspan="6" class="px-4 py-6 text-center text-sm text-gray-500">No campaigns yet.</td>
                                    </tr>
                                @endforelse
                            </tbody>
                        </table>
                    </div>

                    <div class="mt-4">{{ $campaigns->links() }}</div>
                </div>
            </div>

            <div class="bg-white dark:bg-gray-800 shadow-sm sm:rounded-lg">
                <div class="p-4 sm:p-6">
                    <div class="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
                        <div>
                            <h2 class="text-lg font-semibold text-gray-900 dark:text-white">Templates</h2>
                            <p class="mt-1 text-sm text-gray-600 dark:text-gray-400">Saved templates for this event.</p>
                        </div>
                        <a href="{{ route('event.email.create', ['subdomain' => $subdomain, 'hash' => \App\Utils\UrlUtils::encodeId($event->id)]) }}"
                            class="text-sm text-indigo-600 hover:text-indigo-800">New Campaign</a>
                    </div>

                    <div class="mt-6 overflow-x-auto">
                        <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
                            <thead class="bg-gray-50 dark:bg-gray-900">
                                <tr>
                                    <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Name</th>
                                    <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Type</th>
                                    <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Updated</th>
                                    <th class="px-4 py-3"></th>
                                </tr>
                            </thead>
                            <tbody class="divide-y divide-gray-100 dark:divide-gray-700">
                                @forelse ($templates as $template)
                                    <tr>
                                        <td class="px-4 py-3 text-sm text-gray-900 dark:text-gray-100">{{ $template->name }}</td>
                                        <td class="px-4 py-3 text-sm text-gray-600 dark:text-gray-300 capitalize">{{ $template->email_type }}</td>
                                        <td class="px-4 py-3 text-sm text-gray-600 dark:text-gray-300">{{ $template->updated_at?->toDateTimeString() ?? '—' }}</td>
                                        <td class="px-4 py-3 text-right text-sm">
                                            <a href="{{ route('event.email.create', ['subdomain' => $subdomain, 'hash' => \App\Utils\UrlUtils::encodeId($event->id), 'template_id' => $template->id]) }}"
                                                class="text-indigo-600 hover:text-indigo-800">Use</a>
                                            <form method="POST" action="{{ route('event.email.templates.destroy', ['subdomain' => $subdomain, 'hash' => \App\Utils\UrlUtils::encodeId($event->id), 'template' => $template->id]) }}" class="inline">
                                                @csrf
                                                @method('DELETE')
                                                <button type="submit" class="ml-3 text-xs text-red-600 hover:text-red-800">Delete</button>
                                            </form>
                                        </td>
                                    </tr>
                                @empty
                                    <tr>
                                        <td colspan="4" class="px-4 py-6 text-center text-sm text-gray-500">No templates yet.</td>
                                    </tr>
                                @endforelse
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>

            <div class="bg-white dark:bg-gray-800 shadow-sm sm:rounded-lg">
                <div class="p-4 sm:p-6">
                    <h2 class="text-lg font-semibold text-gray-900 dark:text-white">Manage Event List</h2>
                    <p class="mt-1 text-sm text-gray-600 dark:text-gray-400">Add a contact or remove them from the event mailing list.</p>

                    <form method="POST" action="{{ route('event.email.subscribers.update', ['subdomain' => $subdomain, 'hash' => \App\Utils\UrlUtils::encodeId($event->id)]) }}" class="mt-4 grid gap-4 lg:grid-cols-6">
                        @csrf
                        <input type="hidden" name="action" value="add">
                        <div class="lg:col-span-2">
                            <label class="block text-sm font-medium text-gray-700 dark:text-gray-200" for="event_add_email">Email</label>
                            <input id="event_add_email" name="email" type="email" required
                                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 dark:bg-gray-900 dark:border-gray-700 dark:text-gray-100">
                        </div>
                        <div>
                            <label class="block text-sm font-medium text-gray-700 dark:text-gray-200" for="event_add_first_name">First name</label>
                            <input id="event_add_first_name" name="first_name" type="text"
                                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 dark:bg-gray-900 dark:border-gray-700 dark:text-gray-100">
                        </div>
                        <div>
                            <label class="block text-sm font-medium text-gray-700 dark:text-gray-200" for="event_add_last_name">Last name</label>
                            <input id="event_add_last_name" name="last_name" type="text"
                                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 dark:bg-gray-900 dark:border-gray-700 dark:text-gray-100">
                        </div>
                        <div>
                            <label class="block text-sm font-medium text-gray-700 dark:text-gray-200" for="event_add_intent">Intent</label>
                            <select id="event_add_intent" name="intent"
                                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 dark:bg-gray-900 dark:border-gray-700 dark:text-gray-100">
                                <option value="invite">Invite to subscribe</option>
                                <option value="subscribe">Add as subscribed</option>
                            </select>
                        </div>
                        <div class="lg:col-span-1 flex items-end">
                            <button type="submit" class="inline-flex items-center rounded-md bg-indigo-600 px-4 py-2 text-sm font-semibold text-white hover:bg-indigo-700">Add</button>
                        </div>
                    </form>
                </div>
            </div>

            <div class="bg-white dark:bg-gray-800 shadow-sm sm:rounded-lg">
                <div class="p-4 sm:p-6">
                    <div class="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
                        <div>
                            <h2 class="text-lg font-semibold text-gray-900 dark:text-white">Recent Subscribers</h2>
                            <p class="mt-1 text-sm text-gray-600 dark:text-gray-400">Latest 15 contacts in this event list.</p>
                        </div>
                        <div class="flex items-center gap-2 text-sm">
                            <span class="text-gray-500">Export:</span>
                            <a href="{{ route('event.email.export', ['subdomain' => $subdomain, 'hash' => \App\Utils\UrlUtils::encodeId($event->id), 'format' => 'csv']) }}"
                                class="text-indigo-600 hover:text-indigo-800">CSV</a>
                            <a href="{{ route('event.email.export', ['subdomain' => $subdomain, 'hash' => \App\Utils\UrlUtils::encodeId($event->id), 'format' => 'xlsx']) }}"
                                class="text-indigo-600 hover:text-indigo-800">Excel</a>
                        </div>
                    </div>

                    <div class="mt-6 overflow-x-auto">
                        <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
                            <thead class="bg-gray-50 dark:bg-gray-900">
                                <tr>
                                    <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Email</th>
                                    <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Status</th>
                                    <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Source</th>
                                    <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Updated</th>
                                    <th class="px-4 py-3"></th>
                                </tr>
                            </thead>
                            <tbody class="divide-y divide-gray-100 dark:divide-gray-700">
                                @forelse ($subscriptions as $subscription)
                                    <tr>
                                        <td class="px-4 py-3 text-sm text-gray-900 dark:text-gray-100">{{ $subscription->subscriber?->email ?? '—' }}</td>
                                        <td class="px-4 py-3 text-sm text-gray-600 dark:text-gray-300 capitalize">{{ $subscription->status }}</td>
                                        <td class="px-4 py-3 text-sm text-gray-600 dark:text-gray-300">{{ $subscription->source ?? '—' }}</td>
                                        <td class="px-4 py-3 text-sm text-gray-600 dark:text-gray-300">{{ $subscription->status_updated_at ? $subscription->status_updated_at->toDateTimeString() : '—' }}</td>
                                        <td class="px-4 py-3 text-right text-sm">
                                            <form method="POST" action="{{ route('event.email.subscribers.update', ['subdomain' => $subdomain, 'hash' => \App\Utils\UrlUtils::encodeId($event->id)]) }}">
                                                @csrf
                                                <input type="hidden" name="action" value="remove">
                                                <input type="hidden" name="subscription_id" value="{{ $subscription->id }}">
                                                <button type="submit" class="text-xs text-red-600 hover:text-red-800">Remove</button>
                                            </form>
                                        </td>
                                    </tr>
                                @empty
                                    <tr>
                                        <td colspan="5" class="px-4 py-6 text-center text-sm text-gray-500">No subscribers yet.</td>
                                    </tr>
                                @endforelse
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
        </div>
    </div>
</x-app-admin-layout>
