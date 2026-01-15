<x-app-layout title="Subscribe">
    <div class="min-h-screen bg-gradient-to-br from-slate-50 via-white to-amber-50">
        <div class="mx-auto max-w-2xl px-6 py-16">
            <div class="rounded-2xl bg-white shadow-xl ring-1 ring-gray-200">
                <div class="px-8 py-10">
                    <div class="flex flex-col gap-3">
                        <p class="text-sm font-semibold uppercase tracking-widest text-indigo-500">Email updates</p>
                        <h1 class="text-3xl font-semibold text-gray-900">
                            {{ $event ? 'Stay in the loop for ' . $event->translatedName() : 'Get Planify updates' }}
                        </h1>
                        <p class="text-base text-gray-600">
                            {{ $event ? 'Join the event mailing list for schedule updates and important announcements.' : 'Subscribe for new event announcements and platform news.' }}
                        </p>
                    </div>

                    <form method="POST" action="{{ route('public.subscribe') }}" class="mt-8 space-y-6">
                        @csrf
                        <input type="hidden" name="list_id" value="{{ $list->id }}">
                        @if ($event)
                            <input type="hidden" name="event_id" value="{{ \App\Utils\UrlUtils::encodeId($event->id) }}">
                        @endif

                        <div class="grid gap-6 sm:grid-cols-2">
                            <div>
                                <label class="block text-sm font-medium text-gray-700" for="first_name">First name</label>
                                <input id="first_name" name="first_name" type="text" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500">
                            </div>
                            <div>
                                <label class="block text-sm font-medium text-gray-700" for="last_name">Last name</label>
                                <input id="last_name" name="last_name" type="text" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500">
                            </div>
                        </div>

                        <div>
                            <label class="block text-sm font-medium text-gray-700" for="email">Email address</label>
                            <input id="email" name="email" type="email" required class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500">
                            @error('email')
                                <p class="mt-2 text-sm text-red-600">{{ $message }}</p>
                            @enderror
                        </div>

                        <button type="submit" class="inline-flex w-full items-center justify-center rounded-md bg-indigo-600 px-4 py-2 text-sm font-semibold text-white shadow-sm transition hover:bg-indigo-700">
                            Subscribe
                        </button>

                        <p class="text-xs text-gray-500">By subscribing, you agree to receive email updates. You can unsubscribe at any time.</p>
                    </form>
                </div>
            </div>
        </div>
    </div>
</x-app-layout>
