<?php

namespace App\Utils;

use League\CommonMark\CommonMarkConverter;
use HTMLPurifier;
use HTMLPurifier_Config;
use Illuminate\Support\Facades\File;

class MarkdownUtils
{
    public static function convertToHtml($markdown)
    {
        if (! $markdown) {
            return $markdown;
        }

        try {
            $converter = new CommonMarkConverter([
                'renderer' => [
                    'soft_break' => '<br>'
                ]
            ]);
            $html = $converter->convertToHtml($markdown);
        } catch (\Throwable $e) {
            // Fail-safe: if markdown conversion fails, log and return stripped markdown
            if (class_exists('\Illuminate\Support\Facades\Log')) {
                \Illuminate\Support\Facades\Log::error('Markdown conversion failed', ['exception' => $e]);
            }

            return strip_tags($markdown);
        }

        try {
            $config = HTMLPurifier_Config::createDefault();
            $config->set('HTML.Allowed', implode(',', [
                'a[href|title|target|rel]',
                'blockquote',
                'br',
                'code',
                'em',
                'h1',
                'h2',
                'h3',
                'h4',
                'h5',
                'h6',
                'hr',
                'img[src|alt|title|width|height]',
                'li',
                'ol',
                'p',
                'pre',
                'strong',
                'ul',
            ]));
            $cachePath = storage_path('app/htmlpurifier');

            if (! File::exists($cachePath)) {
                File::makeDirectory($cachePath, 0755, true);
            }

            if (File::exists($cachePath) && File::isWritable($cachePath)) {
                $config->set('Cache.SerializerPath', $cachePath);
            }

            $purifier = new HTMLPurifier($config);

            return $purifier->purify($html);
        } catch (\Throwable $e) {
            if (class_exists('\Illuminate\Support\Facades\Log')) {
                \Illuminate\Support\Facades\Log::warning('Markdown HTML sanitization failed', ['exception' => $e]);
            }

            return $html;
        }
    }
}
