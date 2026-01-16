<?php

namespace App\Services\Email;

class EmailProviderSendResult
{
    public int $acceptedCount;
    public int $failedCount;
    public array $details;
    public array $messageIds;

    public function __construct(int $acceptedCount, int $failedCount, array $details = [], array $messageIds = [])
    {
        $this->acceptedCount = $acceptedCount;
        $this->failedCount = $failedCount;
        $this->details = $details;
        $this->messageIds = $messageIds;
    }
}
