<?php

namespace App\Services\Email;

class EmailMessage
{
    public string $toEmail;
    public ?string $toName;
    public string $subject;
    public string $fromEmail;
    public ?string $fromName;
    public ?string $replyTo;
    public ?string $html;
    public ?string $text;
    public array $headers;
    public array $metadata;

    public function __construct(
        string $toEmail,
        ?string $toName,
        string $subject,
        string $fromEmail,
        ?string $fromName = null,
        ?string $replyTo = null,
        ?string $html = null,
        ?string $text = null,
        array $headers = [],
        array $metadata = []
    ) {
        $this->toEmail = $toEmail;
        $this->toName = $toName;
        $this->subject = $subject;
        $this->fromEmail = $fromEmail;
        $this->fromName = $fromName;
        $this->replyTo = $replyTo;
        $this->html = $html;
        $this->text = $text;
        $this->headers = $headers;
        $this->metadata = $metadata;
    }
}
