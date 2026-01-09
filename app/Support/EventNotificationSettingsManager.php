<?php

namespace App\Support;

use App\Models\Event;
use App\Models\EventNotificationSetting;

class EventNotificationSettingsManager
{
    /**
     * Persist per-event notification settings. Only known template keys and channels are stored.
     */
    public function update(Event $event, array $input): EventNotificationSetting
    {
        $allowedTemplates = array_keys(config('mail_templates.templates', []));

        $existing = $event->notificationSetting?->settings ?? [];
        $settings = [
            'templates' => $existing['templates'] ?? [],
            'channels' => $existing['channels'] ?? [],
        ];

        $templateInput = $input['templates'] ?? [];
        foreach ($templateInput as $key => $templateData) {
            if (! in_array($key, $allowedTemplates, true) || ! is_array($templateData)) {
                continue;
            }

            $settings['templates'][$key] = $settings['templates'][$key] ?? [];

            foreach (['subject', 'subject_curated', 'body', 'body_curated'] as $field) {
                if (array_key_exists($field, $templateData)) {
                    $value = $templateData[$field];
                    $settings['templates'][$key][$field] = is_string($value) ? $value : null;
                }
            }

            if (array_key_exists('enabled', $templateData)) {
                $settings['templates'][$key]['enabled'] = $this->toBool($templateData['enabled']);
            }
        }

        $channelsInput = $input['channels'] ?? [];
        foreach ($channelsInput as $key => $channelData) {
            if (! in_array($key, $allowedTemplates, true) || ! is_array($channelData)) {
                continue;
            }

            $settings['channels'][$key] = $settings['channels'][$key] ?? [];

            if (array_key_exists('mail', $channelData)) {
                $settings['channels'][$key]['mail'] = $this->toBool($channelData['mail']);
            }
        }

        // Clean out empty overrides to keep payloads small
        $settings['templates'] = array_filter($settings['templates'], function ($template) {
            return is_array($template) && count(array_filter($template, fn ($v) => $v !== null && $v !== '')) > 0;
        });

        $settings['channels'] = array_filter($settings['channels'], function ($channels) {
            return is_array($channels) && count(array_filter($channels, fn ($v) => $v !== null)) > 0;
        });

        return EventNotificationSetting::updateOrCreate(
            ['event_id' => $event->id],
            ['settings' => $settings]
        );
    }

    public static function allowedTemplateKeys(): array
    {
        return array_keys(config('mail_templates.templates', []));
    }

    protected function toBool(mixed $value): bool
    {
        if (is_bool($value)) {
            return $value;
        }

        if (is_numeric($value)) {
            return (bool) $value;
        }

        return filter_var($value, FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE) ?? false;
    }
}
