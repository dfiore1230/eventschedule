<x-app-admin-layout>
    <div class="py-12">
        <div class="max-w-6xl mx-auto space-y-6">
            <div class="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
                <div>
                    <h1 class="text-2xl font-semibold text-gray-900 dark:text-white">Subscriber</h1>
                    <p class="text-sm text-gray-600 dark:text-gray-400">{{ $subscriber->email }}</p>
                </div>
                <a href="{{ route('email.subscribers.index') }}" class="text-sm text-gray-600 hover:text-gray-900">Back to Subscribers</a>
            </div>

            <div class="grid gap-6 lg:grid-cols-3">
                <div class="lg:col-span-1 space-y-6">
                    <div class="bg-white dark:bg-gray-800 shadow-sm sm:rounded-lg">
                        <div class="p-4 sm:p-6">
                            <h2 class="text-lg font-semibold text-gray-900 dark:text-white">Profile</h2>
                            <div class="mt-3 text-sm text-gray-600 dark:text-gray-300 space-y-1">
                                <p><span class="font-medium">Name:</span> {{ trim($subscriber->first_name . ' ' . $subscriber->last_name) ?: '—' }}</p>
                                <p><span class="font-medium">Source:</span> {{ $subscriber->source ?? '—' }}</p>
                                <p><span class="font-medium">Subscribed:</span> {{ $subscriber->created_at ? $subscriber->created_at->toDateTimeString() : '—' }}</p>
                                <p><span class="font-medium">Marketing opt-out:</span> {{ $subscriber->marketing_unsubscribed_at ? $subscriber->marketing_unsubscribed_at->toDateTimeString() : '—' }}</p>
                            </div>
                        </div>
                    </div>

                    <div class="bg-white dark:bg-gray-800 shadow-sm sm:rounded-lg">
                        <div class="p-4 sm:p-6">
                            <h2 class="text-lg font-semibold text-gray-900 dark:text-white">Manage Preferences</h2>
                            <form method="POST" action="{{ route('email.subscribers.update', ['subscriber' => $subscriber->id]) }}" class="mt-4 space-y-4">
                                @csrf
                                @method('PATCH')

                                <div>
                                    <label class="block text-sm font-medium text-gray-700 dark:text-gray-200" for="marketing_status">Marketing status</label>
                                    <select id="marketing_status" name="marketing_status" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 dark:bg-gray-900 dark:border-gray-700 dark:text-gray-100">
                                        <option value="unchanged">No change</option>
                                        <option value="opt_in">Opt in</option>
                                        <option value="opt_out">Opt out</option>
                                    </select>
                                </div>

                                <div>
                                    <label class="block text-sm font-medium text-gray-700 dark:text-gray-200" for="list_id">List</label>
                                    <select id="list_id" name="list_id" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 dark:bg-gray-900 dark:border-gray-700 dark:text-gray-100">
                                        <option value="">No list change</option>
                                        @foreach ($subscriber->subscriptions as $subscription)
                                            <option value="{{ $subscription->list_id }}">
                                                {{ $subscription->list?->name ?? 'List' }}
                                            </option>
                                        @endforeach
                                    </select>
                                </div>

                                <div>
                                    <label class="block text-sm font-medium text-gray-700 dark:text-gray-200" for="list_status">List status</label>
                                    <select id="list_status" name="list_status" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 dark:bg-gray-900 dark:border-gray-700 dark:text-gray-100">
                                        <option value="">No change</option>
                                        <option value="subscribed">Subscribed</option>
                                        <option value="unsubscribed">Unsubscribed</option>
                                        <option value="pending">Pending</option>
                                    </select>
                                </div>

                                <button type="submit" class="inline-flex items-center rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700">Save</button>
                            </form>
                        </div>
                    </div>

                    <div class="bg-white dark:bg-gray-800 shadow-sm sm:rounded-lg">
                        <div class="p-4 sm:p-6">
                            <h2 class="text-lg font-semibold text-gray-900 dark:text-white">Subscriptions</h2>
                            <div class="mt-4 space-y-3 text-sm text-gray-600 dark:text-gray-300">
                                @forelse ($subscriber->subscriptions as $subscription)
                                    <div class="rounded-md border border-gray-200 p-3 dark:border-gray-700">
                                        <div class="flex items-start justify-between gap-2">
                                            <p class="font-medium">{{ $subscription->list?->name ?? 'List' }}</p>
                                            <form method="POST" action="{{ route('email.subscribers.remove_list', ['subscriber' => $subscriber->id, 'list' => $subscription->list_id]) }}">
                                                @csrf
                                                @method('DELETE')
                                                <button type="submit" class="text-xs text-red-600 hover:text-red-800">Remove</button>
                                            </form>
                                        </div>
                                        <p>Status: <span class="capitalize">{{ $subscription->status }}</span></p>
                                        <p>Updated: {{ $subscription->status_updated_at ? $subscription->status_updated_at->toDateTimeString() : '—' }}</p>
                                        <p>Source: {{ $subscription->source ?? '—' }}</p>
                                    </div>
                                @empty
                                    <p>No subscriptions found.</p>
                                @endforelse
                            </div>
                        </div>
                    </div>
                </div>

                <div class="lg:col-span-2">
                    <div class="bg-white dark:bg-gray-800 shadow-sm sm:rounded-lg">
                        <div class="p-4 sm:p-6">
                            <h2 class="text-lg font-semibold text-gray-900 dark:text-white">Delivery History</h2>
                            <div class="mt-4 overflow-x-auto">
                                <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
                                    <thead class="bg-gray-50 dark:bg-gray-900">
                                        <tr>
                                            <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Campaign</th>
                                            <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Status</th>
                                            <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Reason</th>
                                            <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Provider ID</th>
                                            <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Sent</th>
                                        </tr>
                                    </thead>
                                    <tbody class="divide-y divide-gray-100 dark:divide-gray-700">
                                        @forelse ($recipientStats as $recipient)
                                            <tr>
                                                <td class="px-4 py-3 text-sm text-gray-900 dark:text-gray-100">
                                                    {{ $recipient->campaign?->subject ?? 'Campaign' }}
                                                </td>
                                                <td class="px-4 py-3 text-sm text-gray-600 dark:text-gray-300 capitalize">{{ $recipient->status }}</td>
                                                <td class="px-4 py-3 text-sm text-gray-600 dark:text-gray-300">{{ $recipient->suppression_reason ?? '—' }}</td>
                                                <td class="px-4 py-3 text-sm text-gray-600 dark:text-gray-300">{{ $recipient->provider_message_id ?? '—' }}</td>
                                                <td class="px-4 py-3 text-sm text-gray-600 dark:text-gray-300">{{ $recipient->sent_at ? $recipient->sent_at->toDateTimeString() : '—' }}</td>
                                            </tr>
                                        @empty
                                            <tr>
                                                <td colspan="5" class="px-4 py-6 text-center text-sm text-gray-500">No delivery history.</td>
                                            </tr>
                                        @endforelse
                                    </tbody>
                                </table>
                            </div>
                            <div class="mt-4">{{ $recipientStats->links() }}</div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
</x-app-admin-layout>
