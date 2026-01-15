<?php

namespace App\Support;

use App\Support\ColorUtils;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\App;
use Illuminate\Support\Facades\Config;
use Illuminate\Support\Facades\Storage;

class BrandingManager
{
    public const BUTTON_TEXT_COLOR_CANDIDATES = ['#FFFFFF', '#111827'];

    public static function apply(?array $settings = null): void
    {
        $settings = $settings ?? [];

        $defaults = [
            'logo_path' => config('branding.logo_path'),
            'logo_disk' => config('branding.logo_disk'),
            'logo_light_path' => config('branding.logo_light_path'),
            'logo_light_disk' => config('branding.logo_light_disk'),
            'logo_dark_path' => config('branding.logo_dark_path'),
            'logo_dark_disk' => config('branding.logo_dark_disk'),
            'logo_alt' => config('branding.logo_alt', 'Planify'),
            'primary_color' => data_get(config('branding'), 'colors.primary', '#1F2937'),
            'secondary_color' => data_get(config('branding'), 'colors.secondary', '#111827'),
            'tertiary_color' => data_get(config('branding'), 'colors.tertiary', '#374151'),
            'default_language' => config('branding.default_language', config('app.fallback_locale', 'en')),
        ];

        // Backward compatibility: if only legacy logo_path exists, treat it as the light logo.
        $logoLightPath = Arr::get($settings, 'logo_light_path', Arr::get($settings, 'logo_path', $defaults['logo_light_path']));
        $logoLightDisk = Arr::get($settings, 'logo_light_disk', Arr::get($settings, 'logo_disk', $defaults['logo_light_disk']));
        $logoDarkPath = Arr::get($settings, 'logo_dark_path', $defaults['logo_dark_path']);
        $logoDarkDisk = Arr::get($settings, 'logo_dark_disk', $defaults['logo_dark_disk']);
        $logoAlt = Arr::get($settings, 'logo_alt', $defaults['logo_alt']);
        $logoLightMediaAssetId = Arr::get($settings, 'logo_light_media_asset_id', Arr::get($settings, 'logo_media_asset_id'));
        $logoLightMediaVariantId = Arr::get($settings, 'logo_light_media_variant_id', Arr::get($settings, 'logo_media_variant_id'));
        $logoDarkMediaAssetId = Arr::get($settings, 'logo_dark_media_asset_id');
        $logoDarkMediaVariantId = Arr::get($settings, 'logo_dark_media_variant_id');

        $primary = ColorUtils::normalizeHexColor(
            Arr::get($settings, 'primary_color', $defaults['primary_color'])
        ) ?? '#1F2937';

        $secondary = ColorUtils::normalizeHexColor(
            Arr::get($settings, 'secondary_color', $defaults['secondary_color'])
        ) ?? '#111827';

        $tertiary = ColorUtils::normalizeHexColor(
            Arr::get($settings, 'tertiary_color', $defaults['tertiary_color'])
        ) ?? '#374151';

        $primaryRgb = ColorUtils::hexToRgbString($primary) ?? '31, 41, 55';
        $primaryLight = ColorUtils::mix($primary, '#FFFFFF', 0.55) ?? '#848991';

        $textColorCandidates = self::BUTTON_TEXT_COLOR_CANDIDATES;

        $onPrimary = ColorUtils::bestContrastingColor($primary, $textColorCandidates)['color'] ?? '#FFFFFF';
        $onSecondary = ColorUtils::bestContrastingColor($secondary, $textColorCandidates)['color'] ?? '#FFFFFF';
        $onTertiary = ColorUtils::bestContrastingColor($tertiary, $textColorCandidates)['color'] ?? '#FFFFFF';

        $defaultLanguage = Arr::get($settings, 'default_language', $defaults['default_language']);
        if (! is_valid_language_code($defaultLanguage)) {
            $defaultLanguage = config('app.fallback_locale', 'en');
        }

        $logoLightUrl = self::resolveLogoUrl($logoLightPath, $logoLightDisk, url('images/planify_horizontal_light.png'));
        $logoDarkUrl = self::resolveLogoUrl($logoDarkPath, $logoDarkDisk, url('images/planify_horizontal_dark.png'));

        // Fallback: if no dark logo provided, use light for both.
        if (! $logoDarkUrl) {
            $logoDarkUrl = $logoLightUrl;
        }

        $resolved = [
            'logo_path' => $logoLightPath,
            'logo_disk' => $logoLightDisk,
            'logo_url' => $logoLightUrl,
            'logo_light_path' => $logoLightPath,
            'logo_light_disk' => $logoLightDisk,
            'logo_light_url' => $logoLightUrl,
            'logo_dark_path' => $logoDarkPath,
            'logo_dark_disk' => $logoDarkDisk,
            'logo_dark_url' => $logoDarkUrl,
            'logo_alt' => is_string($logoAlt) && trim($logoAlt) !== ''
                ? trim($logoAlt)
                : 'Planify',
            'logo_media_asset_id' => $logoLightMediaAssetId ? (int) $logoLightMediaAssetId : null,
            'logo_media_variant_id' => $logoLightMediaVariantId ? (int) $logoLightMediaVariantId : null,
            'logo_light_media_asset_id' => $logoLightMediaAssetId ? (int) $logoLightMediaAssetId : null,
            'logo_light_media_variant_id' => $logoLightMediaVariantId ? (int) $logoLightMediaVariantId : null,
            'logo_dark_media_asset_id' => $logoDarkMediaAssetId ? (int) $logoDarkMediaAssetId : null,
            'logo_dark_media_variant_id' => $logoDarkMediaVariantId ? (int) $logoDarkMediaVariantId : null,
            'colors' => [
                'primary' => $primary,
                'secondary' => $secondary,
                'tertiary' => $tertiary,
                'primary_rgb' => $primaryRgb,
                'primary_light' => $primaryLight,
                'on_primary' => $onPrimary,
                'on_secondary' => $onSecondary,
                'on_tertiary' => $onTertiary,
            ],
            'default_language' => $defaultLanguage,
        ];

        Config::set('branding', $resolved);

        if (App::getLocale() !== $defaultLanguage) {
            App::setLocale($defaultLanguage);
        }

        Config::set('app.locale', $defaultLanguage);
    }

    protected static function resolveLogoUrl(?string $path, ?string $disk, string $fallback): ?string
    {
        if (! is_string($path) || trim($path) === '') {
            return $fallback;
        }

        $diskName = is_string($disk) && trim($disk) !== '' ? $disk : storage_public_disk();

        if ($diskName === storage_public_disk()) {
            return storage_asset_url($path);
        }

        try {
            if (Config::has("filesystems.disks.{$diskName}")) {
                return Storage::disk($diskName)->url($path);
            }
        } catch (\Throwable $exception) {
            // Fall back to the default asset URL below.
        }

        return storage_asset_url($path);
    }
}
