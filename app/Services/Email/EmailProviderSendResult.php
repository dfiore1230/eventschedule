<?php

namespace App\Services\Email;

class EmailProviderSendResult
{
    public int $acceptedCount;
    public int $failedCount;
    public array $details;

    public function __construct(int $acceptedCount, int $failedCount, array $details = [])
    {
        $this->acceptedCount = $acceptedCount;
        $this->failedCount = $failedCount;
        $this->details = $details;
    }
}
