<?php

namespace App\Notifications;

use App\Support\EventMailTemplateManager;
use App\Support\MailConfigManager;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;

class DeletedRoleNotification extends Notification
{
    use Queueable;

    protected $role;
    protected $user;

    /**
     * Create a new notification instance.
     */
    public function __construct($role, $user)
    {
        $this->role = $role;
        $this->user = $user;
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

        $event = $this->role?->events()->first();
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
        $role = $this->role;
        $user = $this->user;

        $event = $role?->events()->first();
        $templates = $event
            ? EventMailTemplateManager::forEvent($event)
            : app(\App\Support\MailTemplateManager::class);
        $templateKey = $this->templateKey();

        $data = [
            'role_name' => $role->name,
            'role_type' => $role->type,
            'actor_name' => $user->name,
            'app_name' => config('app.name'),
        ];

        $subject = $templates->renderSubject($templateKey, $data)
            ?: str_replace(':type', __('messages.' . $role->type), __('messages.role_has_been_deleted'));
        $body = $templates->renderBody($templateKey, $data);

        return (new MailMessage)
            ->replyTo($user->email, $user->name)
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

    /**
     * Get the notification's mail headers.
     */
    public function toMailHeaders(): array
    {
        return [
            'List-Unsubscribe' => '<' . route('role.unsubscribe', ['subdomain' => $this->role->subdomain]) . '>',
            'List-Unsubscribe-Post' => 'List-Unsubscribe=One-Click',
        ];
    }

    protected function templateKey(): string
    {
        return 'role_deleted';
    }
}
