<?php

namespace App\Mail;

use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;
use Illuminate\Queue\SerializesModels;

class ConfirmSubscriptionMail extends Mailable
{
    use Queueable, SerializesModels;

    public function __construct(
        public string $confirmUrl,
        public string $listName
    ) {
    }

    public function envelope(): Envelope
    {
        return new Envelope(
            subject: 'Confirm your subscription'
        );
    }

    public function content(): Content
    {
        $body = <<<BODY
Hello,

Please confirm your subscription to {$this->listName} by clicking the link below:

{$this->confirmUrl}

If you did not request this, you can ignore this email.
BODY;

        return new Content(
            markdown: 'mail.templates.generic',
            with: ['body' => nl2br(e($body))]
        );
    }
}
