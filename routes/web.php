<?php

use App\Http\Controllers\ProfileController;
use App\Http\Controllers\SettingsController;
use App\Http\Controllers\RoleController;
use App\Http\Controllers\EventController;
use App\Http\Controllers\GraphicController;
use App\Http\Controllers\HomeController;
use App\Http\Controllers\StripeController;
use App\Http\Controllers\TicketController;
use App\Http\Controllers\InvoiceNinjaController;
use App\Http\Controllers\AppController;
use App\Http\Controllers\Api\ApiSettingsController;
use App\Http\Controllers\BlogController;
use App\Http\Controllers\GoogleCalendarController;
use App\Http\Controllers\GoogleCalendarWebhookController;
use Illuminate\Support\Facades\Route;

if (config('app.hosted')) {
    
    // Redirect all requests to eventschedule.com to www.eventschedule.com
    Route::group(['domain' => 'eventschedule.com'], function () {
        Route::get('{path?}', function ($path = null) {
            return redirect('https://www.eventschedule.com/' . ($path ? $path : ''), 301);
        })->where('path', '.*');
    });

    if (config('app.env') != 'local') {
        Route::domain('blog.eventschedule.com')->group(function () {
            Route::get('/', [BlogController::class, 'index'])->name('blog.index');
            Route::get('/{slug}', [BlogController::class, 'show'])->name('blog.show');
        });
    }

    Route::domain('{subdomain}.eventschedule.com')->where(['subdomain' => '^(?!www|app).*'])->group(function () {
        Route::get('/request', [RoleController::class, 'request'])->name('role.request');
        Route::get('/follow', [RoleController::class, 'follow'])->name('role.follow');
        Route::get('/guest-add', [EventController::class, 'showGuestImport'])->name('event.guest_import');
        Route::post('/guest-add', [EventController::class, 'guestImport'])->name('event.guest_import');
        Route::post('/guest-parse', [EventController::class, 'guestParse'])->name('event.guest_parse');
        Route::post('/guest-upload-image', [EventController::class, 'guestUploadImage'])->name('event.guest_upload_image');
        Route::get('/guest-search-youtube', [RoleController::class, 'guestSearchYouTube'])->name('role.guest_search_youtube');
        Route::get('/curate-event/{hash}', [EventController::class, 'curate'])->name('event.curate');
        Route::post('/checkout', [TicketController::class, 'checkout'])->name('event.checkout');
        Route::get('/checkout/success/{sale_id}/{date}', [TicketController::class, 'success'])->name('checkout.success');
        Route::get('/checkout/cancel/{sale_id}/{date}', [TicketController::class, 'cancel'])->name('checkout.cancel');
        Route::get('/payment/success/{sale_id}', [TicketController::class, 'paymentUrlSuccess'])->name('payment_url.success');
        Route::get('/payment/cancel/{sale_id}', [TicketController::class, 'paymentUrlCancel'])->name('payment_url.cancel');
        Route::get('/{slug}', [RoleController::class, 'viewGuest'])->name('event.view_guest');
    });
} else {
    Route::match(['get', 'post'], '/update', [AppController::class, 'update'])->name('app.update');
    Route::post('/test_database', [AppController::class, 'testDatabase'])->name('app.test_database');
}

require __DIR__ . '/auth.php';

Route::get('/sitemap.xml', [HomeController::class, 'sitemap'])->name('sitemap');
Route::get('/unsubscribe', [RoleController::class, 'showUnsubscribe'])->name('role.show_unsubscribe');
Route::post('/unsubscribe', [RoleController::class, 'unsubscribe'])->name('role.unsubscribe')->middleware('throttle:2,2');
Route::get('/user/unsubscribe', [RoleController::class, 'unsubscribeUser'])->name('user.unsubscribe')->middleware('throttle:2,2');
Route::post('/clear-pending-request', [EventController::class, 'clearPendingRequest'])->name('event.clear_pending_request');

Route::post('/stripe/webhook', [StripeController::class, 'webhook'])->name('stripe.webhook')->middleware('throttle:60,1');
Route::post('/invoiceninja/webhook/{secret}', [InvoiceNinjaController::class, 'webhook'])->name('invoiceninja.webhook')->middleware('throttle:60,1');

// Google Calendar webhook routes (no auth required)
Route::get('/google-calendar/webhook', [GoogleCalendarWebhookController::class, 'verify'])->name('google.calendar.webhook.verify')->middleware('throttle:10,1');
Route::post('/google-calendar/webhook', [GoogleCalendarWebhookController::class, 'handle'])->name('google.calendar.webhook.handle')->middleware('throttle:60,1');

Route::get('/release_tickets', [TicketController::class, 'release'])->name('release_tickets')->middleware('throttle:5,1');
Route::get('/translate_data', [AppController::class, 'translateData'])->name('translate_data')->middleware('throttle:5,1');

Route::get('/ticket/qr_code/{event_id}/{secret}', [TicketController::class, 'qrCode'])->name('ticket.qr_code')->middleware('throttle:100,1');
Route::get('/ticket/view/{event_id}/{secret}', [TicketController::class, 'view'])->name('ticket.view')->middleware('throttle:100,1');

Route::middleware(['auth', 'verified'])->group(function () 
{
    Route::get('/events', [HomeController::class, 'home'])->name('home');
    Route::get('/new/{type}', [RoleController::class, 'create'])->name('new');
    Route::post('/validate_address', [RoleController::class, 'validateAddress'])->name('validate_address')->middleware('throttle:25,1440');
    Route::post('/store', [RoleController::class, 'store'])->name('role.store');
    Route::get('/search-roles', [RoleController::class, 'search'])->name('role.search');
    Route::get('/search-events/{subdomain}', [RoleController::class, 'searchEvents'])->name('role.search_events');
    Route::get('/admin-edit-event/{hash}', [EventController::class, 'editAdmin'])->name('event.edit_admin');
    Route::get('/following', [RoleController::class, 'following'])->name('following');
    Route::get('/tickets', [TicketController::class, 'tickets'])->name('tickets');
    Route::get('/sales', [TicketController::class, 'sales'])->name('sales');
    Route::post('/sales/action/{sale_id}', [TicketController::class, 'handleAction'])->name('sales.action');
    
    Route::get('/settings', [SettingsController::class, 'index'])->name('settings.index');
    Route::patch('/settings/mail', [SettingsController::class, 'updateMail'])->name('settings.mail.update');
    Route::patch('/settings/mail-templates', [SettingsController::class, 'updateMailTemplates'])->name('settings.mail_templates.update');

    Route::get('/account', [ProfileController::class, 'edit'])->name('profile.edit');
    Route::patch('/account', [ProfileController::class, 'update'])->name('profile.update');
    Route::patch('/account/payments', [ProfileController::class, 'updatePayments'])->name('profile.update_payments');
    Route::delete('/account', [ProfileController::class, 'destroy'])->name('profile.destroy');

    Route::get('/stripe/link', [StripeController::class, 'link'])->name('stripe.link');
    Route::get('/stripe/unlink', [StripeController::class, 'unlink'])->name('stripe.unlink');
    Route::get('/stripe/complete', [StripeController::class, 'complete'])->name('stripe.complete');
    Route::get('/invoiceninja/unlink', [InvoiceNinjaController::class, 'unlink'])->name('invoiceninja.unlink');
    Route::get('/payment_url/unlink', [ProfileController::class, 'unlinkPaymentUrl'])->name('profile.unlink_payment_url');
    
    // Google Calendar routes
    Route::get('/google-calendar/redirect', [GoogleCalendarController::class, 'redirect'])->name('google.calendar.redirect');
    Route::get('/google-calendar/callback', [GoogleCalendarController::class, 'callback'])->name('google.calendar.callback');
    Route::get('/google-calendar/disconnect', [GoogleCalendarController::class, 'disconnect'])->name('google.calendar.disconnect');
    Route::get('/google-calendar/calendars', [GoogleCalendarController::class, 'getCalendars'])->name('google.calendar.calendars');
    Route::post('/google-calendar/sync-events', [GoogleCalendarController::class, 'syncEvents'])->name('google.calendar.sync_events');
    Route::post('/google-calendar/sync-event/{eventId}', [GoogleCalendarController::class, 'syncEvent'])->name('google.calendar.sync_event');
    Route::delete('/google-calendar/unsync-event/{eventId}', [GoogleCalendarController::class, 'unsyncEvent'])->name('google.calendar.unsync_event');
    Route::post('/google-calendar/role/{subdomain}', [GoogleCalendarController::class, 'updateRoleCalendar'])->name('google.calendar.update_role');
    Route::post('/google-calendar/sync-direction/{subdomain}', [GoogleCalendarController::class, 'updateSyncDirection'])->name('google.calendar.sync_direction');
    Route::post('/google-calendar/sync-from-google/{subdomain}', [GoogleCalendarController::class, 'syncFromGoogleCalendar'])->name('google.calendar.sync_from_google');
    
    Route::get('/scan', [TicketController::class, 'scan'])->name('ticket.scan');
    Route::post('/ticket/view/{event_id}/{secret}', [TicketController::class, 'scanned'])->name('ticket.scanned');

    Route::get('/{subdomain}/change-plan/{plan_type}', [RoleController::class, 'changePlan'])->name('role.change_plan');
    Route::post('/{subdomain}/availability', [RoleController::class, 'availability'])->name('role.availability');
    Route::get('/{subdomain}/edit', [RoleController::class, 'edit'])->name('role.edit');
    Route::get('/{subdomain}/subscribe', [RoleController::class, 'subscribe'])->name('role.subscribe');
    Route::get('/{subdomain}/unfollow', [RoleController::class, 'unfollow'])->name('role.unfollow');
    Route::put('/{subdomain}/update', [RoleController::class, 'update'])->name('role.update');
    Route::get('/{subdomain}/delete', [RoleController::class, 'delete'])->name('role.delete');
    Route::get('/{subdomain}/delete-image', [RoleController::class, 'deleteImage'])->name('role.delete_image');
    Route::get('/{subdomain}/add-event', [EventController::class, 'create'])->name('event.create');
    Route::get('/{subdomain}/verify/{hash}', [RoleController::class, 'verify'])->name('role.verification.verify');
    Route::get('/{subdomain}/resend', [RoleController::class, 'resendVerify'])->name('role.verification.resend');    
    Route::get('/{subdomain}/resend-invite/{hash}', [RoleController::class, 'resendInvite'])->name('role.resend_invite');
    Route::post('/{subdomain}/store-event', [EventController::class, 'store'])->name('event.store');    
    Route::get('/{subdomain}/edit-event/{hash}', [EventController::class, 'edit'])->name('event.edit');
    Route::get('/{subdomain}/delete-event/{hash}', [EventController::class, 'delete'])->name('event.delete');
    Route::put('/{subdomain}/update-event/{hash}', [EventController::class, 'update'])->name('event.update');
    Route::get('/{subdomain}/delete-event-image', [EventController::class, 'deleteImage'])->name('event.delete_image');
    Route::get('/{subdomain}/events-graphic', [GraphicController::class, 'generateGraphic'])->name('event.generate_graphic');
    Route::get('/{subdomain}/events-graphic/data', [GraphicController::class, 'generateGraphicData'])->name('event.generate_graphic_data');
    Route::get('/{subdomain}/events-graphic/download', [GraphicController::class, 'downloadGraphic'])->name('event.download_graphic');
    Route::get('/{subdomain}/clear-videos/{event_hash}/{role_hash}', [EventController::class, 'clearVideos'])->name('event.clear_videos');
    Route::get('/{subdomain}/requests/accept-event/{hash}', [EventController::class, 'accept'])->name('event.accept');
    Route::get('/{subdomain}/requests/decline-event/{hash}', [EventController::class, 'decline'])->name('event.decline');
    Route::post('/{subdomain}/profile/update-links', [RoleController::class, 'updateLinks'])->name('role.update_links');
    Route::post('/{subdomain}/profile/remove-links', [RoleController::class, 'removeLinks'])->name('role.remove_links');
    Route::get('/{subdomain}/followers/qr-code', [RoleController::class, 'qrCode'])->name('role.qr_code');
    Route::get('/{subdomain}/team/add-member', [RoleController::class, 'createMember'])->name('role.create_member');
    Route::post('/{subdomain}/team/add-member', [RoleController::class, 'storeMember'])->name('role.store_member');
    Route::get('/{subdomain}/team/remove-member/{hash}', [RoleController::class, 'removeMember'])->name('role.remove_member');
    Route::delete('/{subdomain}/uncurate-event/{hash}', [EventController::class, 'uncurate'])->name('event.uncurate');
    Route::get('/{subdomain}/import', [EventController::class, 'showImport'])->name('event.show_import');
    Route::post('/{subdomain}/parse', [EventController::class, 'parse'])->name('event.parse');    
    Route::post('/{subdomain}/import', [EventController::class, 'import'])->name('event.import');    
    Route::post('/{subdomain}/test-import', [RoleController::class, 'testImport'])->name('role.test_import');
    Route::get('/{subdomain}/search-youtube', [RoleController::class, 'searchYouTube'])->name('role.search_youtube');
    Route::get('/{subdomain}/match-videos', [RoleController::class, 'getTalentRolesWithoutVideos'])->name('role.talent_roles_without_videos');
    Route::post('/{subdomain}/save-video', [RoleController::class, 'saveVideo'])->name('role.save_video');
    Route::post('/{subdomain}/save-videos', [RoleController::class, 'saveVideos'])->name('role.save_videos');
    Route::get('/{subdomain}/{tab}', [RoleController::class, 'viewAdmin'])->name('role.view_admin')->where('tab', 'schedule|availability|requests|profile|followers|team|plan|videos');

    Route::post('/{subdomain}/upload-image', [EventController::class, 'uploadImage'])->name('event.upload_image');

    Route::get('/api/documentation', function () {
        return view('api.documentation');
    })->name('api.documentation');

    Route::patch('/api-settings', [ApiSettingsController::class, 'update'])->name('api-settings.update');
    Route::post('/api-settings/show-key', [ApiSettingsController::class, 'showApiKey'])->name('api-settings.show-key');

    // Admin blog routes (only for admin users)
    Route::get('/admin/blog', [BlogController::class, 'adminIndex'])->name('blog.admin.index');
    Route::get('/admin/blog/create', [BlogController::class, 'create'])->name('blog.create');
    Route::post('/admin/blog', [BlogController::class, 'store'])->name('blog.store');
    Route::get('/admin/blog/{blogPost}/edit', [BlogController::class, 'edit'])->name('blog.edit');
    Route::put('/admin/blog/{blogPost}', [BlogController::class, 'update'])->name('blog.update');
    Route::delete('/admin/blog/{blogPost}', [BlogController::class, 'destroy'])->name('blog.destroy');
    Route::post('/admin/blog/generate-content', [BlogController::class, 'generateContent'])->name('blog.generate-content');
});

Route::get('/tmp/event-image/{filename?}', function ($filename = null) {
    if (!$filename) {
        abort(404);
    }
    
    // Prevent path traversal attacks
    $filename = basename($filename);
    
    // Only allow alphanumeric characters, hyphens, underscores, and dots
    if (!preg_match('/^[a-zA-Z0-9._-]+$/', $filename)) {
        abort(404);
    }
    
    // Ensure filename starts with 'event_' prefix for security
    if (!str_starts_with($filename, 'event_')) {
        abort(404);
    }

    $path = '/tmp/' . $filename;
    
    if (file_exists($path)) {
        return response()->file($path);
    }

    abort(404);
})->name('event.tmp_image');

if (config('app.hosted')) {
    Route::domain('{subdomain}.eventschedule.com')->where(['subdomain' => '^(?!www|app).*'])->group(function () {
        Route::get('/', [RoleController::class, 'viewGuest'])->name('role.view_guest');
    });
} else {
    Route::get('/{subdomain}/request', [RoleController::class, 'request'])->name('role.request');
    Route::get('/{subdomain}/follow', [RoleController::class, 'follow'])->name('role.follow');
    Route::get('/{subdomain}/guest-add', [EventController::class, 'showGuestImport'])->name('event.guest_import');
    Route::post('/{subdomain}/guest-add', [EventController::class, 'guestImport'])->name('event.guest_import');
    Route::post('/{subdomain}/guest-parse', [EventController::class, 'guestParse'])->name('event.guest_parse');
    Route::post('/{subdomain}/guest-upload-image', [EventController::class, 'guestUploadImage'])->name('event.guest_upload_image');
    Route::get('/{subdomain}/guest-search-youtube', [RoleController::class, 'guestSearchYouTube'])->name('role.guest_search_youtube');
    Route::get('/{subdomain}/curate-event/{hash}', [EventController::class, 'curate'])->name('event.curate');
    Route::post('/{subdomain}/checkout', [TicketController::class, 'checkout'])->name('event.checkout');
    Route::get('/{subdomain}/checkout/success/{sale_id}', [TicketController::class, 'success'])->name('checkout.success');
    Route::get('/{subdomain}/checkout/cancel/{sale_id}', [TicketController::class, 'cancel'])->name('checkout.cancel');
    Route::get('/{subdomain}/payment/success/{sale_id}', [TicketController::class, 'paymentUrlSuccess'])->name('payment_url.success');
    Route::get('/{subdomain}/payment/cancel/{sale_id}', [TicketController::class, 'paymentUrlCancel'])->name('payment_url.cancel');
    Route::get('/{subdomain}', [RoleController::class, 'viewGuest'])->name('role.view_guest');
    Route::get('/{subdomain}/{slug}', [RoleController::class, 'viewGuest'])->name('event.view_guest');
}

if (config('app.env') == 'local') {
    Route::get('/blog', [BlogController::class, 'index'])->name('blog.index');
    Route::get('/blog/{slug}', [BlogController::class, 'show'])->name('blog.show');
}

Route::get('/{slug?}', [HomeController::class, 'landing'])->name('landing');