@php
    use App\Utils\UrlUtils;
@endphp

<x-app-admin-layout>

<x-slot name="head">
    <script {!! nonce_attr() !!}>
        document.addEventListener('alpine:init', () => {
            Alpine.data('eventNotifications', (eventId, apiKey) => ({
                apiKey: apiKey || '',
                loading: true,
                saving: false,
                status: '',
                error: '',
                templates: [],
                overrides: {
                    templates: {},
                    channels: {},
                },
                init() {
                    this.fetchData();
                },
                defaultTemplate(key) {
                    return this.templates.find((template) => template.key === key) || {};
                },
                templateEnabled(key) {
                    const override = this.overrides.templates?.[key];

                    if (override && Object.prototype.hasOwnProperty.call(override, 'enabled')) {
                        return !!override.enabled;
                    }

                    const template = this.defaultTemplate(key);

                    return template.enabled !== undefined ? !!template.enabled : true;
                },
                channelEnabled(key) {
                    const override = this.overrides.channels?.[key];

                    if (override && Object.prototype.hasOwnProperty.call(override, 'mail')) {
                        return !!override.mail;
                    }

                    const template = this.defaultTemplate(key);

                    return template.enabled !== undefined ? !!template.enabled : true;
                },
                templateOverrideValue(key, field) {
                    const override = this.overrides.templates?.[key];

                    if (override && Object.prototype.hasOwnProperty.call(override, field)) {
                        return override[field] ?? '';
                    }

                    return '';
                },
                setTemplateField(key, field, value) {
                    if (!this.overrides.templates[key]) {
                        this.overrides.templates[key] = {};
                    }

                    this.overrides.templates[key][field] = value;
                },
                setChannel(key, value) {
                    this.overrides.channels[key] = {
                        ...(this.overrides.channels[key] || {}),
                        mail: !!value,
                    };
                },
                toggleTemplate(key, value) {
                    this.overrides.templates[key] = {
                        ...(this.overrides.templates[key] || {}),
                        enabled: !!value,
                    };
                },
                resetTemplate(key) {
                    delete this.overrides.templates[key];
                    delete this.overrides.channels[key];
                },
                resetAll() {
                    this.overrides = {
                        templates: {},
                        channels: {},
                    };
                    this.status = '';
                },
                placeholderKeys(template) {
                    return Object.keys(template.placeholders || {});
                },
                requireApiKey() {
                    if (this.apiKey) {
                        return true;
                    }

                    this.error = 'Add an API key in Profile -> API Access to manage per-event notifications.';
                    this.loading = false;
                    this.saving = false;
                    return false;
                },
                async fetchData() {
                    this.loading = true;
                    this.error = '';
                    this.status = '';

                    if (!this.requireApiKey()) {
                        return;
                    }

                    try {
                        const response = await fetch(`/api/events/${eventId}/notifications`, {
                            headers: {
                                Accept: 'application/json',
                                'X-API-Key': this.apiKey,
                            },
                        });

                        const payload = await response.json();

                        if (!response.ok) {
                            throw new Error(payload.message || payload.error || 'Unable to load notification settings.');
                        }

                        this.templates = payload.data?.templates || [];
                        this.overrides = {
                            templates: payload.data?.settings?.templates || {},
                            channels: payload.data?.settings?.channels || {},
                        };
                    } catch (error) {
                        this.error = error.message || 'Unable to load notification settings.';
                    } finally {
                        this.loading = false;
                    }
                },
                async save() {
                    this.saving = true;
                    this.error = '';
                    this.status = '';

                    if (!this.requireApiKey()) {
                        return;
                    }

                    try {
                        const csrf = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content');

                        const response = await fetch(`/api/events/${eventId}/notifications`, {
                            method: 'PATCH',
                            headers: {
                                'Content-Type': 'application/json',
                                Accept: 'application/json',
                                'X-API-Key': this.apiKey,
                                ...(csrf ? { 'X-CSRF-TOKEN': csrf } : {}),
                            },
                            body: JSON.stringify({
                                notification_settings: this.overrides,
                            }),
                        });

                        const payload = await response.json();

                        if (!response.ok) {
                            throw new Error(payload.message || payload.error || 'Unable to save notification settings.');
                        }

                        this.templates = payload.data?.templates || this.templates;
                        this.overrides = {
                            templates: payload.data?.settings?.templates || {},
                            channels: payload.data?.settings?.channels || {},
                        };
                        this.status = payload.meta?.message || 'Notification settings updated';
                    } catch (error) {
                        this.error = error.message || 'Unable to save notification settings.';
                    } finally {
                        this.saving = false;
                    }
                },
            }));
        });
    </script>
</x-slot>

<div class="max-w-5xl mx-auto py-8" x-data='eventNotifications(@json(UrlUtils::encodeId($event->id)), @json(auth()->user()->api_key ?? ""))'>
    <div class="flex items-start justify-between gap-4 mb-6">
        <div>
            <p class="text-sm text-gray-600 dark:text-gray-300">Configure per-event notification delivery and override email copy without affecting other events.</p>
        </div>
        <div class="flex items-center gap-3">
            <a href="{{ route('event.edit', ['subdomain' => $subdomain, 'hash' => UrlUtils::encodeId($event->id)]) }}" class="inline-flex items-center px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md shadow-sm hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 dark:bg-gray-800 dark:text-gray-100 dark:border-gray-600 dark:hover:bg-gray-700">
                Back to event
            </a>
            <button type="button" @click="save" :disabled="saving || loading" class="inline-flex items-center px-4 py-2 text-sm font-semibold text-white bg-indigo-600 rounded-md shadow-sm hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 disabled:opacity-60 disabled:cursor-not-allowed">
                <span x-show="!saving">Save changes</span>
                <span x-show="saving">Saving...</span>
            </button>
        </div>
    </div>

    <div class="mb-4" x-show="status">
        <div class="rounded-md bg-green-50 p-4 border border-green-200 text-green-800" x-text="status"></div>
    </div>

    <div class="mb-4" x-show="error">
        <div class="rounded-md bg-red-50 p-4 border border-red-200 text-red-800" x-text="error"></div>
    </div>

    <div x-show="loading" class="p-6 text-center text-gray-600 dark:text-gray-200">Loading notification settings...</div>

    <div x-show="!loading" class="space-y-4">
        <div class="flex justify-end mb-2">
            <button
                type="button"
                class="inline-flex items-center gap-1 px-3 py-1 text-sm font-medium text-red-700 bg-red-50 border border-red-200 rounded hover:text-red-800 hover:bg-red-100 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500 active:bg-red-200"
                @click="resetAll"
            >
                Clear all overrides
            </button>
        </div>

        <template x-for="template in templates" :key="template.key">
            <div class="p-4 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg shadow-sm">
                <div class="flex flex-col md:flex-row md:items-start md:justify-between gap-4">
                    <div class="space-y-1">
                        <h3 class="text-lg font-semibold text-gray-900 dark:text-gray-100" x-text="template.label || template.key"></h3>
                        <p class="text-sm text-gray-600 dark:text-gray-300" x-text="template.description"></p>
                    </div>
                    <div class="space-y-2 text-sm min-w-[180px]">
                        <label class="flex items-center gap-2 text-gray-800 dark:text-gray-100">
                            <input type="checkbox" class="rounded border-gray-300 text-indigo-600 focus:ring-indigo-500" :checked="channelEnabled(template.key)" @change="setChannel(template.key, $event.target.checked)">
                            <span>Send email</span>
                        </label>
                        <label class="flex items-center gap-2 text-gray-800 dark:text-gray-100">
                            <input type="checkbox" class="rounded border-gray-300 text-indigo-600 focus:ring-indigo-500" :checked="templateEnabled(template.key)" @change="toggleTemplate(template.key, $event.target.checked)">
                            <span>Template enabled</span>
                        </label>
                        <button type="button" class="text-xs text-red-600 hover:text-red-700" @click="resetTemplate(template.key)">Reset overrides</button>
                    </div>
                </div>

                <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">
                    <div>
                        <label class="block text-sm font-medium text-gray-700 dark:text-gray-200 mb-1">Subject override</label>
                        <input type="text" class="w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 dark:bg-gray-900 dark:border-gray-700 dark:text-gray-100" :value="templateOverrideValue(template.key, 'subject')" @input="setTemplateField(template.key, 'subject', $event.target.value)">
                        <p class="text-xs text-gray-500 mt-1">Default: <span x-text="template.subject"></span></p>
                    </div>
                    <div>
                        <label class="block text-sm font-medium text-gray-700 dark:text-gray-200 mb-1">Curated subject override</label>
                        <input type="text" class="w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 dark:bg-gray-900 dark:border-gray-700 dark:text-gray-100" :value="templateOverrideValue(template.key, 'subject_curated')" @input="setTemplateField(template.key, 'subject_curated', $event.target.value)">
                        <p class="text-xs text-gray-500 mt-1">Default: <span x-text="template.subject_curated || '—'"></span></p>
                    </div>
                </div>

                <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">
                    <div>
                        <label class="block text-sm font-medium text-gray-700 dark:text-gray-200 mb-1">Body override (Markdown)</label>
                        <textarea rows="5" class="w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 dark:bg-gray-900 dark:border-gray-700 dark:text-gray-100" :value="templateOverrideValue(template.key, 'body')" @input="setTemplateField(template.key, 'body', $event.target.value)"></textarea>
                        <p class="text-xs text-gray-500 mt-1">Default: <span class="font-mono" x-text="(template.body || '').slice(0, 120) + (template.body && template.body.length > 120 ? '…' : '')"></span></p>
                    </div>
                    <div>
                        <label class="block text-sm font-medium text-gray-700 dark:text-gray-200 mb-1">Curated body override (Markdown)</label>
                        <textarea rows="5" class="w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 dark:bg-gray-900 dark:border-gray-700 dark:text-gray-100" :value="templateOverrideValue(template.key, 'body_curated')" @input="setTemplateField(template.key, 'body_curated', $event.target.value)"></textarea>
                        <p class="text-xs text-gray-500 mt-1">Default: <span class="font-mono" x-text="(template.body_curated || '').slice(0, 120) + (template.body_curated && template.body_curated.length > 120 ? '…' : '')"></span></p>
                    </div>
                </div>

                <div class="flex flex-wrap items-center gap-2 mt-4 text-xs text-gray-500 dark:text-gray-300" x-show="placeholderKeys(template).length">
                    <span class="font-semibold">Placeholders:</span>
                    <template x-for="token in placeholderKeys(template)" :key="token">
                        <span class="px-2 py-1 rounded bg-gray-100 dark:bg-gray-700" x-text="token"></span>
                    </template>
                </div>
            </div>
        </template>
    </div>
</div>

</x-app-admin-layout>
