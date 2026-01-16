<x-app-admin-layout>
    <div class="py-12">
        <div class="max-w-4xl mx-auto space-y-6">
            <div class="p-4 sm:p-8 bg-white dark:bg-gray-800 shadow-md sm:rounded-lg">
                <div class="max-w-3xl">
                    <section>
                        <header>
                            <x-breadcrumbs
                                :items="[
                                    ['label' => __('messages.settings'), 'url' => route('settings.index')],
                                    ['label' => __('messages.privacy_settings'), 'current' => true],
                                ]"
                                class="text-xs text-gray-500 dark:text-gray-400"
                            />
                            <h2 class="mt-2 text-lg font-medium text-gray-900 dark:text-gray-100">
                                {{ __('messages.privacy_settings') }}
                            </h2>

                            <p class="mt-1 text-sm text-gray-600 dark:text-gray-400">
                                {{ __('messages.privacy_settings_description') }}
                            </p>
                        </header>

                        <form method="post" action="{{ route('settings.privacy.update') }}" class="mt-6 space-y-6">
                            @csrf
                            @method('patch')

                            <div>
                                <x-input-label for="privacy_markdown" :value="__('messages.privacy_settings_label')" />
                                <textarea id="privacy_markdown" name="privacy_markdown"
                                          class="html-editor mt-1 block w-full border-gray-300 dark:border-gray-700 dark:bg-gray-900 dark:text-gray-300 focus:border-[#4E81FA] dark:focus:border-[#4E81FA] focus:ring-[#4E81FA] dark:focus:ring-[#4E81FA] rounded-md shadow-sm">{{ old('privacy_markdown', $privacySettings['privacy_markdown']) }}</textarea>
                                <p class="mt-2 text-sm text-gray-500 dark:text-gray-400">
                                    {{ __('messages.privacy_settings_hint') }}
                                </p>
                                <x-input-error class="mt-2" :messages="$errors->get('privacy_markdown')" />
                            </div>

                            <div class="flex flex-wrap items-center gap-4">
                                <x-primary-button>{{ __('messages.save') }}</x-primary-button>
                                <x-secondary-button type="submit" form="privacy-refresh-form">
                                    {{ __('messages.privacy_settings_refresh') }}
                                </x-secondary-button>

                                @if (session('status') === 'privacy-settings-updated')
                                    <p x-data="{ show: true }" x-show="show" x-transition x-init="setTimeout(() => show = false, 2000)"
                                       class="text-sm text-gray-600 dark:text-gray-400">{{ __('messages.privacy_settings_saved') }}</p>
                                @endif
                                @if (session('status') === 'privacy-formatting-refreshed')
                                    <p x-data="{ show: true }" x-show="show" x-transition x-init="setTimeout(() => show = false, 2000)"
                                       class="text-sm text-gray-600 dark:text-gray-400">{{ __('messages.privacy_settings_refreshed') }}</p>
                                @endif
                            </div>
                        </form>
                        <form id="privacy-refresh-form" method="post" action="{{ route('settings.privacy.refresh') }}" class="hidden">
                            @csrf
                        </form>
                    </section>
                </div>
            </div>
        </div>
    </div>
</x-app-admin-layout>
