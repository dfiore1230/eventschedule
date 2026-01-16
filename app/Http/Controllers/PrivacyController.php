<?php

namespace App\Http\Controllers;

use App\Models\Setting;
use App\Utils\MarkdownUtils;
use Illuminate\Support\Carbon;
use Illuminate\View\View;
use Throwable;

class PrivacyController extends Controller
{
    public function show(): View
    {
        $storedGeneralSettings = [];

        try {
            $storedGeneralSettings = Setting::forGroup('general');
        } catch (Throwable $exception) {
            $storedGeneralSettings = [];
        }

        $storedMarkdown = $storedGeneralSettings['privacy_markdown'] ?? null;
        $storedHtml = $storedGeneralSettings['privacy_html'] ?? null;
        $decodedHtml = $storedHtml !== null && str_contains($storedHtml, '&lt;')
            ? html_entity_decode($storedHtml, ENT_QUOTES | ENT_HTML5, 'UTF-8')
            : $storedHtml;
        $storedHtmlLooksLikeHtml = $decodedHtml !== null && preg_match('/<[^>]+>/', $decodedHtml) === 1;

        $privacyHtml = $storedMarkdown
            ? MarkdownUtils::convertToHtml($storedMarkdown)
            : ($decodedHtml
                ? ($storedHtmlLooksLikeHtml ? $decodedHtml : MarkdownUtils::convertToHtml($decodedHtml))
                : MarkdownUtils::convertToHtml(config('privacy.default_markdown')));

        $lastUpdatedRaw = $storedGeneralSettings['privacy_updated_at']
            ?? config('privacy.default_last_updated');

        $lastUpdated = null;

        if (! empty($lastUpdatedRaw)) {
            try {
                $lastUpdated = Carbon::parse($lastUpdatedRaw);
            } catch (Throwable $exception) {
                $lastUpdated = null;
            }
        }

        return view('privacy.show', [
            'privacyHtml' => $privacyHtml,
            'lastUpdated' => $lastUpdated,
        ]);
    }
}
