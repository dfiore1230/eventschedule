<?php

namespace App\Notifications;

use App\Models\Event;
use App\Models\EventInvite;
use App\Models\User;
use App\Support\EventMailTemplateManager;
use App\Support\MailConfigManager;
use App\Utils\NotificationUtils;
use Illuminate\Bus\Queueable;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;

class EventInviteNotification extends Notification
{
    use Queueable;

    protected Event $event;
    protected EventInvite $invite;
    protected ?User $sender;

    public function __construct(Event $event, EventInvite $invite, ?User $sender = null)
    {
        $this->event = $event;
        $this->invite = $invite;
        $this->sender = $sender;
    }

    public function via(object $notifiable): array
    {
        MailConfigManager::applyFromDatabase();

        if (config('mail.disable_delivery')) {
            return [];
        }

        $templates = EventMailTemplateManager::forEvent($this->event);

        return $templates->enabled($this->templateKey()) ? ['mail'] : [];
    }

    public function toMail(object $notifiable): MailMessage
    {
        $event = $this->event;
        $templates = EventMailTemplateManager::forEvent($event);
        $templateKey = $this->templateKey();

        $eventName = NotificationUtils::eventDisplayName($event);
        $eventDate = $event->localStartsAt(true) ?: __('messages.date_to_be_announced');

        $senderName = $this->sender?->name ?? $event->user?->name;
        $senderEmail = $this->sender?->email ?? $event->user?->email;

        $inviteUrl = $this->invite->getInviteUrl();
        $eventUrl = $event->getGuestUrl(false, null, null, true);

        $data = [
            'event_name' => $eventName,
            'event_date' => $eventDate,
            'event_url' => $eventUrl,
            'invite_url' => $inviteUrl,
            'organizer_name' => $senderName,
            'organizer_email' => $senderEmail,
            'app_name' => config('app.name'),
        ];

        $subject = $templates->renderSubject($templateKey, $data);
        $body = $templates->renderBody($templateKey, $data);

        $mail = (new MailMessage())
            ->subject($subject)
            ->markdown('mail.templates.generic', [
                'body' => $body,
            ]);

        if ($senderEmail) {
            $mail->replyTo($senderEmail, $senderName);
        }

        return $mail;
    }

    public function toArray(object $notifiable): array
    {
        return [];
    }

    protected function templateKey(): string
    {
        return 'event_invite';
    }
}
