<?php

namespace App\Services\Email;

use App\Models\EmailList;
use App\Models\Event;

class EmailListService
{
    public function getGlobalList(): EmailList
    {
        $key = config('mass_email.global_list_key', 'GLOBAL_UPDATES');

        return EmailList::query()->firstOrCreate(
            ['key' => $key],
            ['type' => EmailList::TYPE_GLOBAL, 'name' => 'Planify Updates']
        );
    }

    public function getEventList(Event $event): EmailList
    {
        return EmailList::query()->firstOrCreate(
            ['type' => EmailList::TYPE_EVENT, 'event_id' => $event->id],
            ['name' => $event->translatedName() ?? $event->name]
        );
    }
}
