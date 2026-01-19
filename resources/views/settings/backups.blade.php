<x-app-admin-layout>
    <div class="py-12">
        <div class="max-w-4xl mx-auto space-y-6">
            <div class="p-4 sm:p-8 bg-white dark:bg-gray-800 shadow-md sm:rounded-lg">
                <div class="max-w-3xl">
                    <section
                        x-data="backupManager({
                            listUrl: '{{ route('settings.backups.list') }}',
                            createUrl: '{{ route('settings.backups.create') }}',
                            restoreUrl: '{{ route('settings.backups.restore') }}',
                            downloadBase: '{{ route('settings.backups.download', ['filename' => 'placeholder']) }}',
                            csrf: '{{ csrf_token() }}',
                            initialBackups: @js($backups),
                        })"
                    >
                        <header>
                            <x-breadcrumbs :items="[
                                ['label' => __('messages.settings'), 'url' => route('settings.index')],
                                ['label' => __('messages.backup_settings_heading'), 'current' => true],
                            ]" />
                            <h2 class="text-lg font-medium text-gray-900 dark:text-gray-100">
                                {{ __('messages.backup_settings_heading') }}
                            </h2>
                            <p class="mt-1 text-sm text-gray-600 dark:text-gray-400">
                                {{ __('messages.backup_settings_description') }}
                            </p>
                        </header>

                        <div class="mt-6 space-y-6">
                            <div class="flex flex-wrap items-center gap-3">
                                <x-primary-button type="button" x-on:click="createBackup" :disabled="loading">
                                    <span x-text="loading ? '{{ __('messages.backup_creating') }}' : '{{ __('messages.backup_create') }}'"></span>
                                </x-primary-button>

                                <div class="text-sm text-gray-600 dark:text-gray-400">
                                    {{ __('messages.backup_create_hint') }}
                                </div>
                            </div>

                            <div class="rounded-md border border-gray-200 bg-gray-50 p-4 dark:border-gray-700 dark:bg-gray-900">
                                <h3 class="text-sm font-semibold text-gray-900 dark:text-gray-100">
                                    {{ __('messages.backup_restore_heading') }}
                                </h3>
                                <p class="mt-1 text-sm text-gray-600 dark:text-gray-400">
                                    {{ __('messages.backup_restore_description') }}
                                </p>

                                <div class="mt-4 flex flex-wrap items-center gap-3">
                                    <input type="file" x-ref="backupFile" class="text-sm text-gray-600 dark:text-gray-300" />
                                    <x-danger-button type="button" x-on:click="restoreUploaded" :disabled="loading">
                                        {{ __('messages.backup_restore') }}
                                    </x-danger-button>
                                </div>
                            </div>

                            <template x-if="message">
                                <p class="text-sm text-green-600" x-text="message"></p>
                            </template>
                            <template x-if="error">
                                <p class="text-sm text-red-600" x-text="error"></p>
                            </template>

                            <div>
                                <h3 class="text-sm font-semibold text-gray-900 dark:text-gray-100">
                                    {{ __('messages.backup_available_heading') }}
                                </h3>

                                <div class="mt-3 overflow-hidden rounded-lg border border-gray-200 dark:border-gray-700">
                                    <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
                                        <thead class="bg-gray-50 dark:bg-gray-900">
                                            <tr>
                                                <th class="px-4 py-3 text-left text-xs font-semibold uppercase text-gray-500 dark:text-gray-400">
                                                    {{ __('messages.backup_file') }}
                                                </th>
                                                <th class="px-4 py-3 text-left text-xs font-semibold uppercase text-gray-500 dark:text-gray-400">
                                                    {{ __('messages.backup_created_at') }}
                                                </th>
                                                <th class="px-4 py-3 text-left text-xs font-semibold uppercase text-gray-500 dark:text-gray-400">
                                                    {{ __('messages.backup_size') }}
                                                </th>
                                                <th class="px-4 py-3"></th>
                                            </tr>
                                        </thead>
                                        <tbody class="divide-y divide-gray-200 bg-white dark:divide-gray-700 dark:bg-gray-800">
                                            <template x-if="backups.length === 0">
                                                <tr>
                                                    <td colspan="4" class="px-4 py-4 text-sm text-gray-500 dark:text-gray-400">
                                                        {{ __('messages.backup_empty') }}
                                                    </td>
                                                </tr>
                                            </template>
                                            <template x-for="backup in backups" :key="backup.name">
                                                <tr>
                                                    <td class="px-4 py-3 text-sm text-gray-700 dark:text-gray-200" x-text="backup.name"></td>
                                                    <td class="px-4 py-3 text-sm text-gray-600 dark:text-gray-300" x-text="backup.created_at"></td>
                                                    <td class="px-4 py-3 text-sm text-gray-600 dark:text-gray-300" x-text="backup.size_human"></td>
                                                    <td class="px-4 py-3 text-sm text-right">
                                                        <a :href="backup.download_url" class="text-sm font-semibold text-[#4E81FA] hover:underline">
                                                            {{ __('messages.backup_download') }}
                                                        </a>
                                                        <button type="button"
                                                                class="ml-3 text-sm font-semibold text-red-600 hover:underline"
                                                                x-on:click="restoreBackup(backup.name)"
                                                                :disabled="loading">
                                                            {{ __('messages.backup_restore') }}
                                                        </button>
                                                    </td>
                                                </tr>
                                            </template>
                                        </tbody>
                                    </table>
                                </div>
                            </div>
                        </div>
                    </section>
                </div>
            </div>
        </div>
    </div>

    <script>
        function backupManager(config) {
            return {
                backups: (config.initialBackups || []).map(formatBackup(config)),
                loading: false,
                message: '',
                error: '',
                async refreshBackups() {
                    try {
                        const response = await fetch(config.listUrl, {
                            headers: { 'Accept': 'application/json' },
                        });
                        const data = await response.json();
                        this.backups = (data.data || []).map(formatBackup(config));
                    } catch (err) {
                        this.error = '{{ __('messages.backup_list_failed') }}';
                    }
                },
                async createBackup() {
                    this.loading = true;
                    this.message = '';
                    this.error = '';
                    try {
                        const response = await fetch(config.createUrl, {
                            method: 'POST',
                            headers: {
                                'Accept': 'application/json',
                                'X-CSRF-TOKEN': config.csrf,
                            },
                        });
                        const data = await response.json();
                        if (!response.ok) {
                            throw new Error(data.message || 'Failed');
                        }
                        this.message = data.message;
                        await this.refreshBackups();
                    } catch (err) {
                        this.error = err.message || '{{ __('messages.backup_create_failed') }}';
                    } finally {
                        this.loading = false;
                    }
                },
                async restoreBackup(filename) {
                    if (!confirm('{{ __('messages.backup_restore_confirm') }}')) {
                        return;
                    }
                    this.loading = true;
                    this.message = '';
                    this.error = '';
                    try {
                        const form = new FormData();
                        form.append('confirm', '1');
                        form.append('filename', filename);
                        const response = await fetch(config.restoreUrl, {
                            method: 'POST',
                            headers: {
                                'Accept': 'application/json',
                                'X-CSRF-TOKEN': config.csrf,
                            },
                            body: form,
                        });
                        const data = await response.json();
                        if (!response.ok) {
                            throw new Error(data.message || 'Failed');
                        }
                        this.message = data.message;
                    } catch (err) {
                        this.error = err.message || '{{ __('messages.backup_restore_failed') }}';
                    } finally {
                        this.loading = false;
                    }
                },
                async restoreUploaded() {
                    const fileInput = this.$refs.backupFile;
                    if (!fileInput || !fileInput.files.length) {
                        this.error = '{{ __('messages.backup_file_required') }}';
                        return;
                    }
                    if (!confirm('{{ __('messages.backup_restore_confirm') }}')) {
                        return;
                    }
                    this.loading = true;
                    this.message = '';
                    this.error = '';
                    try {
                        const form = new FormData();
                        form.append('confirm', '1');
                        form.append('backup', fileInput.files[0]);
                        const response = await fetch(config.restoreUrl, {
                            method: 'POST',
                            headers: {
                                'Accept': 'application/json',
                                'X-CSRF-TOKEN': config.csrf,
                            },
                            body: form,
                        });
                        const data = await response.json();
                        if (!response.ok) {
                            throw new Error(data.message || 'Failed');
                        }
                        this.message = data.message;
                        fileInput.value = '';
                        await this.refreshBackups();
                    } catch (err) {
                        this.error = err.message || '{{ __('messages.backup_restore_failed') }}';
                    } finally {
                        this.loading = false;
                    }
                },
            };
        }

        function formatBackup(config) {
            const base = config.downloadBase.replace(/placeholder$/, '').replace(/\/$/, '');
            return (backup) => ({
                ...backup,
                size_human: formatBytes(backup.size || 0),
                download_url: `${base}/${backup.name}`,
            });
        }

        function formatBytes(bytes) {
            if (!bytes) return '0 B';
            const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
            const i = Math.floor(Math.log(bytes) / Math.log(1024));
            return `${(bytes / Math.pow(1024, i)).toFixed(1)} ${sizes[i]}`;
        }
    </script>
</x-app-admin-layout>
