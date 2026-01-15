<x-app-admin-layout>
    <div class="py-12">
        <div class="max-w-5xl mx-auto space-y-6">
            <div class="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
                <div>
                    <h1 class="text-2xl font-semibold text-gray-900 dark:text-white">Email Templates</h1>
                    <p class="text-sm text-gray-600 dark:text-gray-400">Manage reusable campaign templates.</p>
                </div>
                <div class="flex flex-wrap items-center gap-3">
                    <a href="{{ route('email.create') }}" class="text-sm text-indigo-600 hover:text-indigo-800">New Campaign</a>
                    <a href="{{ route('email.index') }}" class="text-sm text-gray-600 hover:text-gray-900">Back to Email</a>
                </div>
            </div>

            <div class="bg-white dark:bg-gray-800 shadow-sm sm:rounded-lg">
                <div class="p-4 sm:p-6">
                    <div class="overflow-x-auto">
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
                                            <a href="{{ route('email.create', ['template_id' => $template->id]) }}" class="text-indigo-600 hover:text-indigo-800">Use</a>
                                            <form method="POST" action="{{ route('email.templates.destroy', ['template' => $template->id]) }}" class="inline">
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

                    <div class="mt-4">{{ $templates->links() }}</div>
                </div>
            </div>
        </div>
    </div>
</x-app-admin-layout>
