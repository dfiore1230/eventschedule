<?php

namespace App\Support;

use App\Models\Event;
use App\Models\EventNotificationSetting;

class EventMailTemplateManager extends MailTemplateManager
{
    protected array $overrides;

    public function __construct(?array $overrides = null)
    {
        $this->overrides = $overrides ?? [];
        parent::__construct();
    }

    public static function forEvent(Event $event): self
    {
        $setting = $event->relationLoaded('notificationSetting')
            ? $event->notificationSetting
            : $event->notificationSetting()->first();

        $overrides = $setting instanceof EventNotificationSetting ? ($setting->settings ?? []) : [];

        return new self($overrides);
    }

    protected function buildTemplate(string $key, array $config): array
    {
        $template = parent::buildTemplate($key, $config);

        $templateOverride = $this->overrides['templates'][$key] ?? null;

        if (is_array($templateOverride)) {
            foreach (['subject', 'subject_curated', 'body', 'body_curated'] as $field) {
                if (array_key_exists($field, $templateOverride) && $templateOverride[$field] !== null) {
                    $template[$field] = $templateOverride[$field];
                }
            }

            if (array_key_exists('enabled', $templateOverride)) {
                $template['enabled'] = (bool) $templateOverride['enabled'];
            }
        }

        $channelOverride = $this->overrides['channels'][$key]['mail'] ?? null;

        if ($channelOverride !== null) {
            $template['enabled'] = (bool) ($template['enabled'] ?? true) && (bool) $channelOverride;
        }

        return $template;
    }
}
