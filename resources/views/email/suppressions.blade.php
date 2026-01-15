<x-app-admin-layout>
    <div class="py-12">
        <div class="max-w-5xl mx-auto space-y-6">
            <div class="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
                <div>
                    <h1 class="text-2xl font-semibold text-gray-900 dark:text-white">Suppression List</h1>
                    <p class="text-sm text-gray-600 dark:text-gray-400">Manage addresses blocked from future sends.</p>
                </div>
                <a href="{{ route('email.index') }}" class="text-sm text-gray-600 hover:text-gray-900">Back to Email</a>
            </div>

            <div class="rounded-md border border-gray-200 bg-gray-50 p-4 dark:border-gray-700 dark:bg-gray-900">
                <h2 class="text-lg font-semibold text-gray-900 dark:text-white">Add Suppression</h2>
                <form method="POST" action="{{ route('email.suppressions.store') }}" class="mt-4 grid gap-4 sm:grid-cols-3">
                    @csrf
                    <div class="sm:col-span-2">
                        <label class="block text-sm font-medium text-gray-700 dark:text-gray-200" for="suppression_email">Email</label>
                        <input id="suppression_email" name="email" type="email" required
                            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 dark:bg-gray-900 dark:border-gray-700 dark:text-gray-100">
                    </div>
                    <div>
                        <label class="block text-sm font-medium text-gray-700 dark:text-gray-200" for="suppression_reason">Reason</label>
                        <select id="suppression_reason" name="reason"
                            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 dark:bg-gray-900 dark:border-gray-700 dark:text-gray-100">
                            <option value="manual">Manual</option>
                            <option value="bounce">Bounce</option>
                            <option value="complaint">Complaint</option>
                        </select>
                    </div>
                    <div class="sm:col-span-3 flex justify-end">
                        <button type="submit" class="inline-flex items-center rounded-md bg-indigo-600 px-4 py-2 text-sm font-semibold text-white hover:bg-indigo-700">Add</button>
                    </div>
                </form>
            </div>

            <div class="bg-white dark:bg-gray-800 shadow-sm sm:rounded-lg">
                <div class="p-4 sm:p-6">
                    <form method="GET" class="mb-4 flex flex-wrap items-center gap-2">
                        <input name="email" type="text" value="{{ $search }}" placeholder="Search email"
                            class="rounded-md border-gray-300 text-sm shadow-sm focus:border-indigo-500 focus:ring-indigo-500 dark:bg-gray-900 dark:border-gray-700 dark:text-gray-100">
                        <button type="submit" class="text-sm text-indigo-600 hover:text-indigo-800">Search</button>
                    </form>

                    <div class="overflow-x-auto">
                        <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
                            <thead class="bg-gray-50 dark:bg-gray-900">
                                <tr>
                                    <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Email</th>
                                    <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Reason</th>
                                    <th class="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-500">Added</th>
                                    <th class="px-4 py-3"></th>
                                </tr>
                            </thead>
                            <tbody class="divide-y divide-gray-100 dark:divide-gray-700">
                                @forelse ($suppressions as $suppression)
                                    <tr>
                                        <td class="px-4 py-3 text-sm text-gray-900 dark:text-gray-100">{{ $suppression->email }}</td>
                                        <td class="px-4 py-3 text-sm text-gray-600 dark:text-gray-300 capitalize">{{ $suppression->reason }}</td>
                                        <td class="px-4 py-3 text-sm text-gray-600 dark:text-gray-300">{{ $suppression->created_at?->toDateTimeString() ?? '—' }}</td>
                                        <td class="px-4 py-3 text-right text-sm">
                                            <form method="POST" action="{{ route('email.suppressions.destroy', ['suppression' => $suppression->id]) }}">
                                                @csrf
                                                @method('DELETE')
                                                <button type="submit" class="text-xs text-red-600 hover:text-red-800">Remove</button>
                                            </form>
                                        </td>
                                    </tr>
                                @empty
                                    <tr>
                                        <td colspan="4" class="px-4 py-6 text-center text-sm text-gray-500">No suppressions yet.</td>
                                    </tr>
                                @endforelse
                            </tbody>
                        </table>
                    </div>

                    <div class="mt-4">{{ $suppressions->links() }}</div>
                </div>
            </div>
        </div>
    </div>
</x-app-admin-layout>
