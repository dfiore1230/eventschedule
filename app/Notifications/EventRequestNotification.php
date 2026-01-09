<?php

namespace App\Notifications;

use App\Support\EventMailTemplateManager;
use App\Support\MailConfigManager;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;

class EventRequestNotification extends Notification
{
    use Queueable;

    protected $venue;
    protected $role;
    
    /**
     * Create a new notification instance.
     */
    public function __construct($venue, $role)
    {
        $this->role = $role;
        $this->venue = $venue;
    }

    /**
     * Get the notification's delivery channels.
     *
     * @return array<int, string>
     */
    public function via(object $notifiable): array
    {
        MailConfigManager::applyFromDatabase();

        if (config('mail.disable_delivery')) {
            return [];
        }

        $event = $this->venue->events()->first();
        $templates = $event
            ? EventMailTemplateManager::forEvent($event)
            : app(\App\Support\MailTemplateManager::class);

        return $templates->enabled($this->templateKey()) ? ['mail'] : [];
    }

    /**
     * Get the mail representation of the notification.
     */
    public function toMail(object $notifiable): MailMessage
    {
        $event = $this->venue->events()->first();
        $templates = $event
            ? EventMailTemplateManager::forEvent($event)
            : app(\App\Support\MailTemplateManager::class);
        $templateKey = $this->templateKey();

        $data = [
            'role_name' => $this->role->name,
            'venue_name' => $this->venue->name,
            'venue_subdomain' => $this->venue->subdomain,
            'requests_url' => route('role.view_admin', ['subdomain' => $this->venue->subdomain, 'tab' => 'requests']),
            'app_name' => config('app.name'),
        ];

        $subject = $templates->renderSubject($templateKey, $data) ?: str_replace(':name', $this->role->name, __('messages.new_request'));
        $body = $templates->renderBody($templateKey, $data);

        return (new MailMessage)
            ->replyTo($this->role->user->email, $this->role->user->name)
            ->subject($subject)
            ->markdown('mail.templates.generic', ['body' => $body]);
    }

    /**
     * Get the array representation of the notification.
     *
     * @return array<string, mixed>
     */
    public function toArray(object $notifiable): array
    {
        return [
            //
        ];
    }

    protected function templateKey(): string
    {
        return 'event_request';
    }

    /**
     * Get the notification's mail headers.
     */
    public function toMailHeaders(): array
    {
        return [
            'List-Unsubscribe' => '<' . route('role.unsubscribe', ['subdomain' => $this->venue->subdomain]) . '>',
            'List-Unsubscribe-Post' => 'List-Unsubscribe=One-Click',
        ];
    }
}
