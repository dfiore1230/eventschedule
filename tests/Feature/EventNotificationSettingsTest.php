<?php

namespace Tests\Feature;

use App\Models\Event;
use App\Models\EventNotificationSetting;
use App\Models\Sale;
use App\Models\User;
use App\Notifications\TicketPaidNotification;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class EventNotificationSettingsTest extends TestCase
{
    use RefreshDatabase;

    public function test_event_can_disable_mail_channel_for_template(): void
    {
        $event = Event::factory()->create();
        $sale = Sale::factory()->create([
            'event_id' => $event->id,
            'status' => 'paid',
        ]);

        EventNotificationSetting::create([
            'event_id' => $event->id,
            'settings' => [
                'channels' => [
                    'ticket_paid_organizer' => ['mail' => false],
                ],
            ],
        ]);

        $event->refresh();

        $notification = new TicketPaidNotification($sale, 'organizer');

        $this->assertSame([], $notification->via($event->user ?? new User()));
    }

    public function test_event_template_override_is_used(): void
    {
        $event = Event::factory()->create(['name' => 'Sample Event']);
        $sale = Sale::factory()->create([
            'event_id' => $event->id,
            'status' => 'paid',
        ]);

        EventNotificationSetting::create([
            'event_id' => $event->id,
            'settings' => [
                'templates' => [
                    'ticket_paid_purchaser' => [
                        'subject' => 'Custom subject for :event_name',
                    ],
                ],
            ],
        ]);

        $event->refresh();

        $notification = new TicketPaidNotification($sale, 'purchaser');

        $mail = $notification->toMail($event->user ?? new User());

        $this->assertStringContainsString('Custom subject for ' . $event->name, $mail->subject);
    }

    public function test_event_added_notification_respects_channel_toggle(): void
    {
        $event = Event::factory()->create();

        EventNotificationSetting::create([
            'event_id' => $event->id,
            'settings' => [
                'channels' => [
                    'event_added' => ['mail' => false],
                ],
            ],
        ]);

        $event->refresh();

        $notification = new \App\Notifications\EventAddedNotification($event, null, 'organizer', $event->venue ?: null);

        $this->assertSame([], $notification->via($event->user ?? new User()));
    }

    public function test_booking_request_accept_subject_can_be_overridden(): void
    {
        $event = Event::factory()->create(['name' => 'Headline Event']);

        EventNotificationSetting::create([
            'event_id' => $event->id,
            'settings' => [
                'templates' => [
                    'booking_request_accepted_talent' => [
                        'subject' => 'Accepted: :event_name for talent',
                    ],
                ],
            ],
        ]);

        $event->refresh();

        $notification = new \App\Notifications\RequestAcceptedNotification($event, null, 'talent', $event->venue ?: null);

        $mail = $notification->toMail($event->user ?? new User());

        $this->assertStringContainsString('Accepted: ' . $event->name, $mail->subject);
    }

    public function test_member_added_channel_can_be_disabled(): void
    {
        $event = Event::factory()->create();
        $role = \App\Models\Role::factory()->create(['type' => 'talent']);
        $event->roles()->attach($role->id, ['is_accepted' => true]);
        $event->refresh();
        $user = User::factory()->create();
        $admin = User::factory()->create();

        EventNotificationSetting::create([
            'event_id' => $event->id,
            'settings' => [
                'channels' => [
                    'member_added' => ['mail' => false],
                ],
            ],
        ]);

        $event->refresh();

        $notification = new \App\Notifications\AddedMemberNotification($role, $user, $admin);

        $this->assertSame([], $notification->via($user));
    }

    public function test_role_deleted_subject_can_be_overridden(): void
    {
        $event = Event::factory()->create();
        $role = \App\Models\Role::factory()->create(['type' => 'talent']);
        $event->roles()->attach($role->id, ['is_accepted' => true]);
        $event->refresh();
        $actor = User::factory()->create();

        EventNotificationSetting::create([
            'event_id' => $event->id,
            'settings' => [
                'templates' => [
                    'role_deleted' => [
                        'subject' => 'Custom deleted :role_name',
                    ],
                ],
            ],
        ]);

        $event->refresh();

        $notification = new \App\Notifications\DeletedRoleNotification($role, $actor);

        $mail = $notification->toMail($actor);

        $this->assertStringContainsString('Custom deleted ' . $role->name, $mail->subject);
    }
}
