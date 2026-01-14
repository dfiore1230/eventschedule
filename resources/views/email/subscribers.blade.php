<x-app-admin-layout>
    <div class="py-12">
        <div class="max-w-6xl mx-auto space-y-6">
            <div class="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
                <div>
                    <h1 class="text-2xl font-semibold text-gray-900 dark:text-white">Subscribers</h1>
                    <p class="text-sm text-gray-600 dark:text-gray-400">View subscription status and opt-out history.</p>
                </div>
                <a href="{{ route('email.index') }}" class="text-sm text-gray-600 hover:text-gray-900">Back to Email</a>
            </div>

            <div class="bg-white dark:bg-gray-800 shadow-sm sm:rounded-lg">
                <div class="p-4 sm:p-6">
                    <div class="overflow-x-auto">
                        <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
                            <thead class="bg-gray-50 dark:bg-gray-900">
                                <tr>
                                    <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Email</th>
                                    <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Name</th>
                                    <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Subscribed</th>
                                    <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Source</th>
                                    <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Marketing Opt-out</th>
                                    <th class="px-4 py-3"></th>
                                </tr>
                            </thead>
                            <tbody class="divide-y divide-gray-100 dark:divide-gray-700">
                                @forelse ($subscribers as $subscriber)
                                    @php($lastSubscription = $subscriber->subscriptions->sortByDesc('status_updated_at')->first())
                                    <tr>
                                        <td class="px-4 py-3 text-sm text-gray-900 dark:text-gray-100">{{ $subscriber->email }}</td>
                                        <td class="px-4 py-3 text-sm text-gray-600 dark:text-gray-300">{{ trim($subscriber->first_name . ' ' . $subscriber->last_name) ?: '—' }}</td>
                                        <td class="px-4 py-3 text-sm text-gray-600 dark:text-gray-300">{{ $lastSubscription?->status_updated_at?->toDateTimeString() ?? '—' }}</td>
                                        <td class="px-4 py-3 text-sm text-gray-600 dark:text-gray-300">{{ $subscriber->source ?? '—' }}</td>
                                        <td class="px-4 py-3 text-sm text-gray-600 dark:text-gray-300">{{ $subscriber->marketing_unsubscribed_at ? $subscriber->marketing_unsubscribed_at->toDateTimeString() : '—' }}</td>
                                        <td class="px-4 py-3 text-right text-sm">
                                            <a href="{{ route('email.subscribers.show', ['subscriber' => $subscriber->id]) }}" class="text-indigo-600 hover:text-indigo-800">View</a>
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
                    <div class="mt-4">{{ $subscribers->links() }}</div>
                </div>
            </div>
        </div>
    </div>
</x-app-admin-layout>
