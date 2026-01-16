<?php

namespace App\Services\Email;

use Illuminate\Http\Request;

interface EmailProviderInterface
{
    public function sendBatch(array $messages): EmailProviderSendResult;

    public function validateFromAddress(string $fromEmail): bool;

    public function parseWebhook(Request $request): EmailProviderWebhookResult;

    public function syncSuppressions(array $emails, string $reason): void;
}
