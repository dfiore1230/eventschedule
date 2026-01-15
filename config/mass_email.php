<?php

return [
    'double_opt_in_marketing' => env('MASS_EMAIL_DOUBLE_OPT_IN', true),
    'provider' => env('MASS_EMAIL_PROVIDER', 'laravel_mail'),
    'api_key' => env('MASS_EMAIL_API_KEY'),
    'sending_domain' => env('MASS_EMAIL_SENDING_DOMAIN'),
    'webhook_secret' => env('MASS_EMAIL_WEBHOOK_SECRET'),
    'event_list_membership_on_refund' => env('EVENT_LIST_MEMBERSHIP_ON_REFUND', 'retain'),
    'confirmation_token_ttl_minutes' => env('MASS_EMAIL_CONFIRM_TTL', 10080), // 7 days
    'unsubscribe_token_ttl_minutes' => env('MASS_EMAIL_UNSUBSCRIBE_TTL', 525600), // 365 days
    'batch_size' => env('MASS_EMAIL_BATCH_SIZE', 500),
    'rate_limit_per_minute' => env('MASS_EMAIL_RATE_LIMIT', 1200),
    'retry_attempts' => env('MASS_EMAIL_RETRY_ATTEMPTS', 3),
    'retry_backoff_seconds' => env('MASS_EMAIL_RETRY_BACKOFF', '60,300,900'),
    'default_from_name' => env('MASS_EMAIL_FROM_NAME', env('MAIL_FROM_NAME', 'Planify')),
    'default_from_email' => env('MASS_EMAIL_FROM_EMAIL', env('MAIL_FROM_ADDRESS', 'no-reply@example.com')),
    'default_reply_to' => env('MASS_EMAIL_REPLY_TO'),
    'global_list_key' => env('MASS_EMAIL_GLOBAL_LIST_KEY', 'GLOBAL_UPDATES'),
    'unsubscribe_footer' => env('MASS_EMAIL_UNSUBSCRIBE_FOOTER', ''),
    'physical_address' => env('MASS_EMAIL_PHYSICAL_ADDRESS', ''),
];
