<x-app-admin-layout>
    <div class="py-12">
        <div class="max-w-6xl mx-auto space-y-6">
            <div class="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
                <div>
                    <h1 class="text-2xl font-semibold text-gray-900 dark:text-white">Event Campaign</h1>
                    <p class="text-sm text-gray-600 dark:text-gray-400">{{ $campaign->subject }} · {{ $event->name }}</p>
                </div>
                <a href="{{ route('event.email.index', ['subdomain' => $subdomain, 'hash' => \App\Utils\UrlUtils::encodeId($event->id)]) }}" class="text-sm text-gray-600 hover:text-gray-900">Back to Event Email</a>
            </div>

            <div class="grid gap-6 lg:grid-cols-3">
                <div class="lg:col-span-2 space-y-6">
                    <div class="bg-white dark:bg-gray-800 shadow-sm sm:rounded-lg">
                        <div class="p-4 sm:p-6">
                            <h2 class="text-lg font-semibold text-gray-900 dark:text-white">Content</h2>
                            <div class="mt-4 prose max-w-none dark:prose-invert">
                                {!! $campaign->content_html ?? '' !!}
                            </div>
                        </div>
                    </div>

                    <div class="bg-white dark:bg-gray-800 shadow-sm sm:rounded-lg">
                        <div class="p-4 sm:p-6">
                            <h2 class="text-lg font-semibold text-gray-900 dark:text-white">Recipients</h2>
                            <div class="mt-4 overflow-x-auto">
                                <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
                                    <thead class="bg-gray-50 dark:bg-gray-900">
                                        <tr>
                                            <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Email</th>
                                            <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Status</th>
                                            <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Reason</th>
                                            <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Provider ID</th>
                                            <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Sent</th>
                                        </tr>
                                    </thead>
                                    <tbody class="divide-y divide-gray-100 dark:divide-gray-700">
                                        @forelse ($recipients as $recipient)
                                            <tr>
                                                <td class="px-4 py-3 text-sm text-gray-900 dark:text-gray-100">{{ $recipient->email }}</td>
                                                <td class="px-4 py-3 text-sm text-gray-600 dark:text-gray-300 capitalize">{{ $recipient->status }}</td>
                                                <td class="px-4 py-3 text-sm text-gray-600 dark:text-gray-300">{{ $recipient->suppression_reason ?? '—' }}</td>
                                                <td class="px-4 py-3 text-sm text-gray-600 dark:text-gray-300">{{ $recipient->provider_message_id ?? '—' }}</td>
                                                <td class="px-4 py-3 text-sm text-gray-600 dark:text-gray-300">{{ $recipient->sent_at ? $recipient->sent_at->toDateTimeString() : '—' }}</td>
                                            </tr>
                                        @empty
                                            <tr>
                                                <td colspan="5" class="px-4 py-6 text-center text-sm text-gray-500">No recipients yet.</td>
                                            </tr>
                                        @endforelse
                                    </tbody>
                                </table>
                            </div>
                            <div class="mt-4">{{ $recipients->links() }}</div>
                        </div>
                    </div>
                </div>

                <div class="space-y-6">
                    <div class="bg-white dark:bg-gray-800 shadow-sm sm:rounded-lg">
                        <div class="p-4 sm:p-6 space-y-4">
                            <h2 class="text-lg font-semibold text-gray-900 dark:text-white">Details</h2>
                            <div class="text-sm text-gray-600 dark:text-gray-300 space-y-1">
                                <p><span class="font-medium">Type:</span> {{ ucfirst($campaign->email_type) }}</p>
                                <p><span class="font-medium">Status:</span> {{ ucfirst($campaign->status) }}</p>
                                <p><span class="font-medium">From:</span> {{ $campaign->from_name }} &lt;{{ $campaign->from_email }}&gt;</p>
                                <p><span class="font-medium">Reply-to:</span> {{ $campaign->reply_to ?? '—' }}</p>
                                <p><span class="font-medium">Scheduled:</span> {{ $campaign->scheduled_at ? $campaign->scheduled_at->toDateTimeString() : '—' }}</p>
                            </div>
                        </div>
                    </div>

                    <div class="bg-white dark:bg-gray-800 shadow-sm sm:rounded-lg">
                        <div class="p-4 sm:p-6">
                            <h2 class="text-lg font-semibold text-gray-900 dark:text-white">Stats</h2>
                            @php($stats = $campaign->stats)
                            <div class="mt-3 text-sm text-gray-600 dark:text-gray-300 space-y-1">
                                <p>Targeted: {{ $stats->targeted_count ?? 0 }}</p>
                                <p>Suppressed: {{ $stats->suppressed_count ?? 0 }}</p>
                                <p>Accepted: {{ $stats->provider_accepted_count ?? 0 }}</p>
                                <p>Bounced: {{ $stats->bounced_count ?? 0 }}</p>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
</x-app-admin-layout>
