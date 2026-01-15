<x-app-admin-layout>
    @php
        $mailSettings = $mailSettings ?? [];
        $massEmailSettings = $massEmailSettings ?? [];

        if ($mailSettings instanceof \Illuminate\Support\Collection) {
            $mailSettings = $mailSettings->toArray();
        } elseif (is_object($mailSettings)) {
            $mailSettings = (array) $mailSettings;
        }

        if ($massEmailSettings instanceof \Illuminate\Support\Collection) {
            $massEmailSettings = $massEmailSettings->toArray();
        } elseif (is_object($massEmailSettings)) {
            $massEmailSettings = (array) $massEmailSettings;
        }

        $mailTemplates = $mailTemplates ?? [];

        if ($mailTemplates instanceof \Illuminate\Support\Collection) {
            $mailTemplates = $mailTemplates->toArray();
        } elseif (is_object($mailTemplates)) {
            $mailTemplates = (array) $mailTemplates;
        }
    @endphp
    <div class="py-12">
        <div class="max-w-4xl mx-auto space-y-6">
            <div class="p-4 sm:p-8 bg-white dark:bg-gray-800 shadow-md sm:rounded-lg">
                <div class="max-w-3xl">
                    <div class="mb-6 border-b border-gray-100 pb-4 dark:border-gray-800">
                        <x-breadcrumbs
                            :items="[
                                ['label' => __('messages.settings'), 'url' => route('settings.index')],
                                ['label' => __('messages.email_settings'), 'current' => true],
                            ]"
                            class="text-xs text-gray-500 dark:text-gray-400"
                        />
                        <h1 class="mt-2 text-2xl font-semibold text-gray-900 dark:text-white">
                            {{ __('messages.email_settings') }}
                        </h1>
                        <p class="mt-1 text-sm text-gray-600 dark:text-gray-400">
                            {{ __('messages.email_settings_description') }}
                        </p>
                    </div>

                    <section>

                        <form method="post" action="{{ route('settings.mail.update') }}" class="mt-6 space-y-6"
                            x-ref="form"
                            x-data="{
                                testing: false,
                                result: null,
                                async sendTestEmail() {
                                    this.testing = true;
                                    this.result = null;

                                    const formData = new FormData(this.$refs.form);
                                    formData.delete('_method');

                                    try {
                                        const response = await fetch('{{ route('settings.mail.test', [], false) }}', {
                                            method: 'POST',
                                            headers: {
                                                'Accept': 'application/json',
                                                'X-Requested-With': 'XMLHttpRequest',
                                            },
                                            body: formData,
                                        });

                                        const data = await response.json().catch(() => ({}));

                                        const logs = Array.isArray(data.logs) ? data.logs : [];
                                        const failures = Array.isArray(data.failures) ? data.failures : [];

                                        if (response.ok && data.status === 'success') {
                                            this.result = {
                                                success: true,
                                                message: data.message || '{{ __('messages.test_email_sent') }}',
                                                logs,
                                                failures,
                                            };
                                        } else {
                                            this.result = {
                                                success: false,
                                                message: data.message || '{{ __('messages.test_email_failed') }}',
                                                error: data.error || null,
                                                logs,
                                                failures,
                                            };
                                        }
                                    } catch (error) {
                                        this.result = {
                                            success: false,
                                            message: '{{ __('messages.test_email_failed') }}',
                                            error: error.message,
                                            logs: [],
                                            failures: [],
                                        };
                                    } finally {
                                        this.testing = false;
                                    }
                                }
                            }"
                            x-on:submit="result = null">
                            @csrf
                            @method('patch')

                            <div>
                                <x-input-label for="mail_mailer" :value="__('messages.mail_mailer')" />
                                <select id="mail_mailer" name="mail_mailer"
                                    class="mt-1 block w-full border-gray-300 dark:border-gray-700 dark:bg-gray-900 dark:text-gray-300 focus:border-[#4E81FA] dark:focus:border-[#4E81FA] focus:ring-[#4E81FA] dark:focus:ring-[#4E81FA] rounded-md shadow-sm">
                                    @foreach($availableMailers as $value => $label)
                                        <option value="{{ $value }}" {{ old('mail_mailer', $mailSettings['mailer']) === $value ? 'selected' : '' }}>
                                            {{ $label }}
                                        </option>
                                    @endforeach
                                </select>
                                <x-input-error class="mt-2" :messages="$errors->get('mail_mailer')" />
                            </div>

                            <div class="grid gap-6 sm:grid-cols-2">
                                <div>
                                    <x-input-label for="mail_host" :value="__('messages.mail_host')" />
                                    <x-text-input id="mail_host" name="mail_host" type="text" class="mt-1 block w-full"
                                        :value="old('mail_host', $mailSettings['host'])" autocomplete="off" />
                                    <x-input-error class="mt-2" :messages="$errors->get('mail_host')" />
                                </div>

                                <div>
                                    <x-input-label for="mail_port" :value="__('messages.mail_port')" />
                                    <x-text-input id="mail_port" name="mail_port" type="number" class="mt-1 block w-full"
                                        :value="old('mail_port', $mailSettings['port'])" min="1" max="65535" />
                                    <x-input-error class="mt-2" :messages="$errors->get('mail_port')" />
                                </div>
                            </div>

                            <div class="grid gap-6 sm:grid-cols-2">
                                <div>
                                    <x-input-label for="mail_username" :value="__('messages.mail_username')" />
                                    <x-text-input id="mail_username" name="mail_username" type="text" class="mt-1 block w-full"
                                        :value="old('mail_username', $mailSettings['username'])" autocomplete="off" />
                                    <x-input-error class="mt-2" :messages="$errors->get('mail_username')" />
                                </div>

                                <div>
                                    <x-input-label for="mail_password" :value="__('messages.mail_password')" />
                                    <x-text-input id="mail_password" name="mail_password" type="password" class="mt-1 block w-full"
                                        :value="old('mail_password')" autocomplete="new-password" />
                                    <x-input-error class="mt-2" :messages="$errors->get('mail_password')" />
                                </div>
                            </div>

                            <div class="grid gap-6 sm:grid-cols-2">
                                <div>
                                    <x-input-label for="mail_encryption" :value="__('messages.mail_encryption')" />
                                    <select id="mail_encryption" name="mail_encryption"
                                        class="mt-1 block w-full border-gray-300 dark:border-gray-700 dark:bg-gray-900 dark:text-gray-300 focus:border-[#4E81FA] dark:focus:border-[#4E81FA] focus:ring-[#4E81FA] dark:focus:ring-[#4E81FA] rounded-md shadow-sm">
                                        @foreach($availableEncryptions as $value => $label)
                                            <option value="{{ $value }}" {{ old('mail_encryption', $mailSettings['encryption'] ?? '') === $value ? 'selected' : '' }}>
                                                {{ $label }}
                                            </option>
                                        @endforeach
                                    </select>
                                    <x-input-error class="mt-2" :messages="$errors->get('mail_encryption')" />
                                </div>

                                <div>
                                    <x-input-label for="mail_from_name" :value="__('messages.mail_from_name')" />
                                    <x-text-input id="mail_from_name" name="mail_from_name" type="text" class="mt-1 block w-full"
                                        :value="old('mail_from_name', $mailSettings['from_name'])" />
                                    <x-input-error class="mt-2" :messages="$errors->get('mail_from_name')" />
                                </div>
                            </div>

                            <div>
                                <x-input-label for="mail_from_address" :value="__('messages.mail_from_address')" />
                                <x-text-input id="mail_from_address" name="mail_from_address" type="email" class="mt-1 block w-full"
                                    :value="old('mail_from_address', $mailSettings['from_address'])" autocomplete="off" />
                                <x-input-error class="mt-2" :messages="$errors->get('mail_from_address')" />
                            </div>

                            <div>
                                <x-checkbox name="mail_disable_delivery" label="{{ __('messages.mail_disable_delivery') }}"
                                    :checked="old('mail_disable_delivery', $mailSettings['disable_delivery'])" />
                                <p class="mt-2 text-sm text-gray-600 dark:text-gray-400">
                                    {{ __('messages.mail_disable_delivery_help') }}
                                </p>
                            </div>

                            <div class="mt-8 border-t border-gray-100 pt-6 dark:border-gray-700">
                                <h2 class="text-lg font-semibold text-gray-900 dark:text-white">{{ __('messages.mass_email_settings') }}</h2>
                                <p class="mt-1 text-sm text-gray-600 dark:text-gray-400">{{ __('messages.mass_email_settings_description') }}</p>
                            </div>

                            <div>
                                <x-input-label for="mass_email_provider" :value="__('messages.mass_email_provider')" />
                                <select id="mass_email_provider" name="mass_email_provider"
                                    class="mt-1 block w-full border-gray-300 dark:border-gray-700 dark:bg-gray-900 dark:text-gray-300 focus:border-[#4E81FA] dark:focus:border-[#4E81FA] focus:ring-[#4E81FA] dark:focus:ring-[#4E81FA] rounded-md shadow-sm">
                                    @foreach($availableEmailProviders as $value => $label)
                                        <option value="{{ $value }}" {{ old('mass_email_provider', $massEmailSettings['provider']) === $value ? 'selected' : '' }}>
                                            {{ $label }}
                                        </option>
                                    @endforeach
                                </select>
                                <x-input-error class="mt-2" :messages="$errors->get('mass_email_provider')" />
                            </div>

                            <div class="grid gap-6 sm:grid-cols-2">
                                <div>
                                    <x-input-label for="mass_email_from_name" :value="__('messages.mass_email_from_name')" />
                                    <x-text-input id="mass_email_from_name" name="mass_email_from_name" type="text" class="mt-1 block w-full"
                                        :value="old('mass_email_from_name', $massEmailSettings['from_name'] ?? '')" />
                                    <x-input-error class="mt-2" :messages="$errors->get('mass_email_from_name')" />
                                </div>
                                <div>
                                    <x-input-label for="mass_email_from_email" :value="__('messages.mass_email_from_email')" />
                                    <x-text-input id="mass_email_from_email" name="mass_email_from_email" type="email" class="mt-1 block w-full"
                                        :value="old('mass_email_from_email', $massEmailSettings['from_email'] ?? '')" />
                                    <x-input-error class="mt-2" :messages="$errors->get('mass_email_from_email')" />
                                </div>
                            </div>

                            <div>
                                <x-input-label for="mass_email_reply_to" :value="__('messages.mass_email_reply_to')" />
                                <x-text-input id="mass_email_reply_to" name="mass_email_reply_to" type="email" class="mt-1 block w-full"
                                    :value="old('mass_email_reply_to', $massEmailSettings['reply_to'] ?? '')" />
                                <x-input-error class="mt-2" :messages="$errors->get('mass_email_reply_to')" />
                            </div>

                            <div class="grid gap-6 sm:grid-cols-2">
                                <div>
                                    <x-input-label for="mass_email_api_key" :value="__('messages.mass_email_api_key')" />
                                    <x-text-input id="mass_email_api_key" name="mass_email_api_key" type="password" class="mt-1 block w-full"
                                        :value="old('mass_email_api_key')" autocomplete="new-password" />
                                    @if (!empty($massEmailSettings['api_key']))
                                        <p class="mt-1 text-xs text-gray-500">{{ __('messages.secret_stored') }}</p>
                                    @endif
                                    <x-input-error class="mt-2" :messages="$errors->get('mass_email_api_key')" />
                                </div>
                                <div>
                                    <x-input-label for="mass_email_webhook_secret" :value="__('messages.mass_email_webhook_secret')" />
                                    <x-text-input id="mass_email_webhook_secret" name="mass_email_webhook_secret" type="password" class="mt-1 block w-full"
                                        :value="old('mass_email_webhook_secret')" autocomplete="new-password" />
                                    @if (!empty($massEmailSettings['webhook_secret']))
                                        <p class="mt-1 text-xs text-gray-500">{{ __('messages.secret_stored') }}</p>
                                    @endif
                                    <x-input-error class="mt-2" :messages="$errors->get('mass_email_webhook_secret')" />
                                </div>
                            </div>

                            <div class="grid gap-6 sm:grid-cols-2">
                                <div>
                                    <x-input-label for="mass_email_sending_domain" :value="__('messages.mass_email_sending_domain')" />
                                    <x-text-input id="mass_email_sending_domain" name="mass_email_sending_domain" type="text" class="mt-1 block w-full"
                                        :value="old('mass_email_sending_domain', $massEmailSettings['sending_domain'] ?? '')" />
                                    <x-input-error class="mt-2" :messages="$errors->get('mass_email_sending_domain')" />
                                </div>
                                <div>
                                    <x-input-label for="mass_email_batch_size" :value="__('messages.mass_email_batch_size')" />
                                    <x-text-input id="mass_email_batch_size" name="mass_email_batch_size" type="number" class="mt-1 block w-full"
                                        :value="old('mass_email_batch_size', $massEmailSettings['batch_size'] ?? '')" min="1" max="5000" />
                                    <x-input-error class="mt-2" :messages="$errors->get('mass_email_batch_size')" />
                                </div>
                            </div>

                            <div>
                                <x-input-label for="mass_email_rate_limit" :value="__('messages.mass_email_rate_limit')" />
                                <x-text-input id="mass_email_rate_limit" name="mass_email_rate_limit" type="number" class="mt-1 block w-full"
                                    :value="old('mass_email_rate_limit', $massEmailSettings['rate_limit_per_minute'] ?? '')" min="1" max="100000" />
                                <x-input-error class="mt-2" :messages="$errors->get('mass_email_rate_limit')" />
                            </div>

                            <div class="grid gap-6 sm:grid-cols-2">
                                <div>
                                    <x-input-label for="mass_email_retry_attempts" value="Retry attempts" />
                                    <x-text-input id="mass_email_retry_attempts" name="mass_email_retry_attempts" type="number" class="mt-1 block w-full"
                                        :value="old('mass_email_retry_attempts', $massEmailSettings['retry_attempts'] ?? '')" min="1" max="10" />
                                    <x-input-error class="mt-2" :messages="$errors->get('mass_email_retry_attempts')" />
                                </div>
                                <div>
                                    <x-input-label for="mass_email_retry_backoff" value="Retry backoff (seconds)" />
                                    <x-text-input id="mass_email_retry_backoff" name="mass_email_retry_backoff" type="text" class="mt-1 block w-full"
                                        :value="old('mass_email_retry_backoff', $massEmailSettings['retry_backoff_seconds'] ?? '')" placeholder="60,300,900" />
                                    <x-input-error class="mt-2" :messages="$errors->get('mass_email_retry_backoff')" />
                                </div>
                            </div>

                            <div class="grid gap-6 sm:grid-cols-2">
                                <div>
                                    <x-input-label for="mass_email_physical_address" value="Physical mailing address" />
                                    <x-text-input id="mass_email_physical_address" name="mass_email_physical_address" type="text" class="mt-1 block w-full"
                                        :value="old('mass_email_physical_address', $massEmailSettings['physical_address'] ?? '')" />
                                    <x-input-error class="mt-2" :messages="$errors->get('mass_email_physical_address')" />
                                </div>
                            </div>

                            <div>
                                <x-input-label for="mass_email_unsubscribe_footer" value="Compliance footer" />
                                <textarea id="mass_email_unsubscribe_footer" name="mass_email_unsubscribe_footer" rows="4"
                                    class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-[#4E81FA] focus:ring-[#4E81FA] dark:border-gray-700 dark:bg-gray-900 dark:text-gray-300">{{ old('mass_email_unsubscribe_footer', $massEmailSettings['unsubscribe_footer'] ?? '') }}</textarea>
                                <p class="mt-2 text-xs text-gray-500">
                                    Supports @{{unsubscribeUrl}}, @{{unsubscribeAllUrl}}, and @{{physicalAddress}} placeholders.
                                </p>
                                <x-input-error class="mt-2" :messages="$errors->get('mass_email_unsubscribe_footer')" />
                            </div>

                            <div class="flex flex-wrap items-center gap-4">
                                <x-primary-button>{{ __('messages.save') }}</x-primary-button>

                                <x-secondary-button type="button" x-on:click="sendTestEmail" x-bind:disabled="testing">
                                    <span x-text="testing ? '{{ __('messages.sending_test_email') }}' : '{{ __('messages.send_test_email') }}'"
                                        class="whitespace-nowrap"></span>
                                </x-secondary-button>

                                @if (session('status') === 'mail-settings-updated')
                                    <p x-data="{ show: true }" x-show="show" x-transition x-init="setTimeout(() => show = false, 2000)"
                                        class="text-sm text-gray-600 dark:text-gray-400">{{ __('messages.email_settings_saved') }}</p>
                                @endif
                            </div>

                            <div x-cloak x-show="result" x-transition
                                :class="result?.success ? 'border-green-200 bg-green-50 text-green-700' : 'border-red-200 bg-red-50 text-red-700'"
                                class="rounded-md border px-4 py-3 text-sm">
                                <p class="font-medium" x-text="result?.message ?? ''"></p>
                                <template x-if="!result?.success && result?.error">
                                    <p class="mt-2"><span class="font-medium">{{ __('messages.error_details') }}</span>
                                        <span x-text="result.error"></span>
                                    </p>
                                </template>
                                <template x-if="result?.failures?.length">
                                    <div class="mt-2">
                                        <p class="font-medium">{{ __('messages.test_email_failed_recipients') }}</p>
                                        <ul class="mt-1 list-inside list-disc space-y-1">
                                            <template x-for="(failure, index) in result.failures" :key="index">
                                                <li class="font-mono" x-text="failure"></li>
                                            </template>
                                        </ul>
                                    </div>
                                </template>
                                <template x-if="result?.logs?.length">
                                    <div class="mt-4 rounded-md border border-gray-200 bg-white p-3 text-xs text-gray-800 dark:border-gray-700 dark:bg-gray-900 dark:text-gray-200">
                                        <p class="mb-2 font-semibold uppercase tracking-wide text-gray-500 dark:text-gray-400 text-[11px]">
                                            {{ __('messages.test_email_logs') }}
                                        </p>
                                        <div class="space-y-1">
                                            <template x-for="(logLine, index) in result.logs" :key="index">
                                                <div class="font-mono" x-text="logLine"></div>
                                            </template>
                                        </div>
                                    </div>
                                </template>
                            </div>
                        </form>
                    </section>
                </div>
            </div>
            <div class="p-4 sm:p-8 bg-white dark:bg-gray-800 shadow-md sm:rounded-lg">
                <div class="max-w-3xl">
                    <section>
                        <header>
                            <h2 class="text-lg font-medium text-gray-900 dark:text-gray-100">
                                {{ __('messages.email_templates') }}
                            </h2>

                            <p class="mt-1 text-sm text-gray-600 dark:text-gray-400">
                                {{ __('messages.email_templates_description') }}
                            </p>
                        </header>

                        <div class="mt-6 space-y-4">
                            @forelse($mailTemplates as $template)
                                <a href="{{ route('settings.email_templates.show', ['template' => $template['key']]) }}"
                                    class="block rounded-lg border border-gray-200 bg-white px-4 py-4 transition hover:shadow-sm focus:outline-none focus:ring-2 focus:ring-[#4E81FA] focus:ring-offset-2 dark:border-gray-700 dark:bg-gray-800">
                                    <div class="flex items-start justify-between gap-4">
                                        <div>
                                            <h3 class="text-base font-semibold text-gray-900 dark:text-gray-100">
                                                {{ $template['label'] }}
                                            </h3>

                                            @if(!empty($template['description']))
                                                <p class="mt-1 text-sm text-gray-600 dark:text-gray-400">
                                                    {{ $template['description'] }}
                                                </p>
                                            @endif
                                        </div>

                                        <span class="inline-flex items-center rounded-full px-2.5 py-1 text-xs font-medium {{ $template['enabled'] ? 'bg-green-100 text-green-800 dark:bg-green-900/40 dark:text-green-300' : 'bg-red-100 text-red-800 dark:bg-red-900/50 dark:text-red-300' }}">
                                            {{ $template['enabled'] ? __('messages.enabled') : __('messages.disabled') }}
                                        </span>
                                    </div>

                                    <div class="mt-4 flex items-center justify-between text-sm text-gray-500 dark:text-gray-400">
                                        <span>{{ __('messages.email_template_status') }}: {{ $template['enabled'] ? __('messages.enabled') : __('messages.disabled') }}</span>
                                        <span class="inline-flex items-center gap-1 text-[#4E81FA]">
                                            <span>{{ __('messages.preview') }}</span>
                                            <svg class="h-4 w-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" aria-hidden="true">
                                                <path stroke-linecap="round" stroke-linejoin="round" d="M9 5l7 7-7 7" />
                                            </svg>
                                        </span>
                                    </div>
                                </a>
                            @empty
                                <p class="text-sm text-gray-600 dark:text-gray-400">{{ __('messages.no_email_templates_defined') }}</p>
                            @endforelse
                        </div>
                    </section>
                </div>
            </div>
        </div>
    </div>
</x-app-admin-layout>
