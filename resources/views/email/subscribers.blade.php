<x-app-admin-layout>
    <div class="py-12">
        <div class="max-w-6xl mx-auto space-y-6">
            <div class="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
                <div>
                    <h1 class="text-2xl font-semibold text-gray-900 dark:text-white">Subscribers</h1>
                    <p class="text-sm text-gray-600 dark:text-gray-400">View subscription status and opt-out history.</p>
                </div>
                <div class="flex flex-wrap items-center gap-3">
                    <form method="GET" class="flex flex-wrap items-center gap-2">
                        <label class="text-sm text-gray-600 dark:text-gray-400" for="export_list_id">Export list</label>
                        <select id="export_list_id" name="list_id"
                            class="rounded-md border-gray-300 text-sm shadow-sm focus:border-indigo-500 focus:ring-indigo-500 dark:bg-gray-900 dark:border-gray-700 dark:text-gray-100">
                            <option value="">All lists</option>
                            @foreach ($lists as $list)
                                <option value="{{ $list->id }}">
                                    {{ $list->type === \App\Models\EmailList::TYPE_EVENT ? 'Event: ' . ($list->event?->translatedName() ?? $list->event?->name ?? $list->name) : 'Global: ' . $list->name }}
                                </option>
                            @endforeach
                        </select>
                        <button type="submit" formaction="{{ route('email.subscribers.export', ['format' => 'csv']) }}"
                            class="text-sm text-indigo-600 hover:text-indigo-800">CSV</button>
                        <button type="submit" formaction="{{ route('email.subscribers.export', ['format' => 'xlsx']) }}"
                            class="text-sm text-indigo-600 hover:text-indigo-800">Excel</button>
                    </form>
                    <a href="{{ route('email.index') }}" class="text-sm text-gray-600 hover:text-gray-900">Back to Email</a>
                </div>
            </div>

            <div class="bg-white dark:bg-gray-800 shadow-sm sm:rounded-lg">
                <div class="p-4 sm:p-6">
                    <div class="rounded-md border border-gray-200 bg-gray-50 p-4 dark:border-gray-700 dark:bg-gray-900">
                        <h2 class="text-lg font-semibold text-gray-900 dark:text-white">Add Subscriber</h2>
                        <form method="POST" action="{{ route('email.subscribers.add') }}" class="mt-4 grid gap-4 lg:grid-cols-5">
                            @csrf
                            <div class="lg:col-span-2">
                                <label class="block text-sm font-medium text-gray-700 dark:text-gray-200" for="add_email">Email</label>
                                <input id="add_email" name="email" type="email" required
                                    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 dark:bg-gray-900 dark:border-gray-700 dark:text-gray-100">
                            </div>
                            <div>
                                <label class="block text-sm font-medium text-gray-700 dark:text-gray-200" for="add_first_name">First name</label>
                                <input id="add_first_name" name="first_name" type="text"
                                    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 dark:bg-gray-900 dark:border-gray-700 dark:text-gray-100">
                            </div>
                            <div>
                                <label class="block text-sm font-medium text-gray-700 dark:text-gray-200" for="add_last_name">Last name</label>
                                <input id="add_last_name" name="last_name" type="text"
                                    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 dark:bg-gray-900 dark:border-gray-700 dark:text-gray-100">
                            </div>
                            <div>
                                <label class="block text-sm font-medium text-gray-700 dark:text-gray-200" for="add_list_id">List</label>
                                <select id="add_list_id" name="list_id" required
                                    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 dark:bg-gray-900 dark:border-gray-700 dark:text-gray-100">
                                    @foreach ($lists as $list)
                                        <option value="{{ $list->id }}">
                                            {{ $list->type === \App\Models\EmailList::TYPE_EVENT ? 'Event: ' . ($list->event?->translatedName() ?? $list->event?->name ?? $list->name) : 'Global: ' . $list->name }}
                                        </option>
                                    @endforeach
                                </select>
                            </div>
                            <div>
                                <label class="block text-sm font-medium text-gray-700 dark:text-gray-200" for="add_intent">Intent</label>
                                <select id="add_intent" name="intent"
                                    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 dark:bg-gray-900 dark:border-gray-700 dark:text-gray-100">
                                    <option value="invite">Invite to subscribe</option>
                                    <option value="subscribe">Add as subscribed</option>
                                </select>
                            </div>
                            <div class="lg:col-span-5 flex justify-end">
                                <button type="submit" class="inline-flex items-center rounded-md bg-indigo-600 px-4 py-2 text-sm font-semibold text-white hover:bg-indigo-700">Add</button>
                            </div>
                        </form>
                    </div>

                    <form method="POST" action="{{ route('email.subscribers.bulk') }}" class="space-y-4"
                        x-data="{ action: 'marketing' }">
                        @csrf
                        @method('PATCH')
                        <div class="flex flex-col gap-3 lg:flex-row lg:items-end lg:justify-between">
                            <div class="flex flex-col gap-3 sm:flex-row sm:items-end">
                                <div>
                                    <label class="block text-sm font-medium text-gray-700 dark:text-gray-200" for="bulk_action">Bulk action</label>
                                    <select id="bulk_action" name="action"
                                        x-model="action"
                                        class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 dark:bg-gray-900 dark:border-gray-700 dark:text-gray-100">
                                        <option value="marketing">Marketing opt-in/out</option>
                                        <option value="list">List status</option>
                                    </select>
                                </div>
                                <div>
                                    <label class="block text-sm font-medium text-gray-700 dark:text-gray-200" for="bulk_marketing_status">Marketing status</label>
                                    <select id="bulk_marketing_status" name="marketing_status"
                                        x-bind:disabled="action !== 'marketing'"
                                        class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 disabled:bg-gray-100 disabled:text-gray-400 dark:bg-gray-900 dark:border-gray-700 dark:text-gray-100">
                                        <option value="opt_out">Opt out</option>
                                        <option value="opt_in">Opt in</option>
                                    </select>
                                </div>
                                <div>
                                    <label class="block text-sm font-medium text-gray-700 dark:text-gray-200" for="bulk_list_id">List (optional)</label>
                                    <select id="bulk_list_id" name="list_id"
                                        x-bind:disabled="action !== 'list'"
                                        class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 disabled:bg-gray-100 disabled:text-gray-400 dark:bg-gray-900 dark:border-gray-700 dark:text-gray-100">
                                        <option value="">No list change</option>
                                        @foreach ($subscribers->pluck('subscriptions')->flatten()->filter()->map->list->filter()->unique('id') as $list)
                                            <option value="{{ $list->id }}">{{ $list->name }}</option>
                                        @endforeach
                                    </select>
                                </div>
                                <div>
                                    <label class="block text-sm font-medium text-gray-700 dark:text-gray-200" for="bulk_list_status">List status</label>
                                    <select id="bulk_list_status" name="list_status"
                                        x-bind:disabled="action !== 'list'"
                                        class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 disabled:bg-gray-100 disabled:text-gray-400 dark:bg-gray-900 dark:border-gray-700 dark:text-gray-100">
                                        <option value="">No change</option>
                                        <option value="subscribed">Subscribed</option>
                                        <option value="unsubscribed">Unsubscribed</option>
                                        <option value="pending">Pending</option>
                                    </select>
                                </div>
                            </div>
                            <button type="submit" class="inline-flex items-center rounded-md bg-indigo-600 px-4 py-2 text-sm font-semibold text-white hover:bg-indigo-700">Apply to selected</button>
                        </div>

                        <div class="overflow-x-auto">
                            <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
                            <thead class="bg-gray-50 dark:bg-gray-900">
                                <tr>
                                    <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">
                                        <input type="checkbox" id="select_all_subscribers" class="h-4 w-4 rounded border-gray-300 text-indigo-600 focus:ring-indigo-500"
                                            onclick="document.querySelectorAll('.subscriber-select').forEach(cb => cb.checked = this.checked)">
                                    </th>
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
                                        <td class="px-4 py-3 text-sm text-gray-900 dark:text-gray-100">
                                            <input type="checkbox" name="subscriber_ids[]" value="{{ $subscriber->id }}" class="subscriber-select h-4 w-4 rounded border-gray-300 text-indigo-600 focus:ring-indigo-500">
                                        </td>
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
                                        <td colspan="7" class="px-4 py-6 text-center text-sm text-gray-500">No subscribers yet.</td>
                                    </tr>
                                @endforelse
                            </tbody>
                            </table>
                        </div>
                    </form>
                    <div class="mt-4">{{ $subscribers->links() }}</div>
                </div>
            </div>
        </div>
    </div>
</x-app-admin-layout>
