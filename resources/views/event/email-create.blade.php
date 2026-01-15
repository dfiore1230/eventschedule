<x-app-admin-layout>
    <div class="py-12">
        <div class="max-w-4xl mx-auto space-y-6">
            <div class="flex items-center justify-between">
                <div>
                    <h1 class="text-2xl font-semibold text-gray-900 dark:text-white">New Event Campaign</h1>
                    <p class="text-sm text-gray-600 dark:text-gray-400">{{ $event->name }}</p>
                </div>
                <a href="{{ route('event.email.index', ['subdomain' => $subdomain, 'hash' => \App\Utils\UrlUtils::encodeId($event->id)]) }}" class="text-sm text-gray-600 hover:text-gray-900">Back to Event Email</a>
            </div>

            <div class="bg-white dark:bg-gray-800 shadow-sm sm:rounded-lg">
                <form method="POST" action="{{ route('event.email.store', ['subdomain' => $subdomain, 'hash' => \App\Utils\UrlUtils::encodeId($event->id)]) }}" class="p-4 sm:p-6 space-y-6">
                    @csrf

                    @if ($templates->isNotEmpty())
                        <div>
                            <label class="block text-sm font-medium text-gray-700 dark:text-gray-200" for="template_id">Template</label>
                            <select id="template_id"
                                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 dark:bg-gray-900 dark:border-gray-700 dark:text-gray-100"
                                onchange="if (this.value) { window.location = '{{ route('event.email.create', ['subdomain' => $subdomain, 'hash' => \App\Utils\UrlUtils::encodeId($event->id)]) }}' + '?template_id=' + this.value; }">
                                <option value="">Select a template</option>
                                @foreach ($templates as $template)
                                    <option value="{{ $template->id }}" {{ $selectedTemplate && $selectedTemplate->id === $template->id ? 'selected' : '' }}>
                                        {{ $template->name }}
                                    </option>
                                @endforeach
                            </select>
                        </div>
                    @endif

                    <div>
                        <x-input-label for="subject" value="Subject" />
                        <x-text-input id="subject" name="subject" type="text" class="mt-1 block w-full" :value="old('subject', $defaults['subject'] ?? '')" required />
                        <x-input-error class="mt-2" :messages="$errors->get('subject')" />
                    </div>

                    <div class="grid gap-6 sm:grid-cols-2">
                        <div>
                            <x-input-label for="from_name" value="From name" />
                            <x-text-input id="from_name" name="from_name" type="text" class="mt-1 block w-full" :value="old('from_name', $defaults['from_name'])" required />
                            <x-input-error class="mt-2" :messages="$errors->get('from_name')" />
                        </div>
                        <div>
                            <x-input-label for="from_email" value="From email" />
                            <x-text-input id="from_email" name="from_email" type="email" class="mt-1 block w-full" :value="old('from_email', $defaults['from_email'])" required />
                            <x-input-error class="mt-2" :messages="$errors->get('from_email')" />
                        </div>
                    </div>

                    <div>
                        <x-input-label for="reply_to" value="Reply-to" />
                        <x-text-input id="reply_to" name="reply_to" type="email" class="mt-1 block w-full" :value="old('reply_to', $defaults['reply_to'])" />
                        <x-input-error class="mt-2" :messages="$errors->get('reply_to')" />
                    </div>

                    <div class="grid gap-6 sm:grid-cols-2">
                        <div>
                            <x-input-label for="email_type" value="Email type" />
                            <select id="email_type" name="email_type" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 dark:bg-gray-900 dark:border-gray-700 dark:text-gray-100">
                                <option value="marketing" {{ old('email_type', $defaults['email_type'] ?? 'marketing') === 'marketing' ? 'selected' : '' }}>Marketing</option>
                                <option value="notification" {{ old('email_type', $defaults['email_type'] ?? 'marketing') === 'notification' ? 'selected' : '' }}>Notification</option>
                            </select>
                            <x-input-error class="mt-2" :messages="$errors->get('email_type')" />
                        </div>
                        <div>
                            <x-input-label for="scheduled_at" value="Schedule (optional)" />
                            <x-text-input id="scheduled_at" name="scheduled_at" type="datetime-local" class="mt-1 block w-full" :value="old('scheduled_at')" />
                            <x-input-error class="mt-2" :messages="$errors->get('scheduled_at')" />
                        </div>
                    </div>

                    <div>
                        <x-input-label for="content_markdown" value="Content (Markdown)" />
                        <textarea id="content_markdown" name="content_markdown" rows="12" class="html-editor mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 dark:bg-gray-900 dark:border-gray-700 dark:text-gray-100">{{ old('content_markdown', $defaults['content_markdown'] ?? '') }}</textarea>
                        <x-input-error class="mt-2" :messages="$errors->get('content_markdown')" />
                    </div>

                    <div class="rounded-md border border-gray-200 bg-gray-50 p-4 dark:border-gray-700 dark:bg-gray-900">
                        <div class="flex items-center gap-3">
                            <input id="save_template" name="save_template" type="checkbox" value="1" class="h-4 w-4 rounded border-gray-300 text-indigo-600 focus:ring-indigo-500">
                            <label class="text-sm text-gray-700 dark:text-gray-200" for="save_template">Save as template</label>
                        </div>
                        <div class="mt-3">
                            <x-input-label for="template_name" value="Template name" />
                            <x-text-input id="template_name" name="template_name" type="text" class="mt-1 block w-full" :value="old('template_name')" />
                            <x-input-error class="mt-2" :messages="$errors->get('template_name')" />
                        </div>
                    </div>

                    <div class="flex flex-wrap items-center gap-3">
                        <button type="submit" name="action" value="draft" class="inline-flex items-center rounded-md border border-gray-300 px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 dark:border-gray-700 dark:text-gray-200 dark:hover:bg-gray-800">Save Draft</button>
                        <button type="submit" name="action" value="send" class="inline-flex items-center rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700">Send Campaign</button>
                    </div>
                </form>
            </div>
        </div>
    </div>
</x-app-admin-layout>
