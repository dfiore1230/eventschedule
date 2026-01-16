<?php

namespace App\Services\Email\Providers;

use App\Services\Email\EmailMessage;
use App\Services\Email\EmailProviderInterface;
use App\Services\Email\EmailProviderSendResult;
use App\Services\Email\EmailProviderWebhookResult;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Mail;

class LaravelMailProvider implements EmailProviderInterface
{
    public function sendBatch(array $messages): EmailProviderSendResult
    {
        $accepted = 0;
        $failed = 0;
        $details = [];

        foreach ($messages as $message) {
            try {
                $this->sendMessage($message);
                $accepted++;
            } catch (\Throwable $e) {
                $failed++;
                $details[] = ['error' => $e->getMessage()];
            }
        }

        return new EmailProviderSendResult($accepted, $failed, $details);
    }

    public function validateFromAddress(string $fromEmail): bool
    {
        return (bool) filter_var($fromEmail, FILTER_VALIDATE_EMAIL);
    }

    public function parseWebhook(Request $request): EmailProviderWebhookResult
    {
        $payload = $request->all();
        $events = $payload['events'] ?? [];

        $bounces = [];
        $complaints = [];
        $unsubscribes = [];

        foreach ($events as $event) {
            $type = $event['type'] ?? null;
            if ($type === 'bounce') {
                $bounces[] = $event;
            } elseif ($type === 'complaint') {
                $complaints[] = $event;
            } elseif ($type === 'unsubscribe') {
                $unsubscribes[] = $event;
            }
        }

        return new EmailProviderWebhookResult($bounces, $complaints, $unsubscribes);
    }

    public function syncSuppressions(array $emails, string $reason): void
    {
        // SMTP mailers do not provide suppression APIs.
    }

    private function sendMessage(EmailMessage $message): void
    {
        Mail::send([], [], function ($mail) use ($message) {
            $mail->to($message->toEmail, $message->toName ?? null)
                ->from($message->fromEmail, $message->fromName ?? null)
                ->subject($message->subject);

            if ($message->replyTo) {
                $mail->replyTo($message->replyTo);
            }

            if ($message->html) {
                $mail->setBody($message->html, 'text/html');

                if ($message->text) {
                    $mail->addPart($message->text, 'text/plain');
                }
            } elseif ($message->text) {
                $mail->setBody($message->text, 'text/plain');
            }

            $headers = $mail->getHeaders();

            foreach ($message->headers as $key => $value) {
                if ($value === null || $value === '') {
                    continue;
                }

                $headers->addTextHeader($key, (string) $value);
            }
        });
    }
}
