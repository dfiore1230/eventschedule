<?php

namespace App\Http\Controllers;

use App\Enums\ReleaseChannel;
use App\Models\MediaAsset;
use App\Models\MediaAssetVariant;
use App\Models\Setting;
use App\Services\ReleaseChannelService;
use App\Rules\AccessibleColor;
use App\Support\BrandingManager;
use App\Support\ColorUtils;
use App\Support\HomePageSettings;
use App\Support\Logging\LogLevelNormalizer;
use App\Support\Logging\LoggingConfigManager;
use App\Support\MailConfigManager;
use App\Support\MailTemplateManager;
use App\Support\MassEmailConfigManager;
use App\Support\ReleaseChannelManager;
use App\Support\UpdateConfigManager;
use App\Support\UrlUtilsConfigManager;
use App\Support\WalletConfigManager;
use App\Services\Email\Providers\LaravelMailProvider;
use App\Services\Email\Providers\MailchimpProvider;
use App\Services\Email\Providers\MailgunProvider;
use App\Services\Email\Providers\SendGridProvider;
use App\Services\Audit\AuditLogger;
use App\Services\BackupService;
use App\Utils\MarkdownUtils;
use Codedge\Updater\UpdaterManager;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\URL;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;
use Illuminate\View\View;
use Throwable;
use App\Mail\TemplatePreview;

class SettingsController extends Controller
{
    public function __construct(private AuditLogger $auditLogger)
    {
    }
    public function index(Request $request): View
    {
        $this->authorizeAdmin($request->user());

        return view('settings.index');
    }

    public function general(Request $request): View
    {
        $this->authorizeAdmin($request->user());

        return view('settings.general', [
            'generalSettings' => $this->getGeneralSettings(),
        ]);
    }

    public function updates(Request $request, UpdaterManager $updater, ReleaseChannelService $releaseChannels): View
    {
        $this->authorizeAdmin($request->user());

        $updateSettings = $this->getUpdateSettings();
        $selectedChannel = ReleaseChannel::fromString($updateSettings['update_release_channel'] ?? null);

        $versionInstalled = config('self-update.version_installed');
        $versionAvailable = null;

        if (! config('app.hosted') && ! config('app.testing')) {
            $installedFromSource = $updater->source()->getVersionInstalled();

            if (is_string($installedFromSource) && $installedFromSource !== '') {
                $versionInstalled = $installedFromSource;
            }

            try {
                if ($request->has('clear_cache')) {
                    $releaseChannels->forgetCached($selectedChannel);
                }

                $versionAvailable = $releaseChannels->getLatestVersion($selectedChannel);
            } catch (Throwable $e) {
                $versionAvailable = 'Error: failed to check version';
            }
        }

        return view('settings.updates', [
            'updateSettings' => $updateSettings,
            'availableUpdateChannels' => ReleaseChannel::options(),
            'versionInstalled' => $versionInstalled,
            'versionAvailable' => $versionAvailable,
            'selectedUpdateChannel' => $selectedChannel->value,
        ]);
    }

    public function logging(Request $request): View
    {
        $this->authorizeAdmin($request->user());

        return view('settings.logging', [
            'loggingSettings' => $this->getLoggingSettings(),
            'availableLogLevels' => LoggingConfigManager::availableLevels(),
        ]);
    }

    public function branding(Request $request): View
    {
        $this->authorizeAdmin($request->user());

        return view('settings.branding', [
            'brandingSettings' => $this->getBrandingSettings(),
            'languageOptions' => $this->getSupportedLanguageOptions(),
            'colorPalettes' => $this->getBrandingPalettes(),
        ]);
    }

    public function home(Request $request): View
    {
        $this->authorizeAdmin($request->user());

        $homeSettings = Setting::forGroup('home');

        $heroPreview = HomePageSettings::resolveImagePreview(
            isset($homeSettings['hero_image_media_asset_id']) ? (int) $homeSettings['hero_image_media_asset_id'] : null,
            isset($homeSettings['hero_image_media_variant_id']) ? (int) $homeSettings['hero_image_media_variant_id'] : null,
        );

        $imagePreview = HomePageSettings::resolveImagePreview(
            isset($homeSettings['aside_image_media_asset_id']) ? (int) $homeSettings['aside_image_media_asset_id'] : null,
            isset($homeSettings['aside_image_media_variant_id']) ? (int) $homeSettings['aside_image_media_variant_id'] : null,
        );

        return view('settings.home', [
            'homeSettings' => $homeSettings,
            'layoutOptions' => $this->homeLayoutOptions(),
            'initialHeroImage' => $heroPreview,
            'initialAsideImage' => $imagePreview,
        ]);
    }

    public function terms(Request $request): View
    {
        $this->authorizeAdmin($request->user());

        return view('settings.terms', [
            'termsSettings' => $this->getTermsSettings(),
        ]);
    }

    public function privacy(Request $request): View
    {
        $this->authorizeAdmin($request->user());

        return view('settings.privacy', [
            'privacySettings' => $this->getPrivacySettings(),
        ]);
    }

    public function integrations(Request $request): View
    {
        $this->authorizeAdmin($request->user());

        return view('settings.integrations', [
            'user' => $request->user(),
        ]);
    }

    public function wallet(Request $request): View
    {
        $this->authorizeAdmin($request->user());

        $appleStored = Setting::forGroup('wallet.apple');
        $googleStored = Setting::forGroup('wallet.google');

        return view('settings.wallet', [
            'appleSettings' => $this->buildAppleWalletFormValues($appleStored),
            'appleFiles' => [
                'certificate' => $this->buildFileInfo(
                    $appleStored['certificate_path'] ?? null,
                    config('wallet.apple.certificate_path')
                ),
                'wwdr' => $this->buildFileInfo(
                    $appleStored['wwdr_certificate_path'] ?? null,
                    config('wallet.apple.wwdr_certificate_path')
                ),
            ],
            'applePasswordStored' => array_key_exists('certificate_password', $appleStored)
                && $appleStored['certificate_password'] !== null,
            'googleSettings' => $this->buildGoogleWalletFormValues($googleStored),
            'googleFiles' => [
                'service_account' => $this->buildFileInfo(
                    $googleStored['service_account_json_path'] ?? null,
                    config('wallet.google.service_account_json_path')
                ),
            ],
            'googleInlineStatus' => [
                'stored' => !empty($googleStored['service_account_json']),
                'configured' => empty($googleStored['service_account_json'])
                    && !empty(config('wallet.google.service_account_json')),
            ],
        ]);
    }

    public function email(Request $request, MailTemplateManager $mailTemplates): View
    {
        $this->authorizeAdmin($request->user());

        $mailSettings = $this->getMailSettings();
        $massEmailSettings = $this->getMassEmailSettings();

        return view('settings.email', [
            'mailSettings' => $mailSettings,
            'massEmailSettings' => $massEmailSettings,
            'availableMailers' => [
                'smtp' => 'SMTP',
                'log' => 'Log',
            ],
            'availableEmailProviders' => [
                'laravel_mail' => 'SMTP (Laravel mailer)',
                'sendgrid' => 'SendGrid',
                'mailgun' => 'Mailgun',
                'mailchimp' => 'Mailchimp Transactional',
            ],
            'availableEncryptions' => [
                '' => __('messages.none'),
                'tls' => 'TLS',
                'ssl' => 'SSL',
            ],
            'mailTemplates' => $mailTemplates->all(),
        ]);
    }

    public function emailTemplates(Request $request, MailTemplateManager $mailTemplates): View
    {
        $this->authorizeAdmin($request->user());

        return redirect()->route('settings.email');
    }

    public function showEmailTemplate(Request $request, MailTemplateManager $mailTemplates, string $template): View
    {
        $this->authorizeAdmin($request->user());

        if (! $mailTemplates->exists($template)) {
            abort(404);
        }

        return view('settings.email-templates.show', [
            'template' => $mailTemplates->get($template),
        ]);
    }

    public function updateAppleWallet(Request $request): RedirectResponse
    {
        $this->authorizeAdmin($request->user());

        $stored = Setting::forGroup('wallet.apple');

        $request->validate([
            'apple_enabled' => ['required', 'boolean'],
            'apple_pass_type_identifier' => ['nullable', 'string', 'max:255'],
            'apple_team_identifier' => ['nullable', 'string', 'max:255'],
            'apple_organization_name' => ['nullable', 'string', 'max:255'],
            'apple_background_color' => ['nullable', 'string', 'max:50'],
            'apple_foreground_color' => ['nullable', 'string', 'max:50'],
            'apple_label_color' => ['nullable', 'string', 'max:50'],
            'apple_certificate' => ['nullable', 'file', 'max:10240'],
            'apple_certificate_password' => ['nullable', 'string', 'max:255'],
            'apple_clear_certificate_password' => ['nullable', 'boolean'],
            'apple_remove_certificate' => ['nullable', 'boolean'],
            'apple_wwdr_certificate' => ['nullable', 'file', 'max:10240'],
            'apple_remove_wwdr_certificate' => ['nullable', 'boolean'],
        ]);

        $certificatePath = $stored['certificate_path'] ?? null;

        if ($request->boolean('apple_remove_certificate')) {
            $this->deleteStoredFile($certificatePath);
            $certificatePath = null;
        }

        if ($request->file('apple_certificate')) {
            $certificatePath = $this->storeUploadedFile($request->file('apple_certificate'), 'wallet/apple', $certificatePath);
        }

        $wwdrPath = $stored['wwdr_certificate_path'] ?? null;

        if ($request->boolean('apple_remove_wwdr_certificate')) {
            $this->deleteStoredFile($wwdrPath);
            $wwdrPath = null;
        }

        if ($request->file('apple_wwdr_certificate')) {
            $wwdrPath = $this->storeUploadedFile($request->file('apple_wwdr_certificate'), 'wallet/apple', $wwdrPath);
        }

        $certificatePassword = $stored['certificate_password'] ?? null;

        if ($request->filled('apple_certificate_password')) {
            $certificatePassword = trim((string) $request->input('apple_certificate_password'));
        } elseif ($request->boolean('apple_clear_certificate_password')) {
            $certificatePassword = null;
        }

        if ($request->boolean('apple_enabled')) {
            $hasCertificate = !empty($certificatePath)
                || $request->hasFile('apple_certificate')
                || !empty(env('APPLE_WALLET_CERTIFICATE_PATH'));

            $hasWwdrCertificate = !empty($wwdrPath)
                || $request->hasFile('apple_wwdr_certificate')
                || !empty(env('APPLE_WALLET_WWDR_CERTIFICATE_PATH'));

            if (! $hasCertificate) {
                throw ValidationException::withMessages([
                    'apple_certificate' => __('messages.apple_wallet_certificate_required'),
                ]);
            }

            if (! $hasWwdrCertificate) {
                throw ValidationException::withMessages([
                    'apple_wwdr_certificate' => __('messages.apple_wallet_wwdr_certificate_required'),
                ]);
            }
        }

        $appleSettings = [
            'enabled' => $request->boolean('apple_enabled'),
            'pass_type_identifier' => $this->nullableTrim($request->input('apple_pass_type_identifier')),
            'team_identifier' => $this->nullableTrim($request->input('apple_team_identifier')),
            'organization_name' => $this->nullableTrim($request->input('apple_organization_name')),
            'background_color' => $this->nullableTrim($request->input('apple_background_color')),
            'foreground_color' => $this->nullableTrim($request->input('apple_foreground_color')),
            'label_color' => $this->nullableTrim($request->input('apple_label_color')),
            'certificate_path' => $certificatePath,
            'certificate_password' => $certificatePassword,
            'wwdr_certificate_path' => $wwdrPath,
        ];

        Setting::setGroup('wallet.apple', $appleSettings);

        WalletConfigManager::applyApple($appleSettings);

        $this->auditSettingsChange($request, 'settings.wallet.apple.update', [
            'enabled' => $appleSettings['enabled'],
            'has_certificate' => (bool) $appleSettings['certificate_path'],
            'has_wwdr_certificate' => (bool) $appleSettings['wwdr_certificate_path'],
        ]);

        return redirect()->route('settings.wallet')->with('status', 'apple-wallet-settings-updated');
    }

    public function updateGoogleWallet(Request $request): RedirectResponse
    {
        $this->authorizeAdmin($request->user());

        $stored = Setting::forGroup('wallet.google');

        $request->validate([
            'google_enabled' => ['required', 'boolean'],
            'google_issuer_id' => ['nullable', 'string', 'max:255'],
            'google_issuer_name' => ['nullable', 'string', 'max:255'],
            'google_class_suffix' => ['nullable', 'string', 'max:255'],
            'google_service_account_file' => ['nullable', 'file', 'max:10240'],
            'google_remove_service_account_file' => ['nullable', 'boolean'],
            'google_service_account_json' => ['nullable', 'string'],
            'google_clear_service_account_json' => ['nullable', 'boolean'],
        ]);

        $serviceAccountPath = $stored['service_account_json_path'] ?? null;

        if ($request->boolean('google_remove_service_account_file')) {
            $this->deleteStoredFile($serviceAccountPath);
            $serviceAccountPath = null;
        }

        if ($request->file('google_service_account_file')) {
            $serviceAccountPath = $this->storeUploadedFile(
                $request->file('google_service_account_file'),
                'wallet/google',
                $serviceAccountPath
            );
        }

        $serviceAccountJson = $stored['service_account_json'] ?? null;

        if ($request->filled('google_service_account_json')) {
            $serviceAccountJson = $this->nullableTrim($request->input('google_service_account_json'));
        } elseif ($request->boolean('google_clear_service_account_json')) {
            $serviceAccountJson = null;
        }

        $googleSettings = [
            'enabled' => $request->boolean('google_enabled'),
            'issuer_id' => $this->nullableTrim($request->input('google_issuer_id')),
            'issuer_name' => $this->nullableTrim($request->input('google_issuer_name')),
            'class_suffix' => $this->nullableTrim($request->input('google_class_suffix')),
            'service_account_json_path' => $serviceAccountPath,
            'service_account_json' => $serviceAccountJson,
        ];

        $finalIssuerId = $googleSettings['issuer_id']
            ?? $stored['issuer_id']
            ?? config('wallet.google.issuer_id');

        if ($request->boolean('google_enabled')) {
            if (empty($finalIssuerId)) {
                throw ValidationException::withMessages([
                    'google_issuer_id' => __('messages.google_wallet_issuer_id_required'),
                ]);
            }

            $hasCredentials = !empty($serviceAccountPath)
                || $request->hasFile('google_service_account_file')
                || !empty($serviceAccountJson)
                || !empty(env('GOOGLE_WALLET_SERVICE_ACCOUNT_JSON_PATH'))
                || !empty(env('GOOGLE_WALLET_SERVICE_ACCOUNT_JSON'));

            if (! $hasCredentials) {
                throw ValidationException::withMessages([
                    'google_service_account_file' => __('messages.google_wallet_credentials_required'),
                ]);
            }
        }

        Setting::setGroup('wallet.google', $googleSettings);

        WalletConfigManager::applyGoogle($googleSettings);

        $this->auditSettingsChange($request, 'settings.wallet.google.update', [
            'enabled' => $googleSettings['enabled'],
            'has_service_account_file' => (bool) $googleSettings['service_account_json_path'],
            'has_inline_credentials' => ! empty($googleSettings['service_account_json']),
        ]);

        return redirect()->route('settings.wallet')->with('status', 'google-wallet-settings-updated');
    }

    public function updateMail(Request $request): RedirectResponse
    {
        $this->authorizeAdmin($request->user());

        $validated = $this->validateMailSettings($request);
        $massEmailValidated = $this->validateMassEmailSettings($request);

        $mailSettings = $this->buildMailSettings($request, $validated);
        $massEmailSettings = $this->buildMassEmailSettings($request, $massEmailValidated);

        Setting::setGroup('mail', $mailSettings);
        Setting::setGroup('mass_email', $massEmailSettings);

        $this->applyMailConfig($mailSettings);

        $this->auditSettingsChange($request, 'settings.mail.update', [
            'mailer' => $mailSettings['mailer'] ?? config('mail.default'),
        ]);

        return redirect()->route('settings.email')->with('status', 'mail-settings-updated');
    }

    public function testMail(Request $request): JsonResponse
    {
        $this->authorizeAdmin($request->user());

        $user = $request->user();

        if (!$user || empty($user->email)) {
            return response()->json([
                'status' => 'error',
                'message' => __('messages.test_email_failed'),
                'error' => __('messages.test_email_missing_user'),
                'logs' => [
                    'No authenticated user email address was available for the test message.',
                ],
            ], 422);
        }

        $validated = $this->validateMailSettings($request);

        $originalSettings = $this->getMailSettings();
        $testMailSettings = $this->buildMailSettings($request, $validated);

        $this->applyMailConfig($testMailSettings, force: true);

        $logOutput = [];
        $logOutput[] = 'Test email started at ' . now()->toDateTimeString();
        $logOutput[] = 'Resolved mailer: ' . ($testMailSettings['mailer'] ?? config('mail.default'));
        $logOutput[] = 'Target host: ' . ($testMailSettings['host'] ?: '(not configured)');
        $logOutput[] = 'Target port: ' . ($testMailSettings['port'] ?: '(not configured)');
        $logOutput[] = 'Encryption: ' . ($testMailSettings['encryption'] ?: '(none)');
        $logOutput[] = 'Authentication username ' . ($testMailSettings['username'] ? 'provided' : 'not provided');
        $logOutput[] = 'From address: ' . $testMailSettings['from_address'];
        $logOutput[] = 'From name: ' . $testMailSettings['from_name'];
        $logOutput[] = 'Attempting to send test message to: ' . $user->email;

        try {
            Mail::raw(__('messages.test_email_body'), function ($message) use ($user) {
                $message->to($user->email)->subject(__('messages.test_email_subject'));
            });

            $inspection = $this->inspectMailerFailures();
            $failures = $inspection['failures'];

            if (! empty($inspection['note'])) {
                $logOutput[] = $inspection['note'];
            }

            if ($inspection['inspected'] && empty($failures)) {
                $logOutput[] = 'Mail driver did not report any delivery failures.';
            }

            if (empty($failures)) {
                return response()->json([
                    'status' => 'success',
                    'message' => __('messages.test_email_sent'),
                    'logs' => $logOutput,
                ]);
            }

            $logOutput[] = 'Mail driver reported failures for the following recipients:';

            foreach ($failures as $failure) {
                $logOutput[] = ' - ' . $failure;
            }

            return response()->json([
                'status' => 'error',
                'message' => __('messages.test_email_failed'),
                'error' => __('messages.test_email_failures'),
                'failures' => $failures,
                'logs' => $logOutput,
            ], 500);
        } catch (Throwable $exception) {
            report($exception);

            $logOutput[] = 'Encountered exception while sending the test email: ' . $exception->getMessage();
            $logOutput[] = 'Exception class: ' . get_class($exception);
            $logOutput[] = 'Stack trace:';

            foreach (explode(PHP_EOL, $exception->getTraceAsString()) as $traceLine) {
                if ($traceLine !== '') {
                    $logOutput[] = $traceLine;
                }
            }

            return response()->json([
                'status' => 'error',
                'message' => __('messages.test_email_failed'),
                'error' => $exception->getMessage(),
                'logs' => $logOutput,
            ], 500);
        } finally {
            $this->applyMailConfig($originalSettings);
            MailConfigManager::purgeResolvedMailer($originalSettings['mailer'] ?? null);
        }
    }

    public function testMassEmailProvider(Request $request): JsonResponse
    {
        $this->authorizeAdmin($request->user());

        $validated = $this->validateMassEmailSettings($request);
        $massEmailSettings = $this->buildMassEmailSettings($request, $validated);

        MassEmailConfigManager::apply($massEmailSettings);

        $providerKey = $massEmailSettings['provider'] ?? config('mass_email.provider', 'laravel_mail');
        $provider = $this->resolveMassEmailProvider($providerKey);
        $logs = ['Provider: ' . $providerKey];
        $validationMode = (string) $request->input('mass_email_validation_mode', 'online');

        $fromEmail = $massEmailSettings['from_email'] ?? '';
        if (! $provider->validateFromAddress($fromEmail)) {
            return response()->json([
                'status' => 'error',
                'message' => 'Provider validation failed.',
                'error' => 'From email address or provider credentials are invalid.',
                'logs' => $logs,
            ], 422);
        }

        if ($validationMode === 'offline') {
            $offlineResult = $this->offlineProviderValidation($providerKey, $massEmailSettings, $logs);

            return response()->json($offlineResult['payload'], $offlineResult['status']);
        }

        try {
            if ($providerKey === 'sendgrid') {
                $apiKey = (string) ($massEmailSettings['api_key'] ?? '');
                if ($apiKey === '') {
                    return response()->json([
                        'status' => 'error',
                        'message' => 'SendGrid API key is required.',
                        'error' => 'Missing API key.',
                        'logs' => $logs,
                    ], 422);
                }

                $response = Http::withToken($apiKey)->acceptJson()->get('https://api.sendgrid.com/v3/scopes');
                $logs[] = 'SendGrid scopes status: ' . $response->status();

                if (! $response->successful()) {
                    return $this->handleProviderTestResponse($response, $logs, 'SendGrid settings are valid.');
                }

                $verifiedResponse = Http::withToken($apiKey)->acceptJson()->get('https://api.sendgrid.com/v3/verified_senders');
                $logs[] = 'SendGrid verified sender status: ' . $verifiedResponse->status();

                if (! $verifiedResponse->successful()) {
                    return $this->handleProviderTestResponse($verifiedResponse, $logs, 'SendGrid settings are valid.');
                }

                $verifiedSenders = $verifiedResponse->json('results') ?? [];
                $matched = collect($verifiedSenders)->contains(function ($sender) use ($fromEmail) {
                    return isset($sender['from_email']) && strtolower((string) $sender['from_email']) === strtolower($fromEmail);
                });

                if (! $matched) {
                    return response()->json([
                        'status' => 'error',
                        'message' => 'SendGrid sender identity not verified.',
                        'error' => 'The from address is not in the verified sender list.',
                        'logs' => $logs,
                    ], 422);
                }

                if (! empty($massEmailSettings['webhook_public_key']) && ! function_exists('sodium_crypto_sign_verify_detached')) {
                    $logs[] = 'libsodium not available; SendGrid webhook signatures will not be verified.';
                }

                return response()->json([
                    'status' => 'success',
                    'message' => 'SendGrid settings are valid.',
                    'logs' => $logs,
                ]);
            }

            if ($providerKey === 'mailgun') {
                $apiKey = (string) ($massEmailSettings['api_key'] ?? '');
                $domain = (string) ($massEmailSettings['sending_domain'] ?? '');

                if ($apiKey === '' || $domain === '') {
                    return response()->json([
                        'status' => 'error',
                        'message' => 'Mailgun API key and domain are required.',
                        'error' => 'Missing API key or sending domain.',
                        'logs' => $logs,
                    ], 422);
                }

                $response = Http::withBasicAuth('api', $apiKey)->acceptJson()->get('https://api.mailgun.net/v3/domains/' . $domain);
                $logs[] = 'Mailgun domain status: ' . $response->status();

                if (! $response->successful()) {
                    return $this->handleProviderTestResponse($response, $logs, 'Mailgun settings are valid.');
                }

                $state = $response->json('domain.state');
                if ($state !== 'active') {
                    return response()->json([
                        'status' => 'error',
                        'message' => 'Mailgun domain is not active.',
                        'error' => $state ? 'Domain state is ' . $state . '.' : 'Domain state was not returned.',
                        'logs' => $logs,
                    ], 422);
                }

                return response()->json([
                    'status' => 'success',
                    'message' => 'Mailgun settings are valid.',
                    'logs' => $logs,
                ]);
            }

            if ($providerKey === 'mailchimp') {
                $apiKey = (string) ($massEmailSettings['api_key'] ?? '');

                if ($apiKey === '') {
                    return response()->json([
                        'status' => 'error',
                        'message' => 'Mailchimp Transactional API key is required.',
                        'error' => 'Missing API key.',
                        'logs' => $logs,
                    ], 422);
                }

                $response = Http::acceptJson()->post('https://mandrillapp.com/api/1.0/users/ping.json', [
                    'key' => $apiKey,
                ]);

                $logs[] = 'Mailchimp ping status: ' . $response->status();
                $body = trim((string) $response->body());

                if ($response->successful() && stripos($body, 'pong') !== false) {
                    $sendersResponse = Http::acceptJson()->post('https://mandrillapp.com/api/1.0/senders/list.json', [
                        'key' => $apiKey,
                    ]);
                    $logs[] = 'Mailchimp senders status: ' . $sendersResponse->status();

                    if (! $sendersResponse->successful()) {
                        return $this->handleProviderTestResponse($sendersResponse, $logs, 'Mailchimp settings are valid.');
                    }

                    $senders = $sendersResponse->json() ?? [];
                    $fromDomain = strtolower((string) strrchr($fromEmail, '@'));
                    $matched = collect($senders)->contains(function ($sender) use ($fromEmail, $fromDomain) {
                        $email = strtolower((string) ($sender['email'] ?? ''));
                        $domain = strtolower((string) ($sender['domain'] ?? ''));
                        $status = strtolower((string) ($sender['status'] ?? ''));

                        return $status === 'verified'
                            && ($email === strtolower($fromEmail) || $domain === ltrim($fromDomain, '@'));
                    });

                    if (! $matched) {
                        return response()->json([
                            'status' => 'error',
                            'message' => 'Mailchimp sender identity not verified.',
                            'error' => 'The from address is not verified in Mailchimp Transactional.',
                            'logs' => $logs,
                        ], 422);
                    }

                    return response()->json([
                        'status' => 'success',
                        'message' => 'Mailchimp settings are valid.',
                        'logs' => $logs,
                    ]);
                }

                return response()->json([
                    'status' => 'error',
                    'message' => 'Mailchimp validation failed.',
                    'error' => $body !== '' ? $body : 'Unexpected response from Mailchimp.',
                    'logs' => $logs,
                ], 422);
            }

            if ($providerKey === 'laravel_mail') {
                return response()->json([
                    'status' => 'success',
                    'message' => 'SMTP provider is configured.',
                    'logs' => $logs,
                ]);
            }

            return response()->json([
                'status' => 'error',
                'message' => 'Unsupported provider.',
                'error' => 'Provider is not recognized.',
                'logs' => $logs,
            ], 422);
        } catch (\Throwable $e) {
            return response()->json([
                'status' => 'error',
                'message' => 'Provider validation failed.',
                'error' => $e->getMessage(),
                'logs' => $logs,
            ], 422);
        }
    }

    protected function offlineProviderValidation(string $providerKey, array $settings, array $logs): array
    {
        $logs[] = 'Validation mode: offline (no network calls)';
        $status = 200;
        $payload = [
            'status' => 'success',
            'message' => 'Offline validation succeeded.',
            'logs' => $logs,
        ];

        if ($providerKey === 'sendgrid' && empty($settings['api_key'])) {
            $status = 422;
            $payload = [
                'status' => 'error',
                'message' => 'SendGrid API key is required.',
                'error' => 'Missing API key.',
                'logs' => $logs,
            ];
        }

        if ($providerKey === 'mailgun' && (empty($settings['api_key']) || empty($settings['sending_domain']))) {
            $status = 422;
            $payload = [
                'status' => 'error',
                'message' => 'Mailgun API key and domain are required.',
                'error' => 'Missing API key or sending domain.',
                'logs' => $logs,
            ];
        }

        if ($providerKey === 'mailchimp' && empty($settings['api_key'])) {
            $status = 422;
            $payload = [
                'status' => 'error',
                'message' => 'Mailchimp Transactional API key is required.',
                'error' => 'Missing API key.',
                'logs' => $logs,
            ];
        }

        return [
            'status' => $status,
            'payload' => $payload,
        ];
    }

    protected function handleProviderTestResponse(\Illuminate\Http\Client\Response $response, array $logs, string $successMessage): JsonResponse
    {
        if ($response->successful()) {
            return response()->json([
                'status' => 'success',
                'message' => $successMessage,
                'logs' => $logs,
            ]);
        }

        return response()->json([
            'status' => 'error',
            'message' => 'Provider validation failed.',
            'error' => $response->body() ?: 'Unexpected response from provider.',
            'logs' => $logs,
        ], 422);
    }

    protected function resolveMassEmailProvider(string $providerKey)
    {
        return match ($providerKey) {
            'sendgrid' => new SendGridProvider(),
            'mailgun' => new MailgunProvider(),
            'mailchimp' => new MailchimpProvider(),
            default => new LaravelMailProvider(),
        };
    }

    public function updateGeneral(Request $request): RedirectResponse
    {
        $this->authorizeAdmin($request->user());

        $validated = $request->validate([
            'public_url' => ['required', 'string', 'max:255', 'url'],
        ]);

        $publicUrl = $this->sanitizeUrl($validated['public_url']);

        Setting::setGroup('general', [
            'public_url' => $publicUrl,
        ]);

        $this->applyGeneralConfig($publicUrl);

        $this->auditSettingsChange($request, 'settings.general.update', [
            'keys' => ['public_url'],
        ]);

        return redirect()->route('settings.general')->with('status', 'general-settings-updated');
    }

    public function updateUpdates(Request $request, ReleaseChannelService $releaseChannels): RedirectResponse
    {
        $this->authorizeAdmin($request->user());

        $storedGeneralSettings = Setting::forGroup('general');
        $previousChannel = ReleaseChannel::fromString($storedGeneralSettings['update_release_channel'] ?? null);

        $validated = $request->validate([
            'update_repository_url' => ['nullable', 'string', 'max:255', 'url'],
            'update_release_channel' => ['required', 'string', Rule::in(ReleaseChannel::values())],
            'url_utils_verify_ssl' => ['nullable', 'boolean'],
        ]);

        $updateRepositoryUrl = $this->nullableTrim($validated['update_repository_url'] ?? null);

        if ($updateRepositoryUrl !== null) {
            $updateRepositoryUrl = $this->sanitizeUrl($updateRepositoryUrl);
        }

        $previousRepositoryUrl = $storedGeneralSettings['update_repository_url'] ?? null;
        $normalizedPreviousRepositoryUrl = $this->normalizeRepositoryUrl($previousRepositoryUrl);
        $normalizedNewRepositoryUrl = $this->normalizeRepositoryUrl($updateRepositoryUrl);

        $channel = ReleaseChannel::fromString($validated['update_release_channel'] ?? null);

        Setting::setGroup('general', [
            'update_repository_url' => $updateRepositoryUrl,
            'update_release_channel' => $channel->value,
            'url_utils_verify_ssl' => $request->boolean('url_utils_verify_ssl') ? '1' : '0',
        ]);

        if ($normalizedPreviousRepositoryUrl !== $normalizedNewRepositoryUrl || $previousChannel !== $channel) {
            $releaseChannels->forgetAll();
        }

        UpdateConfigManager::apply($updateRepositoryUrl);
        ReleaseChannelManager::apply($channel);
        UrlUtilsConfigManager::apply($request->boolean('url_utils_verify_ssl'));

        $this->auditSettingsChange($request, 'settings.updates.update', [
            'channel' => $channel->value,
            'url_utils_verify_ssl' => $request->boolean('url_utils_verify_ssl'),
        ]);

        return redirect()->route('settings.updates')->with('status', 'update-settings-updated');
    }

    public function updateLogging(Request $request): RedirectResponse
    {
        $this->authorizeAdmin($request->user());

        $logLevelKeys = array_keys(LoggingConfigManager::availableLevels());

        $validated = $request->validate([
            'log_syslog_host' => ['required', 'string', 'max:255'],
            'log_syslog_port' => ['required', 'integer', 'min:1', 'max:65535'],
            'log_level' => ['required', 'string', Rule::in($logLevelKeys)],
            'log_disabled' => ['nullable', 'boolean'],
        ]);

        $syslogHost = $this->sanitizeHost($validated['log_syslog_host']);
        $syslogPort = (int) $validated['log_syslog_port'];
        $logLevel = LogLevelNormalizer::normalize(
            $validated['log_level'],
            config('logging.channels.single.level', 'debug')
        );

        $loggingSettings = [
            'syslog_host' => $syslogHost,
            'syslog_port' => (string) $syslogPort,
            'level' => $logLevel,
            'disabled' => $request->boolean('log_disabled') ? '1' : '0',
        ];

        Setting::setGroup('logging', $loggingSettings);

        $this->auditSettingsChange($request, 'settings.logging.update', [
            'level' => $logLevel,
            'syslog_host' => $syslogHost,
            'syslog_port' => $syslogPort,
            'disabled' => $request->boolean('log_disabled'),
        ]);

        LoggingConfigManager::apply($loggingSettings);

        return redirect()->route('settings.logging')->with('status', 'logging-settings-updated');
    }

    public function updateBranding(Request $request): RedirectResponse
    {
        $this->authorizeAdmin($request->user());

        $storedBrandingSettings = Setting::forGroup('branding');

        if ($request->boolean('reset_branding')) {
            $previousLogoPath = $storedBrandingSettings['logo_path'] ?? null;
            $previousLogoDisk = $storedBrandingSettings['logo_disk'] ?? null;
            $previousMediaAssetId = $storedBrandingSettings['logo_media_asset_id'] ?? null;

            $previousDarkLogoPath = $storedBrandingSettings['logo_dark_path'] ?? null;
            $previousDarkLogoDisk = $storedBrandingSettings['logo_dark_disk'] ?? null;
            $previousDarkMediaAssetId = $storedBrandingSettings['logo_dark_media_asset_id'] ?? null;

            if ($previousLogoPath && empty($previousMediaAssetId)) {
                $this->deleteStoredFile($previousLogoPath, $previousLogoDisk);
            }

            if ($previousDarkLogoPath && empty($previousDarkMediaAssetId)) {
                $this->deleteStoredFile($previousDarkLogoPath, $previousDarkLogoDisk);
            }

            Setting::clearGroup('branding');
            BrandingManager::apply();

            return redirect()->route('settings.branding')->with('status', 'branding-settings-reset');
        }

        $languageOptions = $this->getSupportedLanguageOptions();
        $supportedLanguageCodes = array_keys($languageOptions);

        $buttonTextColors = [];

        foreach (BrandingManager::BUTTON_TEXT_COLOR_CANDIDATES as $candidate) {
            $normalizedCandidate = ColorUtils::normalizeHexColor($candidate);

            if ($normalizedCandidate === null) {
                continue;
            }

            $label = match ($normalizedCandidate) {
                '#FFFFFF' => __('messages.branding_contrast_text_white'),
                '#111827' => __('messages.branding_contrast_text_charcoal'),
                default => $normalizedCandidate,
            };

            $buttonTextColors[$normalizedCandidate] = $label;
        }

        $validated = $request->validate([
            'branding_logo_media_asset_id' => ['nullable', 'integer', 'exists:media_assets,id'],
            'branding_logo_media_variant_id' => ['nullable', 'integer', 'exists:media_asset_variants,id'],
            'branding_logo_dark_media_asset_id' => ['nullable', 'integer', 'exists:media_assets,id'],
            'branding_logo_dark_media_variant_id' => ['nullable', 'integer', 'exists:media_asset_variants,id'],
            'branding_logo_alt' => ['nullable', 'string', 'max:255'],
            'branding_primary_color' => ['required', new AccessibleColor(__('messages.branding_primary_color'), 4.5, $buttonTextColors)],
            'branding_secondary_color' => ['required', new AccessibleColor(__('messages.branding_secondary_color'), 4.5, $buttonTextColors)],
            'branding_tertiary_color' => ['required', new AccessibleColor(__('messages.branding_tertiary_color'), 4.5, $buttonTextColors)],
            'branding_default_language' => ['required', 'string', Rule::in($supportedLanguageCodes)],
        ]);

        $logoAssetId = $request->input('branding_logo_media_asset_id');
        $logoVariantId = $request->input('branding_logo_media_variant_id');
        $logoDarkAssetId = $request->input('branding_logo_dark_media_asset_id');
        $logoDarkVariantId = $request->input('branding_logo_dark_media_variant_id');

        if ($logoVariantId && ! $logoAssetId) {
            throw ValidationException::withMessages([
                'branding_logo_media_variant_id' => __('messages.branding_logo_variant_mismatch'),
            ]);
        }

        if ($logoDarkVariantId && ! $logoDarkAssetId) {
            throw ValidationException::withMessages([
                'branding_logo_dark_media_variant_id' => __('messages.branding_logo_variant_mismatch'),
            ]);
        }

        $resolveLogo = function (?int $assetId, ?int $variantId, string $assetField, string $variantField, string $storedPrefix) use ($request, $storedBrandingSettings) {
            $previousPath = $storedBrandingSettings[$storedPrefix . '_path'] ?? null;
            $previousDisk = $storedBrandingSettings[$storedPrefix . '_disk'] ?? null;
            $previousMediaAssetId = $storedBrandingSettings[$storedPrefix . '_media_asset_id'] ?? null;
            $previousMediaVariantId = $storedBrandingSettings[$storedPrefix . '_media_variant_id'] ?? null;

            $path = $previousPath;
            $disk = $previousDisk;
            $mediaAssetId = $previousMediaAssetId;
            $mediaVariantId = $previousMediaVariantId;

            if ($assetId) {
                $asset = MediaAsset::find((int) $assetId);

                if (! $asset) {
                    throw ValidationException::withMessages([
                        $assetField => __('messages.branding_logo_missing'),
                    ]);
                }

                if ($previousPath && empty($previousMediaAssetId)) {
                    $this->deleteStoredFile($previousPath, $previousDisk);
                }

                $mediaAssetId = $asset->id;
                $mediaVariantId = null;
                $path = $asset->path;
                $disk = $asset->disk ?: storage_public_disk();

                if ($variantId) {
                    $variant = MediaAssetVariant::where('media_asset_id', $asset->id)
                        ->find((int) $variantId);

                    if (! $variant) {
                        throw ValidationException::withMessages([
                            $variantField => __('messages.branding_logo_variant_mismatch'),
                        ]);
                    }

                    $mediaVariantId = $variant->id;
                    $path = $variant->path;
                    $disk = $variant->disk ?: $disk;
                }
            } elseif ($request->exists($assetField)) {
                if ($previousPath && empty($previousMediaAssetId)) {
                    $this->deleteStoredFile($previousPath, $previousDisk);
                }

                $path = null;
                $disk = null;
                $mediaAssetId = null;
                $mediaVariantId = null;
            }

            return [$path, $disk, $mediaAssetId, $mediaVariantId];
        };

        [$logoPath, $logoDisk, $logoMediaAssetId, $logoMediaVariantId] = $resolveLogo(
            $logoAssetId,
            $logoVariantId,
            'branding_logo_media_asset_id',
            'branding_logo_media_variant_id',
            'logo'
        );

        [$logoDarkPath, $logoDarkDisk, $logoDarkMediaAssetId, $logoDarkMediaVariantId] = $resolveLogo(
            $logoDarkAssetId,
            $logoDarkVariantId,
            'branding_logo_dark_media_asset_id',
            'branding_logo_dark_media_variant_id',
            'logo_dark'
        );

        $logoAlt = $this->nullableTrim($validated['branding_logo_alt'] ?? null);
        $primaryColor = ColorUtils::normalizeHexColor($validated['branding_primary_color']) ?? '#1F2937';
        $secondaryColor = ColorUtils::normalizeHexColor($validated['branding_secondary_color']) ?? '#111827';
        $tertiaryColor = ColorUtils::normalizeHexColor($validated['branding_tertiary_color']) ?? '#374151';

        $defaultLanguage = $validated['branding_default_language'] ?? config('app.fallback_locale', 'en');

        if (! is_valid_language_code($defaultLanguage)) {
            $defaultLanguage = config('app.fallback_locale', 'en');
        }

        $brandingSettings = [
            // Legacy keys (kept for backward compatibility)
            'logo_path' => $logoPath,
            'logo_disk' => $logoPath ? ($logoDisk ?: storage_public_disk()) : null,
            'logo_media_asset_id' => $logoMediaAssetId ? (int) $logoMediaAssetId : null,
            'logo_media_variant_id' => $logoMediaVariantId ? (int) $logoMediaVariantId : null,

            // Explicit light/dark variants
            'logo_light_path' => $logoPath,
            'logo_light_disk' => $logoPath ? ($logoDisk ?: storage_public_disk()) : null,
            'logo_light_media_asset_id' => $logoMediaAssetId ? (int) $logoMediaAssetId : null,
            'logo_light_media_variant_id' => $logoMediaVariantId ? (int) $logoMediaVariantId : null,

            'logo_dark_path' => $logoDarkPath,
            'logo_dark_disk' => $logoDarkPath ? ($logoDarkDisk ?: storage_public_disk()) : null,
            'logo_dark_media_asset_id' => $logoDarkMediaAssetId ? (int) $logoDarkMediaAssetId : null,
            'logo_dark_media_variant_id' => $logoDarkMediaVariantId ? (int) $logoDarkMediaVariantId : null,

            'logo_alt' => $logoAlt,
            'primary_color' => $primaryColor,
            'secondary_color' => $secondaryColor,
            'tertiary_color' => $tertiaryColor,
            'default_language' => $defaultLanguage,
        ];

        Setting::setGroup('branding', $brandingSettings);
        BrandingManager::apply($brandingSettings);

        $this->auditSettingsChange($request, 'settings.branding.update', [
            'keys' => array_keys($brandingSettings),
        ]);

        return redirect()->route('settings.branding')->with('status', 'branding-settings-updated');
    }

    public function updateHome(Request $request): RedirectResponse
    {
        $this->authorizeAdmin($request->user());

        $validated = $request->validate([
            'home_layout' => ['required', 'string', Rule::in(HomePageSettings::allowedLayouts())],
            'home_hero_alignment' => ['nullable', 'string', Rule::in(HomePageSettings::allowedHeroAlignments())],
            'home_hero_title' => ['nullable', 'string', 'max:150'],
            'home_hero_markdown' => ['nullable', 'string', 'max:65000'],
            'home_hero_cta_label' => ['nullable', 'string', 'max:100', 'required_with:home_hero_cta_url'],
            'home_hero_cta_url' => ['nullable', 'string', 'max:500', 'required_with:home_hero_cta_label'],
            'home_hero_media_asset_id' => ['nullable', 'integer', 'exists:media_assets,id'],
            'home_hero_media_variant_id' => ['nullable', 'integer', 'exists:media_asset_variants,id'],
            'home_hero_image_alt' => ['nullable', 'string', 'max:255'],
            'home_hero_show_default_text' => ['nullable', 'boolean'],
            'home_aside_title' => ['nullable', 'string', 'max:150'],
            'home_aside_markdown' => ['nullable', 'string', 'max:65000'],
            'home_aside_media_asset_id' => ['nullable', 'integer', 'exists:media_assets,id'],
            'home_aside_media_variant_id' => ['nullable', 'integer', 'exists:media_asset_variants,id'],
            'home_aside_image_alt' => ['nullable', 'string', 'max:255'],
        ]);

        $layout = HomePageSettings::normalizeLayout($validated['home_layout'] ?? null);
        $heroAlignment = HomePageSettings::normalizeHeroAlignment($validated['home_hero_alignment'] ?? null);

        $heroTitle = HomePageSettings::clean($validated['home_hero_title'] ?? null);
        $heroMarkdown = HomePageSettings::clean($validated['home_hero_markdown'] ?? null);
        $heroHtml = $heroMarkdown ? MarkdownUtils::convertToHtml($heroMarkdown) : null;
        $showDefaultHeroText = HomePageSettings::normalizeBoolean($validated['home_hero_show_default_text'] ?? null, true);

        $heroCtaLabel = HomePageSettings::clean($validated['home_hero_cta_label'] ?? null);
        $heroCtaUrl = HomePageSettings::clean($validated['home_hero_cta_url'] ?? null);

        if ($heroCtaUrl && ! HomePageSettings::isSafeCtaUrl($heroCtaUrl)) {
            throw ValidationException::withMessages([
                'home_hero_cta_url' => __('messages.home_cta_url_invalid'),
            ]);
        }

        $heroAlt = HomePageSettings::clean($validated['home_hero_image_alt'] ?? null);

        $heroAssetId = $request->input('home_hero_media_asset_id');
        $heroVariantId = $request->input('home_hero_media_variant_id');

        if ($heroVariantId && ! $heroAssetId) {
            throw ValidationException::withMessages([
                'home_hero_media_variant_id' => __('messages.home_image_variant_mismatch'),
            ]);
        }

        $heroImageAssetId = null;
        $heroImageVariantId = null;

        if ($heroAssetId) {
            $heroAsset = MediaAsset::find((int) $heroAssetId);

            if (! $heroAsset) {
                throw ValidationException::withMessages([
                    'home_hero_media_asset_id' => __('messages.home_image_missing'),
                ]);
            }

            $heroImageAssetId = $heroAsset->id;

            if ($heroVariantId) {
                $heroVariant = MediaAssetVariant::where('media_asset_id', $heroAsset->id)
                    ->find((int) $heroVariantId);

                if (! $heroVariant) {
                    throw ValidationException::withMessages([
                        'home_hero_media_variant_id' => __('messages.home_image_variant_mismatch'),
                    ]);
                }

                $heroImageVariantId = $heroVariant->id;
            }
        } elseif ($request->exists('home_hero_media_asset_id')) {
            $heroImageAssetId = null;
            $heroImageVariantId = null;
        }

        if (! $heroImageAssetId) {
            $heroAlt = null;
        }

        $asideTitle = HomePageSettings::clean($validated['home_aside_title'] ?? null);
        $asideMarkdown = HomePageSettings::clean($validated['home_aside_markdown'] ?? null);
        $asideHtml = $asideMarkdown ? MarkdownUtils::convertToHtml($asideMarkdown) : null;
        $asideAlt = HomePageSettings::clean($validated['home_aside_image_alt'] ?? null);

        $asideAssetId = $request->input('home_aside_media_asset_id');
        $asideVariantId = $request->input('home_aside_media_variant_id');

        if ($asideVariantId && ! $asideAssetId) {
            throw ValidationException::withMessages([
                'home_aside_media_variant_id' => __('messages.home_image_variant_mismatch'),
            ]);
        }

        $imageAssetId = null;
        $imageVariantId = null;

        if ($asideAssetId) {
            $asset = MediaAsset::find((int) $asideAssetId);

            if (! $asset) {
                throw ValidationException::withMessages([
                    'home_aside_media_asset_id' => __('messages.home_image_missing'),
                ]);
            }

            $imageAssetId = $asset->id;

            if ($asideVariantId) {
                $variant = MediaAssetVariant::where('media_asset_id', $asset->id)
                    ->find((int) $asideVariantId);

                if (! $variant) {
                    throw ValidationException::withMessages([
                        'home_aside_media_variant_id' => __('messages.home_image_variant_mismatch'),
                    ]);
                }

                $imageVariantId = $variant->id;
            }
        } elseif ($request->exists('home_aside_media_asset_id')) {
            $imageAssetId = null;
            $imageVariantId = null;
        }

        Setting::setGroup('home', [
            'layout' => $layout,
            'hero_title' => $heroTitle,
            'hero_markdown' => $heroMarkdown,
            'hero_html' => $heroHtml,
            'hero_alignment' => $heroAlignment,
            'hero_show_default_text' => $showDefaultHeroText,
            'hero_cta_label' => $heroCtaLabel,
            'hero_cta_url' => $heroCtaUrl,
            'hero_image_media_asset_id' => $heroImageAssetId,
            'hero_image_media_variant_id' => $heroImageVariantId,
            'hero_image_alt' => $heroAlt,
            'aside_title' => $asideTitle,
            'aside_markdown' => $asideMarkdown,
            'aside_html' => $asideHtml,
            'aside_image_media_asset_id' => $imageAssetId,
            'aside_image_media_variant_id' => $imageVariantId,
            'aside_image_alt' => $asideAlt,
        ]);

        $this->auditSettingsChange($request, 'settings.home.update', [
            'layout' => $layout,
            'hero_has_image' => (bool) $heroImageAssetId,
            'aside_has_image' => (bool) $imageAssetId,
        ]);

        return redirect()->route('settings.home')->with('status', 'home-settings-updated');
    }

    public function updateTerms(Request $request): RedirectResponse
    {
        $this->authorizeAdmin($request->user());

        $validated = $request->validate([
            'terms_markdown' => ['nullable', 'string', 'max:65000'],
        ]);

        $termsMarkdown = $this->nullableTrim($validated['terms_markdown'] ?? null);
        $termsHtml = $termsMarkdown ? MarkdownUtils::convertToHtml($termsMarkdown) : null;

        $storedGeneralSettings = Setting::forGroup('general');

        Setting::setGroup('general', [
            'terms_markdown' => $termsMarkdown,
            'terms_html' => $termsHtml,
            'terms_updated_at' => (($storedGeneralSettings['terms_markdown'] ?? null) !== $termsMarkdown)
                ? now()->toIso8601String()
                : ($storedGeneralSettings['terms_updated_at'] ?? null),
        ]);

        $this->auditSettingsChange($request, 'settings.terms.update', [
            'terms_length' => $termsMarkdown ? mb_strlen($termsMarkdown) : 0,
        ]);

        return redirect()->route('settings.terms')->with('status', 'terms-settings-updated');
    }

    public function refreshTermsFormatting(Request $request): RedirectResponse
    {
        $this->authorizeAdmin($request->user());

        $storedGeneralSettings = Setting::forGroup('general');

        $termsHtml = $this->regenerateMarkdownHtml(
            $storedGeneralSettings['terms_markdown'] ?? null,
            $storedGeneralSettings['terms_html'] ?? null
        );

        Setting::setGroup('general', array_merge($storedGeneralSettings, [
            'terms_html' => $termsHtml,
        ]));

        $this->auditSettingsChange($request, 'settings.terms.refresh', [
            'terms_refreshed' => true,
        ]);

        return redirect()->route('settings.terms')->with('status', 'terms-formatting-refreshed');
    }

    public function updatePrivacy(Request $request): RedirectResponse
    {
        $this->authorizeAdmin($request->user());

        $validated = $request->validate([
            'privacy_markdown' => ['nullable', 'string', 'max:65000'],
        ]);

        $storedGeneralSettings = Setting::forGroup('general');

        $privacyMarkdown = $this->nullableTrim($validated['privacy_markdown'] ?? null);
        $privacyHtml = $privacyMarkdown ? MarkdownUtils::convertToHtml($privacyMarkdown) : null;

        $privacySettings = [
            'privacy_markdown' => $privacyMarkdown,
            'privacy_html' => $privacyHtml,
            'privacy_updated_at' => (($storedGeneralSettings['privacy_markdown'] ?? null) !== $privacyMarkdown)
                ? now()->toDateTimeString()
                : ($storedGeneralSettings['privacy_updated_at'] ?? null),
        ];

        Setting::setGroup('general', array_merge($storedGeneralSettings, $privacySettings));

        $this->auditSettingsChange($request, 'settings.privacy.update', [
            'privacy_length' => $privacyMarkdown ? mb_strlen($privacyMarkdown) : 0,
        ]);

        return redirect()->route('settings.privacy')->with('status', 'privacy-settings-updated');
    }

    public function refreshPrivacyFormatting(Request $request): RedirectResponse
    {
        $this->authorizeAdmin($request->user());

        $storedGeneralSettings = Setting::forGroup('general');

        $privacyHtml = $this->regenerateMarkdownHtml(
            $storedGeneralSettings['privacy_markdown'] ?? null,
            $storedGeneralSettings['privacy_html'] ?? null
        );

        Setting::setGroup('general', array_merge($storedGeneralSettings, [
            'privacy_html' => $privacyHtml,
        ]));

        $this->auditSettingsChange($request, 'settings.privacy.refresh', [
            'privacy_refreshed' => true,
        ]);

        return redirect()->route('settings.privacy')->with('status', 'privacy-formatting-refreshed');
    }

    public function updateMailTemplate(Request $request, MailTemplateManager $mailTemplates, string $template): RedirectResponse
    {
        $this->authorizeAdmin($request->user());

        if (! $mailTemplates->exists($template)) {
            abort(404);
        }

        $templateConfig = $mailTemplates->get($template);

        $rules = [
            'enabled' => ['required', 'boolean'],
        ];

        if (isset($templateConfig['subject'])) {
            $rules['subject'] = ['required', 'string', 'max:255'];
        }

        if (!empty($templateConfig['has_subject_curated']) && isset($templateConfig['subject_curated'])) {
            $rules['subject_curated'] = ['required', 'string', 'max:255'];
        }

        if (isset($templateConfig['body'])) {
            $rules['body'] = ['required', 'string'];
        }

        if (!empty($templateConfig['has_body_curated']) && isset($templateConfig['body_curated'])) {
            $rules['body_curated'] = ['required', 'string'];
        }

        $validated = $request->validate($rules);

        $mailTemplates->updateTemplate($template, $validated);

        $this->auditSettingsChange($request, 'settings.mail_template.update', [
            'template' => $template,
            'enabled' => (bool) ($validated['enabled'] ?? false),
        ]);

        return redirect()
            ->route('settings.email_templates.show', ['template' => $template])
            ->with('status', 'mail-template-updated');
    }

    public function testMailTemplate(Request $request, MailTemplateManager $mailTemplates, string $template): JsonResponse
    {
        $this->authorizeAdmin($request->user());

        if (! $mailTemplates->exists($template)) {
            abort(404);
        }

        $user = $request->user();

        if (! $user || empty($user->email)) {
            return response()->json([
                'status' => 'error',
                'message' => __('messages.test_email_failed'),
                'error' => __('messages.test_email_missing_user'),
                'failures' => [],
            ], 422);
        }

        $isCurated = $request->boolean('curated');

        $data = array_merge(
            $mailTemplates->sampleData($template, $isCurated),
            ['is_curated' => $isCurated]
        );

        $subject = $mailTemplates->renderSubject($template, $data);
        $body = $mailTemplates->renderBody($template, $data);

        $originalMailConfig = $this->getCurrentMailConfig();
        $mailSettings = $this->getMailSettings();

        $this->applyMailConfig($mailSettings, force: true);

        try {
            Mail::to($user->email, $user->name ?? null)->send(new TemplatePreview($subject, $body));

            $inspection = $this->inspectMailerFailures(true);
            $failures = $inspection['failures'];

            if (! empty($failures)) {
                return response()->json([
                    'status' => 'error',
                    'message' => __('messages.test_email_failed'),
                    'error' => __('messages.test_email_failures'),
                    'failures' => $failures,
                ], 500);
            }

            return response()->json([
                'status' => 'success',
                'message' => __('messages.test_email_sent'),
                'failures' => [],
            ]);
        } catch (Throwable $exception) {
            report($exception);

            return response()->json([
                'status' => 'error',
                'message' => __('messages.test_email_failed'),
                'error' => $exception->getMessage(),
                'failures' => [],
            ], 500);
        } finally {
            $this->applyMailConfig($originalMailConfig);
        }
    }

    /**
     * Inspect the configured mailer for any reported delivery failures.
     *
     * @return array{failures: array<int, string>, inspected: bool, note: string|null}
     */
    protected function inspectMailerFailures(bool $throwOnError = false): array
    {
        $result = [
            'failures' => [],
            'inspected' => false,
            'note' => null,
        ];

        try {
            $mailer = Mail::mailer();

            if ($mailer === null) {
                $result['note'] = 'Mailer instance was unavailable for failure inspection; assuming success.';

                return $result;
            }

            if (! is_object($mailer)) {
                $result['note'] = 'Mailer does not support reporting failed recipients; assuming success.';

                return $result;
            }

            if (! method_exists($mailer, 'failures')) {
                $result['note'] = 'Mailer does not support reporting failed recipients; assuming success.';

                return $result;
            }

            $result['failures'] = array_values(array_filter((array) $mailer->failures(), function ($failure) {
                return $failure !== null && $failure !== '';
            }));
            $result['inspected'] = true;

            return $result;
        } catch (Throwable $exception) {
            if ($throwOnError) {
                throw $exception;
            }

            $result['note'] = 'Unable to inspect mailer for delivery failures: ' . $exception->getMessage();

            return $result;
        }
    }

    protected function buildAppleWalletFormValues(array $stored): array
    {
        $config = config('wallet.apple');

        return [
            'enabled' => array_key_exists('enabled', $stored)
                ? WalletConfigManager::toBool($stored['enabled'])
                : (bool) ($config['enabled'] ?? false),
            'pass_type_identifier' => $stored['pass_type_identifier'] ?? ($config['pass_type_identifier'] ?? ''),
            'team_identifier' => $stored['team_identifier'] ?? ($config['team_identifier'] ?? ''),
            'organization_name' => $stored['organization_name'] ?? ($config['organization_name'] ?? config('app.name')),
            'background_color' => $stored['background_color'] ?? ($config['background_color'] ?? 'rgb(78,129,250)'),
            'foreground_color' => $stored['foreground_color'] ?? ($config['foreground_color'] ?? 'rgb(255,255,255)'),
            'label_color' => $stored['label_color'] ?? ($config['label_color'] ?? 'rgb(255,255,255)'),
        ];
    }

    protected function buildGoogleWalletFormValues(array $stored): array
    {
        $config = config('wallet.google');

        return [
            'enabled' => array_key_exists('enabled', $stored)
                ? WalletConfigManager::toBool($stored['enabled'])
                : (bool) ($config['enabled'] ?? false),
            'issuer_id' => $stored['issuer_id'] ?? ($config['issuer_id'] ?? ''),
            'issuer_name' => $stored['issuer_name'] ?? ($config['issuer_name'] ?? config('app.name')),
            'class_suffix' => $stored['class_suffix'] ?? ($config['class_suffix'] ?? 'event'),
        ];
    }

    protected function buildFileInfo(?string $storedRelativePath, ?string $configuredPath): array
    {
        $storedRelativePath = $this->nullableTrim($storedRelativePath);
        $configuredPath = $this->nullableTrim($configuredPath);

        if ($storedRelativePath) {
            $resolvedPath = storage_path('app/' . ltrim($storedRelativePath, '/'));

            return [
                'source' => 'settings',
                'stored_relative' => $storedRelativePath,
                'resolved_path' => $resolvedPath,
                'display_name' => basename($storedRelativePath),
                'exists' => Storage::disk('local')->exists($storedRelativePath),
            ];
        }

        if ($configuredPath) {
            return [
                'source' => 'environment',
                'stored_relative' => null,
                'resolved_path' => $configuredPath,
                'display_name' => basename($configuredPath),
                'exists' => file_exists($configuredPath),
            ];
        }

        return [
            'source' => null,
            'stored_relative' => null,
            'resolved_path' => null,
            'display_name' => null,
            'exists' => false,
        ];
    }

    protected function storeUploadedFile(
        ?UploadedFile $file,
        string $directory,
        ?string $existingRelativePath = null,
        ?string $disk = null
    ): ?string
    {
        if (! $file) {
            return $existingRelativePath;
        }

        $diskName = $disk ?: 'local';

        if ($existingRelativePath) {
            $this->deleteStoredFile($existingRelativePath, $diskName);
        }

        $path = $file->store($directory, $diskName);

        return $path ?: $existingRelativePath;
    }

    protected function deleteStoredFile(?string $relativePath, ?string $disk = null): void
    {
        if ($relativePath) {
            $diskName = $disk ?: 'local';
            Storage::disk($diskName)->delete($relativePath);
        }
    }

    protected function getMailSettings(): array
    {
        $storedMailSettings = Setting::forGroup('mail');

        return [
            'mailer' => $storedMailSettings['mailer'] ?? config('mail.default'),
            'host' => $storedMailSettings['host'] ?? config('mail.mailers.smtp.host'),
            'port' => $storedMailSettings['port'] ?? config('mail.mailers.smtp.port'),
            'username' => $storedMailSettings['username'] ?? config('mail.mailers.smtp.username'),
            'password' => $storedMailSettings['password'] ?? config('mail.mailers.smtp.password'),
            'encryption' => $storedMailSettings['encryption'] ?? config('mail.mailers.smtp.encryption'),
            'from_address' => $storedMailSettings['from_address'] ?? config('mail.from.address'),
            'from_name' => $storedMailSettings['from_name'] ?? config('mail.from.name'),
            'disable_delivery' => array_key_exists('disable_delivery', $storedMailSettings)
                ? $this->toBoolean($storedMailSettings['disable_delivery'])
                : $this->toBoolean(config('mail.disable_delivery')),
            'smtp_url' => config('mail.mailers.smtp.url'),
        ];
    }

    protected function getMassEmailSettings(): array
    {
        $stored = Setting::forGroup('mass_email');

        return [
            'provider' => $stored['provider'] ?? config('mass_email.provider'),
            'api_key' => $stored['api_key'] ?? null,
            'sending_domain' => $stored['sending_domain'] ?? null,
            'webhook_secret' => $stored['webhook_secret'] ?? null,
            'webhook_public_key' => $stored['webhook_public_key'] ?? null,
            'from_name' => $stored['from_name'] ?? config('mass_email.default_from_name'),
            'from_email' => $stored['from_email'] ?? config('mass_email.default_from_email'),
            'reply_to' => $stored['reply_to'] ?? config('mass_email.default_reply_to'),
            'batch_size' => $stored['batch_size'] ?? config('mass_email.batch_size'),
            'rate_limit_per_minute' => $stored['rate_limit_per_minute'] ?? config('mass_email.rate_limit_per_minute'),
            'unsubscribe_footer' => $stored['unsubscribe_footer'] ?? config('mass_email.unsubscribe_footer'),
            'physical_address' => $stored['physical_address'] ?? config('mass_email.physical_address'),
            'retry_attempts' => $stored['retry_attempts'] ?? config('mass_email.retry_attempts'),
            'retry_backoff_seconds' => $stored['retry_backoff_seconds'] ?? config('mass_email.retry_backoff_seconds'),
            'sendgrid_unsubscribe_group_id' => $stored['sendgrid_unsubscribe_group_id'] ?? config('mass_email.sendgrid_unsubscribe_group_id'),
        ];
    }

    protected function getCurrentMailConfig(): array
    {
        return [
            'mailer' => config('mail.default'),
            'host' => config('mail.mailers.smtp.host'),
            'port' => config('mail.mailers.smtp.port'),
            'username' => config('mail.mailers.smtp.username'),
            'password' => config('mail.mailers.smtp.password'),
            'encryption' => config('mail.mailers.smtp.encryption'),
            'from_address' => config('mail.from.address'),
            'from_name' => config('mail.from.name'),
            'disable_delivery' => $this->toBoolean(config('mail.disable_delivery')),
            'smtp_url' => config('mail.mailers.smtp.url'),
        ];
    }

    protected function getGeneralSettings(): array
    {
        $storedGeneralSettings = Setting::forGroup('general');

        return [
            'public_url' => $storedGeneralSettings['public_url'] ?? config('app.url'),
        ];
    }

    protected function getUpdateSettings(): array
    {
        $storedGeneralSettings = Setting::forGroup('general');

        return [
            'update_repository_url' => $storedGeneralSettings['update_repository_url']
                ?? config('self-update.repository_types.github.repository_url'),
            'update_release_channel' => ReleaseChannel::fromString(
                $storedGeneralSettings['update_release_channel'] ?? config('self-update.release_channel')
            )->value,
            'url_utils_verify_ssl' => array_key_exists('url_utils_verify_ssl', $storedGeneralSettings)
                ? $this->toBoolean($storedGeneralSettings['url_utils_verify_ssl'])
                : $this->toBoolean(config('url_utils.verify_ssl', true)),
        ];
    }

    protected function getLoggingSettings(): array
    {
        $storedLoggingSettings = Setting::forGroup('logging');

        $syslogHandlerConfig = config('logging.channels.syslog_server.handler_with', []);
        $defaultSyslogHost = is_array($syslogHandlerConfig)
            ? ($syslogHandlerConfig['host'] ?? '127.0.0.1')
            : '127.0.0.1';
        $defaultSyslogPort = is_array($syslogHandlerConfig)
            ? ($syslogHandlerConfig['port'] ?? 514)
            : 514;

        $defaultLogLevel = config('logging.channels.single.level', 'debug');

        return [
            'log_syslog_host' => $storedLoggingSettings['syslog_host'] ?? $defaultSyslogHost,
            'log_syslog_port' => $storedLoggingSettings['syslog_port'] ?? $defaultSyslogPort,
            'log_level' => $storedLoggingSettings['level'] ?? $defaultLogLevel,
            'log_disabled' => array_key_exists('disabled', $storedLoggingSettings)
                ? $this->toBoolean($storedLoggingSettings['disabled'])
                : false,
        ];
    }

    protected function getBrandingSettings(): array
    {
        $storedBrandingSettings = Setting::forGroup('branding');
        $resolvedBranding = config('branding', []);

        $logoPath = $storedBrandingSettings['logo_path'] ?? null;
        $logoDisk = $storedBrandingSettings['logo_disk'] ?? null;
        $logoUrl = data_get($resolvedBranding, 'logo_url');
        $logoMediaAssetId = $storedBrandingSettings['logo_media_asset_id']
            ?? data_get($resolvedBranding, 'logo_media_asset_id');
        $logoMediaVariantId = $storedBrandingSettings['logo_media_variant_id']
            ?? data_get($resolvedBranding, 'logo_media_variant_id');

        if (! $logoUrl) {
            if ($logoPath) {
                $diskName = $logoDisk ?: storage_public_disk();

                if ($diskName === storage_public_disk()) {
                    $logoUrl = storage_asset_url($logoPath);
                } else {
                    try {
                        $logoUrl = Storage::disk($diskName)->url($logoPath);
                    } catch (\Throwable $exception) {
                        $logoUrl = null;
                    }
                }
            }

            if (! $logoUrl) {
                $logoUrl = branding_logo_url();
            }
        }

        return [
            'logo_path' => $logoPath,
            'logo_disk' => $logoDisk,
            'logo_url' => $logoUrl,
            'logo_media_asset_id' => $logoMediaAssetId ? (int) $logoMediaAssetId : null,
            'logo_media_variant_id' => $logoMediaVariantId ? (int) $logoMediaVariantId : null,
            'logo_alt' => $storedBrandingSettings['logo_alt']
                ?? data_get($resolvedBranding, 'logo_alt', branding_logo_alt()),
            'primary_color' => $storedBrandingSettings['primary_color']
                ?? data_get($resolvedBranding, 'colors.primary', '#1F2937'),
            'secondary_color' => $storedBrandingSettings['secondary_color']
                ?? data_get($resolvedBranding, 'colors.secondary', '#111827'),
            'tertiary_color' => $storedBrandingSettings['tertiary_color']
                ?? data_get($resolvedBranding, 'colors.tertiary', '#374151'),
            'default_language' => $storedBrandingSettings['default_language']
                ?? data_get($resolvedBranding, 'default_language', config('app.locale', 'en')),
        ];
    }

    protected function getBrandingPalettes(): array
    {
        $palettes = [
            [
                'key' => 'monochrome',
                'label' => __('messages.branding_palette_monochrome'),
                'description' => __('messages.branding_palette_monochrome_description'),
                'colors' => [
                    'primary' => '#1F2937',
                    'secondary' => '#111827',
                    'tertiary' => '#374151',
                ],
            ],
            [
                'key' => 'red',
                'label' => __('messages.branding_palette_red'),
                'description' => __('messages.branding_palette_red_description'),
                'colors' => [
                    'primary' => '#B91C1C',
                    'secondary' => '#991B1B',
                    'tertiary' => '#DC2626',
                ],
            ],
            [
                'key' => 'orange',
                'label' => __('messages.branding_palette_orange'),
                'description' => __('messages.branding_palette_orange_description'),
                'colors' => [
                    'primary' => '#C2410C',
                    'secondary' => '#9A3412',
                    'tertiary' => '#BB4F06',
                ],
            ],
            [
                'key' => 'yellow',
                'label' => __('messages.branding_palette_yellow'),
                'description' => __('messages.branding_palette_yellow_description'),
                'colors' => [
                    'primary' => '#B45309',
                    'secondary' => '#92400E',
                    'tertiary' => '#A16207',
                ],
            ],
            [
                'key' => 'green',
                'label' => __('messages.branding_palette_green'),
                'description' => __('messages.branding_palette_green_description'),
                'colors' => [
                    'primary' => '#15803D',
                    'secondary' => '#166534',
                    'tertiary' => '#0B7A34',
                ],
            ],
            [
                'key' => 'blue',
                'label' => __('messages.branding_palette_blue'),
                'description' => __('messages.branding_palette_blue_description'),
                'colors' => [
                    'primary' => '#1D4ED8',
                    'secondary' => '#1E40AF',
                    'tertiary' => '#2563EB',
                ],
            ],
        ];

        foreach ($palettes as &$palette) {
            $primary = $palette['colors']['primary'];

            $palette['colors']['primary_rgb'] = ColorUtils::hexToRgbString($primary) ?? '31, 41, 55';
            $palette['colors']['primary_light'] = ColorUtils::mix($primary, '#FFFFFF', 0.55) ?? '#848991';
        }

        unset($palette);

        return array_values($palettes);
    }

    protected function auditSettingsChange(Request $request, string $action, array $metadata = []): void
    {
        $user = $request->user();

        if (! $user) {
            return;
        }

        $routeName = optional($request->route())->getName();

        $context = array_filter([
            'route' => $routeName,
        ]);

        $this->auditLogger->log($user, $action, 'settings', null, array_merge($context, $metadata));
    }

    public function backups(Request $request, BackupService $service): View
    {
        $this->authorizeAdmin($request->user());

        return view('settings.backups', [
            'backups' => $service->listBackups(),
        ]);
    }

    public function listBackups(Request $request, BackupService $service): JsonResponse
    {
        $this->authorizeAdmin($request->user());

        return response()->json([
            'data' => $service->listBackups(),
        ]);
    }

    public function createBackup(Request $request, BackupService $service): JsonResponse
    {
        $this->authorizeAdmin($request->user());

        $backup = $service->createBackup();

        $this->auditSettingsChange($request, 'settings.backups.create', [
            'backup' => $backup['name'] ?? null,
        ]);

        return response()->json([
            'message' => __('messages.backup_created'),
            'data' => $backup,
        ]);
    }

    public function restoreBackup(Request $request, BackupService $service): JsonResponse
    {
        $this->authorizeAdmin($request->user());

        $validated = $request->validate([
            'confirm' => ['required', 'boolean'],
            'filename' => ['nullable', 'string'],
            'backup' => ['nullable', 'file'],
        ]);

        if (! $request->boolean('confirm')) {
            return response()->json([
                'message' => __('messages.backup_restore_confirm_required'),
            ], 422);
        }

        $backupName = $validated['filename'] ?? null;
        if ($request->hasFile('backup')) {
            $meta = $service->storeUploadedBackup($request->file('backup'));
            $backupName = $meta['name'] ?? null;
        }

        if (! $backupName) {
            return response()->json([
                'message' => __('messages.backup_file_required'),
            ], 422);
        }

        $service->restoreBackup($backupName);

        $this->auditSettingsChange($request, 'settings.backups.restore', [
            'backup' => $backupName,
        ]);

        return response()->json([
            'message' => __('messages.backup_restore_complete'),
        ]);
    }

    public function downloadBackup(Request $request, BackupService $service, string $filename)
    {
        $this->authorizeAdmin($request->user());

        $path = $service->resolveBackupPath($filename);
        abort_unless($path && is_file($path), 404);

        return response()->download($path);
    }

    protected function homeLayoutOptions(): array
    {
        return [
            HomePageSettings::LAYOUT_FULL => [
                'label' => __('messages.home_layout_full'),
                'description' => __('messages.home_layout_full_description'),
            ],
            HomePageSettings::LAYOUT_LEFT => [
                'label' => __('messages.home_layout_left'),
                'description' => __('messages.home_layout_left_description'),
            ],
            HomePageSettings::LAYOUT_RIGHT => [
                'label' => __('messages.home_layout_right'),
                'description' => __('messages.home_layout_right_description'),
            ],
        ];
    }

    protected function getTermsSettings(): array
    {
        $storedGeneralSettings = Setting::forGroup('general');

        return [
            'terms_markdown' => $storedGeneralSettings['terms_markdown']
                ?? config('terms.default_markdown'),
        ];
    }

    protected function getPrivacySettings(): array
    {
        $storedGeneralSettings = Setting::forGroup('general');

        return [
            'privacy_markdown' => $storedGeneralSettings['privacy_markdown']
                ?? config('privacy.default_markdown'),
        ];
    }

    protected function getSupportedLanguageOptions(): array
    {
        return collect(config('app.supported_languages', ['en']))
            ->filter()
            ->mapWithKeys(function ($code) {
                $code = is_string($code) ? strtolower(trim($code)) : null;

                if (! $code) {
                    return [];
                }

                $label = trans("messages.language_name_{$code}");

                if ($label === "messages.language_name_{$code}") {
                    $label = strtoupper($code);
                }

                return [$code => $label];
            })
            ->toArray();
    }

    protected function authorizeAdmin($user): void
    {
        abort_unless($user && $user->isAdmin(), 403);
    }

    protected function applyGeneralConfig(?string $publicUrl): void
    {
        if (empty($publicUrl)) {
            return;
        }

        config(['app.url' => $publicUrl]);
        URL::forceRootUrl($publicUrl);
    }

    protected function applyMailConfig(array $settings, bool $force = false): void
    {
        MailConfigManager::apply($settings, $force);
    }

    protected function nullableTrim(?string $value): ?string
    {
        $value = is_string($value) ? trim($value) : $value;

        return $value === '' ? null : $value;
    }

    protected function regenerateMarkdownHtml(?string $markdown, ?string $storedHtml): ?string
    {
        $markdown = $this->nullableTrim($markdown);
        $storedHtml = $this->nullableTrim($storedHtml);
        $storedHtml = $this->decodeHtmlEntities($storedHtml);

        if ($markdown !== null) {
            return MarkdownUtils::convertToHtml($markdown);
        }

        if ($storedHtml === null) {
            return null;
        }

        if ($this->looksLikeHtml($storedHtml)) {
            return $storedHtml;
        }

        return MarkdownUtils::convertToHtml($storedHtml);
    }

    protected function looksLikeHtml(string $value): bool
    {
        return preg_match('/<[^>]+>/', $value) === 1;
    }

    protected function decodeHtmlEntities(?string $value): ?string
    {
        if ($value === null || ! str_contains($value, '&lt;')) {
            return $value;
        }

        return html_entity_decode($value, ENT_QUOTES | ENT_HTML5, 'UTF-8');
    }

    protected function sanitizeUrl(string $url): string
    {
        $trimmed = trim($url);

        return rtrim($trimmed, '/');
    }

    protected function sanitizeHost(string $host): string
    {
        return trim($host);
    }

    protected function normalizeRepositoryUrl(?string $url): ?string
    {
        if (! is_string($url)) {
            return null;
        }

        $trimmed = trim($url);

        if ($trimmed === '') {
            return null;
        }

        return $this->sanitizeUrl($trimmed);
    }

    protected function toBoolean(mixed $value): bool
    {
        if ($value === null) {
            return false;
        }

        if (is_bool($value)) {
            return $value;
        }

        if (is_numeric($value)) {
            return (bool) $value;
        }

        $normalized = strtolower(trim((string) $value));

        return in_array($normalized, ['1', 'true', 'yes', 'on'], true);
    }

    protected function validateMailSettings(Request $request): array
    {
        return $request->validate([
            'mail_mailer' => ['required', Rule::in(['smtp', 'log'])],
            'mail_host' => [Rule::requiredIf($request->mail_mailer === 'smtp'), 'nullable', 'string', 'max:255'],
            'mail_port' => [Rule::requiredIf($request->mail_mailer === 'smtp'), 'nullable', 'integer', 'between:1,65535'],
            'mail_username' => ['nullable', 'string', 'max:255'],
            'mail_password' => ['nullable', 'string', 'max:255'],
            'mail_encryption' => ['nullable', Rule::in(['tls', 'ssl', ''])],
            'mail_from_address' => ['required', 'email', 'max:255'],
            'mail_from_name' => ['required', 'string', 'max:255'],
            'mail_disable_delivery' => ['nullable', 'boolean'],
        ]);
    }

    protected function validateMassEmailSettings(Request $request): array
    {
        return $request->validate([
            'mass_email_provider' => ['required', 'string', 'max:255'],
            'mass_email_api_key' => ['nullable', 'string', 'max:255'],
            'mass_email_sending_domain' => ['nullable', 'string', 'max:255'],
            'mass_email_webhook_secret' => ['nullable', 'string', 'max:255'],
            'mass_email_webhook_public_key' => ['nullable', 'string', 'max:255'],
            'mass_email_from_name' => ['required', 'string', 'max:255'],
            'mass_email_from_email' => ['required', 'email', 'max:255'],
            'mass_email_reply_to' => ['nullable', 'email', 'max:255'],
            'mass_email_batch_size' => ['nullable', 'integer', 'min:1', 'max:5000'],
            'mass_email_rate_limit' => ['nullable', 'integer', 'min:1', 'max:100000'],
            'mass_email_unsubscribe_footer' => ['nullable', 'string', 'max:2000'],
            'mass_email_physical_address' => ['nullable', 'string', 'max:255'],
            'mass_email_retry_attempts' => ['nullable', 'integer', 'min:1', 'max:10'],
            'mass_email_retry_backoff' => ['nullable', 'string', 'max:255'],
            'mass_email_sendgrid_unsubscribe_group_id' => ['nullable', 'integer', 'min:1'],
        ]);
    }

    protected function buildMailSettings(Request $request, array $validated): array
    {
        $currentSettings = Setting::forGroup('mail');

        $password = $request->filled('mail_password')
            ? trim($validated['mail_password'])
            : ($currentSettings['password'] ?? config('mail.mailers.smtp.password'));

        return [
            'mailer' => $validated['mail_mailer'],
            'host' => $this->nullableTrim($validated['mail_host'] ?? null),
            'port' => isset($validated['mail_port']) ? (string) $validated['mail_port'] : null,
            'username' => $this->nullableTrim($validated['mail_username'] ?? null),
            'password' => $this->nullableTrim($password),
            'encryption' => $this->nullableTrim($validated['mail_encryption'] ?? null),
            'from_address' => trim($validated['mail_from_address']),
            'from_name' => trim($validated['mail_from_name']),
            'disable_delivery' => $request->boolean('mail_disable_delivery') ? '1' : '0',
        ];
    }

    protected function buildMassEmailSettings(Request $request, array $validated): array
    {
        $currentSettings = Setting::forGroup('mass_email');

        $apiKey = $request->filled('mass_email_api_key')
            ? trim($validated['mass_email_api_key'])
            : ($currentSettings['api_key'] ?? null);

        $webhookSecret = $request->filled('mass_email_webhook_secret')
            ? trim($validated['mass_email_webhook_secret'])
            : ($currentSettings['webhook_secret'] ?? null);

        return [
            'provider' => trim($validated['mass_email_provider']),
            'api_key' => $this->nullableTrim($apiKey),
            'sending_domain' => $this->nullableTrim($validated['mass_email_sending_domain'] ?? null),
            'webhook_secret' => $this->nullableTrim($webhookSecret),
            'webhook_public_key' => $this->nullableTrim($validated['mass_email_webhook_public_key'] ?? null),
            'from_name' => trim($validated['mass_email_from_name']),
            'from_email' => trim($validated['mass_email_from_email']),
            'reply_to' => $this->nullableTrim($validated['mass_email_reply_to'] ?? null),
            'batch_size' => isset($validated['mass_email_batch_size']) ? (string) $validated['mass_email_batch_size'] : null,
            'rate_limit_per_minute' => isset($validated['mass_email_rate_limit']) ? (string) $validated['mass_email_rate_limit'] : null,
            'unsubscribe_footer' => $this->nullableTrim($validated['mass_email_unsubscribe_footer'] ?? null),
            'physical_address' => $this->nullableTrim($validated['mass_email_physical_address'] ?? null),
            'retry_attempts' => isset($validated['mass_email_retry_attempts']) ? (string) $validated['mass_email_retry_attempts'] : null,
            'retry_backoff_seconds' => $this->nullableTrim($validated['mass_email_retry_backoff'] ?? null),
            'sendgrid_unsubscribe_group_id' => isset($validated['mass_email_sendgrid_unsubscribe_group_id'])
                ? (string) $validated['mass_email_sendgrid_unsubscribe_group_id']
                : null,
        ];
    }
}
