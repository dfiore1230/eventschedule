<?php

use App\Utils\MarkdownUtils;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        $settings = DB::table('settings')
            ->where('group', 'general')
            ->whereIn('key', ['terms_markdown', 'terms_html', 'privacy_markdown', 'privacy_html'])
            ->get()
            ->keyBy('key');

        $this->convertPlaintextHtml(
            $settings,
            markdownKey: 'terms_markdown',
            htmlKey: 'terms_html'
        );

        $this->convertPlaintextHtml(
            $settings,
            markdownKey: 'privacy_markdown',
            htmlKey: 'privacy_html'
        );
    }

    public function down(): void
    {
    }

    private function convertPlaintextHtml($settings, string $markdownKey, string $htmlKey): void
    {
        $markdownValue = $settings[$markdownKey]->value ?? null;
        $htmlValue = $settings[$htmlKey]->value ?? null;

        if ($markdownValue !== null && trim($markdownValue) !== '') {
            return;
        }

        if ($htmlValue === null || trim($htmlValue) === '') {
            return;
        }

        if (preg_match('/<[^>]+>/', $htmlValue) === 1) {
            return;
        }

        DB::table('settings')
            ->where('group', 'general')
            ->where('key', $htmlKey)
            ->update(['value' => MarkdownUtils::convertToHtml($htmlValue)]);
    }
};
