<?php

namespace App\Notifications;

use App\Models\Event;
use App\Models\Role;
use App\Models\User;
use App\Support\EventMailTemplateManager;
use App\Support\MailConfigManager;
use App\Utils\NotificationUtils;
use Illuminate\Bus\Queueable;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;

class RequestDeclinedNotification extends Notification
{
    use Queueable;

    protected Event $event;
    protected ?User $actor;
    protected string $recipientType;
    protected ?Role $contextRole;

    public function __construct(Event $event, ?User $actor = null, string $recipientType = 'talent', ?Role $contextRole = null)
    {
        $this->event = $event;
        $this->actor = $actor;
        $this->recipientType = $recipientType;
        $this->contextRole = $contextRole;
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
        $eventName = NotificationUtils::eventDisplayName($this->event);
        $venueName = $this->event->getVenueDisplayName();
        $talentName = optional($this->event->role())->getDisplayName();
        $date = $this->event->localStartsAt(true);

        $lineKey = $this->recipientType === 'organizer'
            ? 'messages.booking_request_declined_organizer'
            : 'messages.booking_request_declined_talent';

        $templates = EventMailTemplateManager::forEvent($this->event);
        $templateKey = $this->templateKey();

        $data = [
            'event_name' => $eventName,
            'venue_name' => $venueName ?: __('messages.event'),
            'talent_name' => $talentName ?: $eventName,
            'event_date' => $date ?: __('messages.date_to_be_announced'),
            'event_url' => $this->event->getGuestUrl($this->contextRole?->subdomain ?? $this->event->venue?->subdomain),
            'app_name' => config('app.name'),
        ];

        $subject = $templates->renderSubject($templateKey, $data) ?: __('messages.booking_request_declined_subject');
        $body = $templates->renderBody($templateKey, $data);

        $mail = (new MailMessage)
            ->subject($subject)
            ->markdown('mail.templates.generic', ['body' => $body]);

        if ($this->actor && $this->actor->email) {
            $mail->replyTo($this->actor->email, $this->actor->name);
        }

        return $mail;
    }

    public function toArray(object $notifiable): array
    {
        return [];
    }

    protected function templateKey(): string
    {
        return $this->recipientType === 'organizer'
            ? 'booking_request_declined_organizer'
            : 'booking_request_declined_talent';
    }

    public function toMailHeaders(): array
    {
        $subdomain = $this->contextRole?->subdomain
            ?? $this->event->venue?->subdomain
            ?? $this->event->role()?->subdomain;

        if (! $subdomain) {
            return [];
        }

        return [
            'List-Unsubscribe' => '<' . route('role.unsubscribe', ['subdomain' => $subdomain]) . '>',
            'List-Unsubscribe-Post' => 'List-Unsubscribe=One-Click',
        ];
    }
}

