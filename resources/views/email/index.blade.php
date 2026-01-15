<x-app-admin-layout>
    <div class="py-12">
        <div class="max-w-6xl mx-auto space-y-6">
            <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
                <div>
                    <h1 class="text-2xl font-semibold text-gray-900 dark:text-white">Email</h1>
                    <p class="text-sm text-gray-600 dark:text-gray-400">Create, send, and monitor global email campaigns.</p>
                </div>
                <div class="flex flex-wrap gap-2">
                    <a href="{{ route('email.subscribers.index') }}"
                        class="inline-flex items-center rounded-md border border-gray-300 px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 dark:border-gray-700 dark:text-gray-200 dark:hover:bg-gray-800">
                        Subscribers
                    </a>
                    <a href="{{ route('email.suppressions.index') }}"
                        class="inline-flex items-center rounded-md border border-gray-300 px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 dark:border-gray-700 dark:text-gray-200 dark:hover:bg-gray-800">
                        Suppressions
                    </a>
                    <a href="{{ route('email.templates.index') }}"
                        class="inline-flex items-center rounded-md border border-gray-300 px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 dark:border-gray-700 dark:text-gray-200 dark:hover:bg-gray-800">
                        Templates
                    </a>
                    <a href="{{ route('email.create') }}"
                        class="inline-flex items-center rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700">
                        New Campaign
                    </a>
                </div>
            </div>

            <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
                <div class="rounded-lg border border-gray-200 bg-white p-4 shadow-sm dark:border-gray-700 dark:bg-gray-800">
                    <p class="text-sm text-gray-500">Subscribers</p>
                    <p class="mt-2 text-2xl font-semibold text-gray-900 dark:text-white">{{ $summary['subscribers'] }}</p>
                    <p class="mt-1 text-xs text-gray-500">Marketing opt-outs: {{ $summary['marketing_opt_outs'] }}</p>
                </div>
                <div class="rounded-lg border border-gray-200 bg-white p-4 shadow-sm dark:border-gray-700 dark:bg-gray-800">
                    <p class="text-sm text-gray-500">Suppressions</p>
                    <p class="mt-2 text-2xl font-semibold text-gray-900 dark:text-white">{{ $summary['suppressions'] }}</p>
                    <p class="mt-1 text-xs text-gray-500">Bounces (30 days): {{ $summary['bounced_last_30_days'] }}</p>
                </div>
                <div class="rounded-lg border border-gray-200 bg-white p-4 shadow-sm dark:border-gray-700 dark:bg-gray-800">
                    <p class="text-sm text-gray-500">Delivery (30 days)</p>
                    <p class="mt-2 text-2xl font-semibold text-gray-900 dark:text-white">{{ $summary['sent_last_30_days'] }}</p>
                    <p class="mt-1 text-xs text-gray-500">Complaints (30 days): {{ $summary['complaints_last_30_days'] }}</p>
                </div>
            </div>

            <div class="bg-white dark:bg-gray-800 shadow-sm sm:rounded-lg">
                <div class="p-4 sm:p-6">
                    <h2 class="text-lg font-semibold text-gray-900 dark:text-white">Campaigns</h2>
                    <p class="mt-1 text-sm text-gray-600 dark:text-gray-400">Global list: {{ $globalList->name }}</p>

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
                                        <td class="px-4 py-3 text-sm text-gray-900 dark:text-gray-100">
                                            {{ $campaign->subject }}
                                        </td>
                                        <td class="px-4 py-3 text-sm text-gray-600 dark:text-gray-300 capitalize">
                                            {{ $campaign->email_type }}
                                        </td>
                                        <td class="px-4 py-3 text-sm text-gray-600 dark:text-gray-300 capitalize">
                                            {{ $campaign->status }}
                                        </td>
                                        <td class="px-4 py-3 text-sm text-gray-600 dark:text-gray-300">
                                            {{ $campaign->scheduled_at ? $campaign->scheduled_at->toDateTimeString() : '—' }}
                                        </td>
                                        <td class="px-4 py-3 text-sm text-gray-600 dark:text-gray-300">
                                            @php($stats = $campaign->stats)
                                            Targeted: {{ $stats->targeted_count ?? 0 }}
                                            · Suppressed: {{ $stats->suppressed_count ?? 0 }}
                                            · Accepted: {{ $stats->provider_accepted_count ?? 0 }}
                                        </td>
                                        <td class="px-4 py-3 text-right text-sm">
                                            <a href="{{ route('email.campaigns.show', ['campaign' => $campaign->id]) }}" class="text-indigo-600 hover:text-indigo-800">View</a>
                                        </td>
                                    </tr>
                                @empty
                                    <tr>
                                        <td colspan="6" class="px-4 py-6 text-center text-sm text-gray-500">
                                            No campaigns yet.
                                        </td>
                                    </tr>
                                @endforelse
                            </tbody>
                        </table>
                    </div>

                    <div class="mt-4">
                        {{ $campaigns->links() }}
                    </div>
                </div>
            </div>
        </div>
    </div>
</x-app-admin-layout>
