<?php

namespace App\Support;

class MassEmailConfigManager
{
    public static function apply(array $settings): void
    {
        $config = [
            'mass_email.provider' => $settings['provider'] ?? config('mass_email.provider'),
            'mass_email.api_key' => $settings['api_key'] ?? config('mass_email.api_key'),
            'mass_email.sending_domain' => $settings['sending_domain'] ?? config('mass_email.sending_domain'),
            'mass_email.webhook_secret' => $settings['webhook_secret'] ?? config('mass_email.webhook_secret'),
            'mass_email.webhook_public_key' => $settings['webhook_public_key'] ?? config('mass_email.webhook_public_key'),
            'mass_email.default_from_name' => $settings['from_name'] ?? config('mass_email.default_from_name'),
            'mass_email.default_from_email' => $settings['from_email'] ?? config('mass_email.default_from_email'),
            'mass_email.default_reply_to' => $settings['reply_to'] ?? config('mass_email.default_reply_to'),
            'mass_email.unsubscribe_footer' => $settings['unsubscribe_footer'] ?? config('mass_email.unsubscribe_footer'),
            'mass_email.physical_address' => $settings['physical_address'] ?? config('mass_email.physical_address'),
            'mass_email.retry_attempts' => $settings['retry_attempts'] ?? config('mass_email.retry_attempts'),
            'mass_email.retry_backoff_seconds' => $settings['retry_backoff_seconds'] ?? config('mass_email.retry_backoff_seconds'),
            'mass_email.sendgrid_unsubscribe_group_id' => $settings['sendgrid_unsubscribe_group_id'] ?? config('mass_email.sendgrid_unsubscribe_group_id'),
        ];

        if (array_key_exists('batch_size', $settings)) {
            $config['mass_email.batch_size'] = (int) $settings['batch_size'];
        }

        if (array_key_exists('rate_limit_per_minute', $settings)) {
            $config['mass_email.rate_limit_per_minute'] = (int) $settings['rate_limit_per_minute'];
        }

        config($config);
    }
}
