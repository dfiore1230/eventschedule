<?php

namespace App\Notifications;

use App\Support\EventMailTemplateManager;
use App\Support\MailConfigManager;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;

class AddedMemberNotification extends Notification
{
    use Queueable;

    protected $role;
    protected $user;
    protected $admin;
    
    /**
     * Create a new notification instance.
     */
    public function __construct($role, $user, $admin)
    {
        $this->role = $role;
        $this->user = $user;
        $this->admin = $admin;
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
        $newUser = $this->user->wasRecentlyCreated;

        $event = $this->role?->events()->first();
        $templates = $event
            ? EventMailTemplateManager::forEvent($event)
            : app(\App\Support\MailTemplateManager::class);
        $templateKey = $this->templateKey();

        $data = [
            'role_name' => $this->role->name,
            'admin_name' => $this->admin->name,
            'admin_email' => $this->admin->email,
            'action_url' => $newUser
                ? route('password.request', ['email' => $this->user->email])
                : route('role.view_admin', ['subdomain' => $this->role->subdomain, 'tab' => 'schedule']),
            'app_name' => config('app.name'),
        ];

        $subject = $templates->renderSubject($templateKey, $data) ?: str_replace(':name', $this->role->name, __('messages.added_to_team'));
        $body = $templates->renderBody($templateKey, $data);

        return (new MailMessage)
            ->replyTo($this->admin->email, $this->admin->name)
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
        return 'member_added';
    }
}
