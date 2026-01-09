<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Event;
use App\Support\EventMailTemplateManager;
use App\Support\EventNotificationSettingsManager;
use App\Utils\UrlUtils;
use Illuminate\Http\Request;

class ApiEventNotificationController extends Controller
{
    public function show(Request $request, $event_id)
    {
        $event = Event::with('notificationSetting')->findOrFail(UrlUtils::decodeId($event_id));

        if ($event->user_id !== auth()->id()) {
            return response()->json(['error' => 'Unauthorized'], 403);
        }

        $manager = EventMailTemplateManager::forEvent($event);

        return response()->json([
            'data' => [
                'settings' => $event->notificationSetting?->settings ?? [],
                'templates' => $manager->all(),
            ],
        ], 200, [], JSON_PRETTY_PRINT);
    }

    public function update(Request $request, $event_id)
    {
        $event = Event::with('notificationSetting')->findOrFail(UrlUtils::decodeId($event_id));

        if ($event->user_id !== auth()->id()) {
            return response()->json(['error' => 'Unauthorized'], 403);
        }

        $validated = $request->validate([
            'notification_settings' => 'required|array',
            'notification_settings.templates' => 'sometimes|array',
            'notification_settings.channels' => 'sometimes|array',
        ]);

        app(EventNotificationSettingsManager::class)->update(
            $event,
            $validated['notification_settings']
        );

        $event->load('notificationSetting');

        $manager = EventMailTemplateManager::forEvent($event);

        return response()->json([
            'data' => [
                'settings' => $event->notificationSetting?->settings ?? [],
                'templates' => $manager->all(),
            ],
            'meta' => [
                'message' => 'Notification settings updated',
            ],
        ], 200, [], JSON_PRETTY_PRINT);
    }
}
