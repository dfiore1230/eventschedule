<?php

namespace App\Http\Controllers;

use App\Models\Event;
use App\Services\Email\EmailListService;
use App\Utils\UrlUtils;
use Illuminate\Http\Request;
use Illuminate\View\View;

class PublicEmailSignupController extends Controller
{
    public function show(Request $request, EmailListService $listService, ?string $hash = null): View
    {
        $event = null;
        $list = $listService->getGlobalList();

        if ($hash) {
            $eventId = UrlUtils::decodeId($hash);
            if ($eventId) {
                $event = Event::find($eventId);
                if ($event) {
                    $list = $listService->getEventList($event);
                }
            }
        }

        return view('public.subscribe', [
            'event' => $event,
            'list' => $list,
        ]);
    }
}
