<?php

namespace App\Services\Email;

class EmailProviderWebhookResult
{
    public array $bounces;
    public array $complaints;
    public array $unsubscribes;

    public function __construct(array $bounces = [], array $complaints = [], array $unsubscribes = [])
    {
        $this->bounces = $bounces;
        $this->complaints = $complaints;
        $this->unsubscribes = $unsubscribes;
    }
}
