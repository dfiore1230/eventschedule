<x-app-layout title="Privacy">
    <div class="bg-gray-50 dark:bg-gray-900 py-16">
        <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
            <div class="bg-white dark:bg-gray-800 shadow-lg rounded-3xl overflow-hidden">
                <div class="px-6 py-10 sm:px-10">
                    <h1 class="text-3xl font-bold text-gray-900 dark:text-gray-100">
                        Privacy
                    </h1>
                    @if ($lastUpdated)
                        <p class="mt-2 text-sm text-gray-500 dark:text-gray-400">
                            Last updated {{ $lastUpdated->translatedFormat('F j, Y') }}
                        </p>
                    @endif
                    <div class="mt-8 prose prose-indigo max-w-none dark:prose-invert">
                        {!! $privacyHtml !!}
                    </div>
                </div>
            </div>
        </div>
    </div>
</x-app-layout>
