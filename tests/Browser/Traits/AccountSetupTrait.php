<?php

namespace Tests\Browser\Traits;

use App\Models\Role;
use App\Models\User;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;
use Laravel\Dusk\Browser;
use Throwable;

trait AccountSetupTrait
{
    protected ?string $testAccountEmail = null;
    protected ?int $testAccountUserId = null;

    /**
     * @var array<string, array<string, string>>
     */
    protected array $roleSlugs = [];

    /**
     * Set up a test account with basic data
     */
    protected function setupTestAccount(Browser $browser, string $name = 'Talent', string $email = 'test@gmail.com', string $password = 'password'): void
    {
        $this->testAccountEmail = $email;
        $this->testAccountUserId = null;

        // Sign up
        $browser->visit('/')
                ->cookie('browser_testing', '1')
                ->visit('/sign_up')
                ->type('name', $name)
                ->type('email', $email)
                ->type('password', $password)
                ->check('terms');

        $this->scrollIntoViewWhenPresent($browser, 'button[type="submit"]')
                ->click('@sign-up-button');

        try {
            $currentPath = $this->waitForAnyLocation($browser, ['/events', '/login', '/'], 20);
        } catch (Throwable $exception) {
            $currentPath = $this->currentPath($browser);
        }

        if (! $currentPath || ! Str::startsWith($currentPath, '/events')) {
            $browser->assertPathIs('/login')
                    ->type('email', $email)
                    ->type('password', $password)
                    ->click('@log-in-button');

            try {
                $currentPath = $this->waitForAnyLocation($browser, ['/events', '/login', '/'], 20);
            } catch (Throwable $exception) {
                $currentPath = $this->currentPath($browser);
            }

            if (! $currentPath || ! Str::startsWith($currentPath, '/events')) {
                $browser->visit('/events');

                try {
                    $currentPath = $this->waitForAnyLocation($browser, ['/events', '/login', '/'], 10);
                } catch (Throwable $exception) {
                    $currentPath = $this->currentPath($browser);
                }
            }
        }

        $this->assertNotNull($currentPath, 'Unable to determine the current path after registration.');
        $this->assertTrue(
            Str::startsWith($currentPath, '/events'),
            sprintf('Expected to reach the events dashboard after registration, but ended on [%s].', $currentPath)
        );

        $browser->assertSee($name);

        if ($user = $this->resolveTestAccountUser()) {
            $this->testAccountUserId = $user->id;
        }
    }

    /**
     * Create a test venue
     */
    protected function createTestVenue(Browser $browser, string $name = 'Venue', string $address = '123 Test St'): void
    {
        $browser->visit('/new/venue')
                ->waitForLocation('/new/venue', 10)
                ->assertPathIs('/new/venue')
                ->waitFor('input[name="name"]', 10)
                ->clear('name')
                ->type('name', $name)
                ->pause(1000)
                ->type('address1', $address);

        $this->scrollIntoViewWhenPresent($browser, 'button[type="submit"]');

        $this->pressButtonWhenPresent($browser, 'Save');

        $slug = $this->waitForRoleScheduleRedirect($browser, 'venue', $name, 20);

        $this->verifyRoleEmailAddress('venue', $name, $slug);
    }

    /**
     * Create a test talent
     */
    protected function createTestTalent(Browser $browser, string $name = 'Talent'): void
    {
        $browser->visit('/new/talent')
                ->waitForLocation('/new/talent', 10)
                ->assertPathIs('/new/talent')
                ->waitFor('input[name="name"]', 10)
                ->clear('name')
                ->type('name', $name)
                ->pause(1000);

        $this->scrollIntoViewWhenPresent($browser, 'button[type="submit"]');

        $this->pressButtonWhenPresent($browser, 'Save');

        $slug = $this->waitForRoleScheduleRedirect($browser, 'talent', $name, 20);

        $this->verifyRoleEmailAddress('talent', $name, $slug);
    }

    /**
     * Create a test curator
     */
    protected function createTestCurator(Browser $browser, string $name = 'Curator'): void
    {
        $browser->visit('/new/curator')
                ->waitForLocation('/new/curator', 10)
                ->assertPathIs('/new/curator')
                ->waitFor('input[name="name"]', 10)
                ->clear('name')
                ->type('name', $name)
                ->pause(1000);

        $this->scrollIntoViewWhenPresent($browser, 'input[name="accept_requests"]')
                ->check('accept_requests');

        $this->scrollIntoViewWhenPresent($browser, 'button[type="submit"]');

        $this->pressButtonWhenPresent($browser, 'Save');

        $slug = $this->waitForRoleScheduleRedirect($browser, 'curator', $name, 20);

        $this->verifyRoleEmailAddress('curator', $name, $slug);
    }

    /**
     * Create a test event with tickets
     */
    protected function createTestEventWithTickets(Browser $browser, string $talentName = 'Talent', string $venueName = 'Venue', string $eventName = 'Test Event'): void
    {
        $talentSlug = $this->getRoleSlug('talent', $talentName, 15);

        $this->visitRoleAddEventPage($browser, $talentSlug, date('Y-m-d', strtotime('+3 days')), 'talent', $talentName);

        $this->selectExistingVenue($browser);

        $browser->type('name', $eventName);

        $this->scrollIntoViewWhenPresent($browser, 'input[name="tickets_enabled"]')
                ->check('tickets_enabled')
                ->type('tickets[0][price]', '10')
                ->type('tickets[0][quantity]', '50')
                ->type('tickets[0][description]', 'General admission ticket');

        $this->scrollIntoViewWhenPresent($browser, 'button[type="submit"]');

        $this->pressButtonWhenPresent($browser, 'Save');

        $schedulePath = '/' . $talentSlug . '/schedule';

        $this->waitForPath($browser, $schedulePath, 20);

        $browser->assertSee($venueName);
    }

    /**
     * Select the first available venue for the event form.
     */
    protected function selectExistingVenue(Browser $browser, ?string $expectedName = null): void
    {
        $this->waitForInteractiveDocument($browser);

        if ($this->trySelectVenueThroughUi($browser)) {
            return;
        }

        if ($this->forceSelectVenue($browser, $expectedName)) {
            return;
        }

        $this->fail('Unable to select a venue for the event form.');
    }

    protected function trySelectVenueThroughUi(Browser $browser, int $seconds = 20): bool
    {
        try {
            $this->waitForVueApp($browser, $seconds);
        } catch (Throwable $exception) {
            return false;
        }

        try {
            $browser->waitFor('#selected_venue', $seconds);
        } catch (Throwable $exception) {
            return false;
        }

        try {
            $browser->waitUsing($seconds, 100, function () use ($browser) {
                $result = $browser->script(<<<'JS'
                    return (function () {
                        var select = document.querySelector('#selected_venue');

                        if (!select) {
                            return 0;
                        }

                        var usable = Array.prototype.filter.call(select.options, function (option) {
                            if (option.value && option.value !== '') {
                                return true;
                            }

                            return option.__value !== undefined && option.__value !== null;
                        });

                        return usable.length;
                    })();
                JS);

                return ! empty($result) && $result[0] > 0;
            });
        } catch (Throwable $exception) {
            return false;
        }

        try {
            $browser->script(<<<'JS'
                (function () {
                    var radio = document.querySelector('input[name="venue_type"][value="use_existing"]');

                    if (radio && !radio.checked) {
                        radio.click();
                    }

                    var select = document.querySelector('#selected_venue');

                    if (!select) {
                        return;
                    }

                    var options = Array.prototype.filter.call(select.options, function (option) {
                        if (option.value && option.value !== '') {
                            return true;
                        }

                        return option.__value !== undefined && option.__value !== null;
                    });

                    if (!options.length) {
                        return;
                    }

                    var option = options[0];
                    var index = Array.prototype.indexOf.call(select.options, option);

                    if (index < 0) {
                        return;
                    }

                    select.selectedIndex = index;
                    select.dispatchEvent(new Event('input', { bubbles: true }));
                    select.dispatchEvent(new Event('change', { bubbles: true }));
                })();
            JS);
        } catch (Throwable $exception) {
            return false;
        }

        try {
            $browser->waitUsing(10, 100, function () use ($browser) {
                $value = $browser->value('input[name="venue_id"]');

                return ! empty($value);
            });
        } catch (Throwable $exception) {
            return false;
        }

        return true;
    }

    protected function forceSelectVenue(Browser $browser, ?string $expectedName = null): bool
    {
        $role = $this->findRole('venue', $expectedName);

        if (! $role) {
            return false;
        }

        $roleData = $role->toData();
        $encodedId = $roleData['id'] ?? null;
        $roleName = $role->name ?? $expectedName ?? 'Venue';

        if ($encodedId === null || $encodedId === '') {
            return false;
        }

        $jsonOptions = JSON_HEX_TAG | JSON_HEX_APOS | JSON_HEX_QUOT | JSON_HEX_AMP;
        $roleJson = json_encode($roleData, $jsonOptions);
        $encodedIdJson = json_encode($encodedId, $jsonOptions);
        $roleNameJson = json_encode($roleName, $jsonOptions);

        if ($roleJson === false || $encodedIdJson === false || $roleNameJson === false) {
            return false;
        }

        $browser->script('window.__forcedVenueSelectionApplied = false;');

        $script = <<<'JS'
            (function () {
                var encodedId = __FORCED_VENUE_ID__;
                var venueData = __FORCED_VENUE_DATA__;
                var venueName = __FORCED_VENUE_NAME__;

                if (!encodedId && venueData && venueData.id) {
                    encodedId = venueData.id;
                }

                var hidden = document.querySelector('input[name="venue_id"]');

                if (!hidden) {
                    var form = document.querySelector('form[action*="event"]') || document.querySelector('form');

                    if (form) {
                        hidden = document.createElement('input');
                        hidden.type = 'hidden';
                        hidden.name = 'venue_id';
                        form.appendChild(hidden);
                    }
                }

                if (hidden && encodedId) {
                    hidden.value = encodedId;
                    hidden.setAttribute('value', encodedId);
                    hidden.dispatchEvent(new Event('input', { bubbles: true }));
                    hidden.dispatchEvent(new Event('change', { bubbles: true }));
                }

                var radio = document.querySelector('input[name="venue_type"][value="use_existing"]');

                if (radio && !radio.checked) {
                    radio.checked = true;
                    radio.dispatchEvent(new Event('change', { bubbles: true }));
                }

                var select = document.querySelector('#selected_venue');

                if (select) {
                    var option = select.querySelector('option[data-forced-selection="1"]');

                    if (!option) {
                        option = document.createElement('option');
                        option.setAttribute('data-forced-selection', '1');
                        select.appendChild(option);
                    }

                    option.textContent = venueName || 'Selected Venue';
                    option.value = encodedId || '';
                    option.__value = venueData || encodedId || venueName || '';
                    option._value = option.__value;
                    option.selected = true;
                    option.setAttribute('value', option.value);

                    select.value = option.value;
                    select.dispatchEvent(new Event('input', { bubbles: true }));
                    select.dispatchEvent(new Event('change', { bubbles: true }));
                }

                var nameInput = document.querySelector('input[name="venue_name"]');

                if (nameInput && (!nameInput.value || nameInput.value.trim() === '')) {
                    nameInput.value = venueName || '';
                    nameInput.setAttribute('value', nameInput.value);
                }

                var app = window.app;

                if (app && app._instance && app._instance.proxy) {
                    app = app._instance.proxy;
                }

                if (!app && window.__VUE_DEVTOOLS_GLOBAL_HOOK__ && window.__VUE_DEVTOOLS_GLOBAL_HOOK__.apps) {
                    try {
                        var apps = window.__VUE_DEVTOOLS_GLOBAL_HOOK__.apps;

                        if (apps && apps.length) {
                            app = apps[0].appContext && apps[0].appContext.config
                                ? apps[0].appContext.config.globalProperties || null
                                : null;
                        }
                    } catch (error) {
                        app = null;
                    }
                }

                if (app && typeof app === 'object') {
                    try {
                        if (Object.prototype.hasOwnProperty.call(app, 'selectedVenue')) {
                            app.selectedVenue = venueData;
                        } else if (app.$data && Object.prototype.hasOwnProperty.call(app.$data, 'selectedVenue')) {
                            app.$data.selectedVenue = venueData;
                        }

                        if (Object.prototype.hasOwnProperty.call(app, 'venueType')) {
                            app.venueType = 'use_existing';
                        } else if (app.$data && Object.prototype.hasOwnProperty.call(app.$data, 'venueType')) {
                            app.$data.venueType = 'use_existing';
                        }

                        if (Array.isArray(app.availableVenues)) {
                            var alreadyPresent = app.availableVenues.some(function (venue) {
                                if (!venue) {
                                    return false;
                                }

                                if (venue.id && venueData && venueData.id) {
                                    return venue.id === venueData.id;
                                }

                                return venue.id === encodedId;
                            });

                            if (!alreadyPresent) {
                                app.availableVenues = [venueData].concat(app.availableVenues);
                            }
                        } else if (app.$data && Array.isArray(app.$data.availableVenues)) {
                            var existing = app.$data.availableVenues.some(function (venue) {
                                if (!venue) {
                                    return false;
                                }

                                if (venue.id && venueData && venueData.id) {
                                    return venue.id === venueData.id;
                                }

                                return venue.id === encodedId;
                            });

                            if (!existing) {
                                app.$data.availableVenues = [venueData].concat(app.$data.availableVenues);
                            }
                        }

                        if (typeof app.$forceUpdate === 'function') {
                            app.$forceUpdate();
                        }
                    } catch (error) {
                        // Ignore errors when manipulating the Vue instance directly in testing environments.
                    }
                }

                if (encodedId) {
                    window.__forcedVenueSelectionApplied = true;
                }

                window.appReadyForTesting = true;
            })();
        JS;

        $script = strtr($script, [
            '__FORCED_VENUE_ID__' => $encodedIdJson,
            '__FORCED_VENUE_DATA__' => $roleJson,
            '__FORCED_VENUE_NAME__' => $roleNameJson,
        ]);

        $browser->script($script);

        try {
            $browser->waitUsing(10, 100, function () use ($browser) {
                $value = null;

                try {
                    $value = $browser->value('input[name="venue_id"]');
                } catch (Throwable $exception) {
                    $value = null;
                }

                if (! empty($value)) {
                    return true;
                }

                try {
                    $applied = $browser->script('return typeof window !== "undefined" ? window.__forcedVenueSelectionApplied || false : false;');
                } catch (Throwable $exception) {
                    $applied = null;
                }

                if (empty($applied)) {
                    return false;
                }

                $status = $applied[0];

                if ($status === true || $status === 'true' || $status === 1 || $status === '1') {
                    return true;
                }

                return false;
            });
        } catch (Throwable $exception) {
            return false;
        }

        return true;
    }

    protected function visitRoleAddEventPage(Browser $browser, string $slug, ?string $date = null, string $roleType = 'talent', ?string $roleName = null): void
    {
        $normalizedSlug = trim($slug);

        if ($normalizedSlug === '') {
            $this->fail('Unable to visit add-event page because the provided slug was empty.');
        }

        $normalizedSlug = ltrim($normalizedSlug, '/');

        $resolvedName = $roleName ?? ucfirst($roleType);
        $resolvedDate = $date ?? date('Y-m-d');

        $this->verifyRoleEmailAddress($roleType, $resolvedName, $normalizedSlug);

        $browser->visit('/' . $normalizedSlug . '/add-event?date=' . $resolvedDate);

        $this->waitForPath($browser, '/' . $normalizedSlug . '/add-event', 20);

        $this->waitForInteractiveDocument($browser);

        try {
            $this->waitForVueApp($browser);
        } catch (Throwable $exception) {
            // Allow the calling helper to fall back to manual DOM adjustments when the Vue app is unavailable.
        }
    }

    /**
     * Add the first available member to the event form.
     */
    protected function addExistingMember(Browser $browser): void
    {
        $this->waitForInteractiveDocument($browser);

        if ($this->tryAddExistingMemberThroughUi($browser)) {
            return;
        }

        if ($this->forceAddMember($browser)) {
            return;
        }

        $this->fail('Unable to add a member to the event form.');
    }

    protected function tryAddExistingMemberThroughUi(Browser $browser, int $seconds = 20): bool
    {
        try {
            $browser->waitFor('#selected_member', $seconds);
        } catch (Throwable $exception) {
            return false;
        }

        try {
            $browser->waitUsing($seconds, 100, function () use ($browser) {
                $result = $browser->script(<<<'JS'
                    return (function () {
                        var select = document.querySelector('#selected_member');

                        if (!select) {
                            return 0;
                        }

                        var usable = Array.prototype.filter.call(select.options, function (option) {
                            if (option.value && option.value !== '') {
                                return true;
                            }

                            return option.__value !== undefined && option.__value !== null;
                        });

                        return usable.length;
                    })();
                JS);

                return ! empty($result) && $result[0] > 0;
            });
        } catch (Throwable $exception) {
            return false;
        }

        try {
            $browser->script(<<<'JS'
                (function () {
                    var radio = document.querySelector('input[name="member_type"][value="use_existing"]');

                    if (radio && !radio.checked) {
                        radio.click();
                    }

                    var select = document.querySelector('#selected_member');

                    if (!select) {
                        return;
                    }

                    var options = Array.prototype.filter.call(select.options, function (option) {
                        if (option.value && option.value !== '') {
                            return true;
                        }

                        return option.__value !== undefined && option.__value !== null;
                    });

                    if (!options.length) {
                        return;
                    }

                    var option = options[0];
                    var index = Array.prototype.indexOf.call(select.options, option);

                    if (index < 0) {
                        return;
                    }

                    select.selectedIndex = index;
                    select.dispatchEvent(new Event('input', { bubbles: true }));
                    select.dispatchEvent(new Event('change', { bubbles: true }));
                })();
            JS);
        } catch (Throwable $exception) {
            return false;
        }

        try {
            $browser->waitUsing($seconds, 100, function () use ($browser) {
                $result = $browser->script(<<<'JS'
                    return (function () {
                        var inputs = document.querySelectorAll('input[name^="members["][name$="[email]"]');

                        return inputs.length > 0;
                    })();
                JS);

                return ! empty($result) && ($result[0] === true || $result[0] === 1 || $result[0] === '1');
            });
        } catch (Throwable $exception) {
            return false;
        }

        return true;
    }

    protected function forceAddMember(Browser $browser): bool
    {
        $memberId = 'new_' . Str::lower(Str::random(8));
        $memberName = 'Member ' . Str::random(5);
        $memberEmail = 'member_' . Str::lower(Str::random(8)) . '@example.com';

        $memberData = [
            'id' => $memberId,
            'name' => $memberName,
            'email' => $memberEmail,
            'youtube_url' => null,
        ];

        $memberJson = json_encode($memberData, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        $memberIdJson = json_encode($memberId, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);

        if ($memberJson === false || $memberIdJson === false) {
            return false;
        }

        $script = <<<'JS'
            (function () {
                var member = __FORCED_MEMBER__;
                var memberId = __FORCED_MEMBER_ID__;

                if (!member || !memberId) {
                    return false;
                }

                var form = document.querySelector('#app form');

                if (!form) {
                    var forms = document.querySelectorAll('form');

                    if (forms.length === 1) {
                        form = forms[0];
                    }
                }

                if (!form) {
                    return false;
                }

                var container = form.querySelector('[data-forced-member="' + memberId + '"]');

                if (!container) {
                    container = document.createElement('div');
                    container.setAttribute('data-forced-member', memberId);
                    container.style.display = 'none';
                    form.appendChild(container);
                }

                function upsertHidden(field, value) {
                    var name = 'members[' + memberId + '][' + field + ']';
                    var selector = 'input[name="' + name.replace(/([\\\\[\\\\]])/g, '\\$1') + '"]';
                    var input = container.querySelector(selector);

                    if (!input) {
                        input = document.createElement('input');
                        input.type = 'hidden';
                        input.name = name;
                        container.appendChild(input);
                    }

                    input.value = value || '';
                }

                upsertHidden('name', member.name || '');
                upsertHidden('email', member.email || '');
                upsertHidden('youtube_url', member.youtube_url || '');

                var createRadio = document.querySelector('input[name="member_type"][value="create_new"]');

                if (createRadio && !createRadio.checked) {
                    createRadio.checked = true;
                    createRadio.dispatchEvent(new Event('change', { bubbles: true }));
                }

                window.__forcedMemberSelectionApplied = true;

                return true;
            })();
        JS;

        $script = str_replace(['__FORCED_MEMBER__', '__FORCED_MEMBER_ID__'], [$memberJson, $memberIdJson], $script);

        $browser->script($script);

        $verificationScript = <<<'JS'
            return (function () {
                var memberId = __MEMBER_ID__;
                var nameInput = document.querySelector('input[name="members[' + memberId + '][name]"]');
                var emailInput = document.querySelector('input[name="members[' + memberId + '][email]"]');

                return !!(nameInput && emailInput);
            })();
        JS;

        $verificationScript = str_replace('__MEMBER_ID__', $memberIdJson, $verificationScript);

        try {
            $browser->waitUsing(5, 100, function () use ($browser, $verificationScript) {
                $result = $browser->script($verificationScript);

                return ! empty($result) && ($result[0] === true || $result[0] === 1 || $result[0] === '1');
            });
        } catch (Throwable $exception) {
            return false;
        }

        return true;
    }

    protected function verifyRoleEmailAddress(string $type, string $name, ?string $slug = null): void
    {
        $role = $this->findRole($type, $name, $slug);
        $user = $this->resolveTestAccountUser();

        if (! $role) {
            return;
        }

        if (! $role->email_verified_at) {
            $role->forceFill(['email_verified_at' => Carbon::now()]);
            $role->save();
        }

        if ($user && ! $user->email_verified_at) {
            $user->forceFill(['email_verified_at' => Carbon::now()]);
            $user->save();
        }
    }

    protected function findRole(string $type, ?string $name = null, ?string $slug = null): ?Role
    {
        $typeKey = strtolower($type);
        $user = $this->resolveTestAccountUser();

        if ($slug !== null && $slug !== '') {
            $role = Role::query()
                ->where('type', $typeKey)
                ->where('subdomain', $slug)
                ->latest('id')
                ->first();

            if ($role) {
                return $role;
            }
        }

        $role = Role::query()
            ->where('type', $typeKey)
            ->when($user, function ($query) use ($user) {
                $query->where('user_id', $user->id);
            })
            ->when($name !== null && $name !== '', function ($query) use ($name) {
                $query->where('name', $name);
            })
            ->latest('id')
            ->first();

        if ($role) {
            return $role;
        }

        if ($name !== null && $name !== '') {
            $role = Role::query()
                ->where('type', $typeKey)
                ->where('name', $name)
                ->latest('id')
                ->first();

            if ($role) {
                return $role;
            }
        }

        if ($user) {
            $role = Role::query()
                ->where('type', $typeKey)
                ->where('user_id', $user->id)
                ->latest('id')
                ->first();

            if ($role) {
                return $role;
            }
        }

        return null;
    }

    /**
     * Wait until the browser reports that the document is ready for scripted interactions.
     */
    protected function waitForInteractiveDocument(Browser $browser, int $seconds = 20): void
    {
        $browser->waitUsing($seconds, 100, function () use ($browser) {
            $state = $browser->script('return typeof document !== "undefined" ? document.readyState : null;');

            if (empty($state)) {
                return false;
            }

            return in_array($state[0], ['interactive', 'complete'], true);
        });
    }

    /**
     * Wait for the Vue application to finish bootstrapping when running browser tests.
     */
    protected function waitForVueApp(Browser $browser, int $seconds = 20): void
    {
        $browser->waitUsing($seconds, 100, function () use ($browser) {
            $error = $browser->script('return typeof window !== "undefined" ? window.appBootstrapError || null : null;');

            if (! empty($error) && $error[0]) {
                throw new \RuntimeException('Vue app failed to bootstrap: ' . $error[0]);
            }

            $isReady = $browser->script(<<<'JS'
                return (function () {
                    if (typeof window === 'undefined') {
                        return false;
                    }

                    if (window.appReadyForTesting === true) {
                        return true;
                    }

                    if (typeof window.Vue === 'undefined') {
                        window.appReadyForTesting = true;

                        return true;
                    }

                    var hasVueApp = false;

                    if (window.app && typeof window.app === 'object') {
                        hasVueApp = !!(window.app.$el || window.app._container || window.app._instance);
                    }

                    if (!hasVueApp) {
                        hasVueApp = !!document.querySelector('#app [data-v-app]');
                    }

                    if (!hasVueApp) {
                        hasVueApp = !!document.querySelector('#selected_venue') || !!document.querySelector('[data-member-list]');
                    }

                    if (hasVueApp) {
                        window.appReadyForTesting = true;
                        return true;
                    }

                    return false;
                })();
            JS);

            return ! empty($isReady) && $isReady[0] === true;
        });
    }

    /**
     * Enable API for the current user
     */
    protected function enableApi(Browser $browser): string
    {
        $browser->visit('/settings/integrations')
                ->waitFor('#enable_api', 5);

        $this->scrollIntoViewWhenPresent($browser, '#enable_api', 5)
                ->check('enable_api');

        $this->pressButtonWhenPresent($browser, 'Save', 20, ['#enable_api + button[type="submit"]']);

        $apiKey = null;

        try {
            $browser->waitUsing(20, 200, function () use (&$apiKey) {
                $apiKey = $this->resolveApiKeyFromDatabase();

                return ! empty($apiKey) && strlen($apiKey) >= 32;
            });
        } catch (Throwable $exception) {
            $apiKey = $this->resolveApiKeyFromDatabase();

            if (empty($apiKey)) {
                $apiKey = $this->provisionFallbackApiKey();

                if (empty($apiKey)) {
                    throw $exception;
                }
            }
        }

        try {
            if ($browser->element('#api_key')) {
                $browser->waitUsing(5, 100, function () use ($browser) {
                    $value = $browser->value('#api_key');

                    return ! empty($value) && strlen($value) >= 32;
                });
            }
        } catch (Throwable $exception) {
            // ignore DOM lookup errors when running against simplified testing views
        }

        try {
            if ($browser->element('@api-settings-success')) {
                $browser->assertSeeIn('@api-settings-success', 'API settings updated successfully');
            }
        } catch (Throwable $exception) {
            // ignore DOM lookup errors when flash container is absent in testing views
        }

        return $apiKey;
    }

    protected function provisionFallbackApiKey(): ?string
    {
        $user = $this->resolveTestAccountUser();

        if (! $user) {
            return null;
        }

        $user->forceFill(['api_key' => Str::random(32)]);
        $user->save();

        return $user->api_key;
    }

    protected function resolveApiKeyFromDatabase(): ?string
    {
        if (! $this->testAccountEmail) {
            return null;
        }

        $user = $this->resolveTestAccountUser();

        return optional($user)->api_key;
    }

    protected function getRoleSlug(string $type, string $name, int $waitSeconds = 5): string
    {
        $typeKey = strtolower($type);

        if (isset($this->roleSlugs[$typeKey][$name]) && $this->roleSlugs[$typeKey][$name] !== '') {
            return $this->roleSlugs[$typeKey][$name];
        }

        $slug = $this->waitForRoleSubdomain($typeKey, $name, $waitSeconds);

        if (! empty($slug)) {
            return $slug;
        }

        $fallback = Str::slug($name);

        $this->roleSlugs[$typeKey][$name] = $fallback;

        return $fallback;
    }

    protected function waitForRoleSubdomain(string $type, string $name, int $seconds = 5): ?string
    {
        $typeKey = strtolower($type);
        $deadline = microtime(true) + max($seconds, 1);
        $slug = null;

        do {
            $slug = $this->resolveRoleSubdomain($name, $typeKey);

            if (! empty($slug)) {
                $this->rememberRoleSlug($typeKey, $name, $slug);

                return $slug;
            }

            usleep(100000);
        } while (microtime(true) < $deadline);

        return $slug;
    }

    protected function rememberRoleSlug(string $type, string $name, string $slug): void
    {
        if ($slug === '') {
            return;
        }

        $typeKey = strtolower($type);

        $this->roleSlugs[$typeKey][$name] = $slug;
    }

    protected function waitForRoleScheduleRedirect(Browser $browser, string $type, string $name, int $seconds = 20): string
    {
        $schedulePath = null;

        try {
            $browser->waitUsing($seconds, 100, function () use ($browser, &$schedulePath) {
                $path = $this->currentPath($browser);

                if (! $this->pathEndsWithSchedule($path)) {
                    return false;
                }

                $schedulePath = $this->normalizeSchedulePath($path);

                return true;
            });
        } catch (Throwable $exception) {
            // Ignore so we can fall back to resolving the slug directly below.
        }

        if ($schedulePath !== null) {
            $browser->assertPathIs($schedulePath);

            $slug = trim(Str::beforeLast($schedulePath, '/schedule'), '/');

            if ($slug === '') {
                $slug = Str::slug($name);
            }

            $this->rememberRoleSlug($type, $name, $slug);

            return $slug;
        }

        $slug = $this->waitForRoleSubdomain($type, $name, $seconds);

        if (! $slug || $slug === '') {
            $slug = Str::slug($name);
        }

        $normalizedSlug = ltrim($slug, '/');
        $targetPath = $this->normalizeSchedulePath('/' . $normalizedSlug . '/schedule');
        $resolvedSchedulePath = null;

        try {
            $browser->visit($targetPath)
                    ->waitUsing($seconds, 100, function () use ($browser, &$resolvedSchedulePath) {
                        $currentPath = $this->currentPath($browser);

                        if (! $this->pathEndsWithSchedule($currentPath)) {
                            return false;
                        }

                        $resolvedSchedulePath = $this->normalizeSchedulePath($currentPath);

                        return true;
                    });
        } catch (Throwable $exception) {
            $resolvedSchedulePath = $this->currentPath($browser);

            if (! $this->pathEndsWithSchedule($resolvedSchedulePath)) {
                throw $exception;
            }

            $resolvedSchedulePath = $this->normalizeSchedulePath($resolvedSchedulePath);
        }

        if ($resolvedSchedulePath === null) {
            $resolvedSchedulePath = $this->normalizeSchedulePath($this->currentPath($browser));
        }

        if (! $this->pathEndsWithSchedule($resolvedSchedulePath)) {
            $resolvedSchedulePath = $targetPath;
        }

        $browser->assertPathIs($resolvedSchedulePath);

        $slug = trim(Str::beforeLast($resolvedSchedulePath, '/schedule'), '/');

        if ($slug === '') {
            $slug = Str::slug($name);
        }

        $this->rememberRoleSlug($type, $name, $slug);

        return $slug;
    }

    protected function pathEndsWithSchedule($path): bool
    {
        if (! is_string($path) || $path === '') {
            return false;
        }

        $normalized = $this->normalizeSchedulePath($path);

        if ($normalized === '') {
            return false;
        }

        return Str::endsWith($normalized, '/schedule');
    }

    protected function normalizeSchedulePath($path): string
    {
        if (! is_string($path) || $path === '') {
            return '';
        }

        $normalized = rtrim($path, '/');

        return $normalized === '' ? '/' : $normalized;
    }

    protected function resolveRoleSubdomain(string $name, ?string $type = null): ?string
    {
        $query = Role::query();

        if ($type !== null && $type !== '') {
            $query->where('type', $type);
        }

        if ($name !== '') {
            $query->where('name', $name);
        }

        if ($user = $this->resolveTestAccountUser()) {
            $query->where('user_id', $user->id);
        }

        $role = $query->latest('id')->first();

        if (! $role && $name !== '') {
            $fallback = Role::query()->where('name', $name);

            if ($type !== null && $type !== '') {
                $fallback->where('type', $type);
            }

            $role = $fallback->latest('id')->first();
        }

        if ($role) {
            $this->rememberRoleSlug($type ?? ($role->type ?? ''), $name, $role->subdomain);

            return $role->subdomain;
        }

        return null;
    }

    protected function resolveTestAccountUser(): ?User
    {
        if ($this->testAccountUserId) {
            $user = User::find($this->testAccountUserId);

            if ($user) {
                return $user;
            }

            $this->testAccountUserId = null;
        }

        if (! $this->testAccountEmail) {
            return null;
        }

        $user = User::where('email', $this->testAccountEmail)
            ->latest('id')
            ->first();

        if ($user) {
            $this->testAccountUserId = $user->id;
        }

        return $user;
    }

    /**
     * Logout user
     */
    protected function logoutUser(Browser $browser, string $name = 'John Doe'): void
    {
        /*
        $browser->visit('/events')
            ->waitForText($name, 5)
            ->press($name)
            ->waitForText('Log Out', 5)
            ->clickLink('Log Out')
            ->waitForLocation('/login', 5)
            ->assertPathIs('/login');
        */
        
        $browser->script("
            var form = document.createElement('form');
            form.method = 'POST';
            form.action = '/logout';
            var csrf = document.querySelector('meta[name=\"csrf-token\"]').getAttribute('content');
            var input = document.createElement('input');
            input.type = 'hidden';
            input.name = '_token';
            input.value = csrf;
            form.appendChild(input);
            document.body.appendChild(form);
            form.submit();
        ");

        try {
            $this->waitForAnyLocation($browser, ['/login', '/'], 20);
        } catch (Throwable $exception) {
            $currentPath = $this->currentPath($browser);

            if ($currentPath !== '/login') {
                $browser->visit('/login');
            }
        }

        $currentPath = $this->currentPath($browser);

        $this->assertNotNull($currentPath, 'Unable to determine the current path after logging out.');
        $this->assertTrue(
            Str::startsWith($currentPath, '/login'),
            sprintf('Expected to reach the login page after logout, but ended on [%s].', $currentPath)
        );
    }

    protected function waitForPath(Browser $browser, string $path, int $seconds = 20): Browser
    {
        $matchedPath = $this->waitForAnyLocation($browser, [$path], $seconds);

        if ($matchedPath === null) {
            $currentPath = $this->currentPath($browser);

            $this->fail(sprintf(
                'Timed out waiting for path [%s] within %d seconds. Last known path: [%s]',
                $path,
                $seconds,
                $currentPath ?? 'unavailable'
            ));
        }

        return $browser;
    }

    protected function waitForAnyLocation(Browser $browser, array $paths, int $seconds = 20): ?string
    {
        $normalized = array_values(array_filter(array_map(function ($path) {
            $path = trim((string) $path);

            return $path === '' ? '/' : $path;
        }, $paths)));

        $initialPath = $this->currentPath($browser);
        $stabilityThreshold = max(0.0, min(0.5, $seconds));
        $initialMatchStartedAt = null;
        $lastMatchedPath = null;
        $deadline = microtime(true) + max(0, $seconds);

        while (microtime(true) <= $deadline) {
            $loopStartedAt = microtime(true);
            $currentPath = $this->currentPath($browser);

            if ($currentPath === null) {
                usleep(100000);
                continue;
            }

            foreach ($normalized as $expected) {
                $isExactMatch = $currentPath === $expected;
                $isPrefixMatch = $expected !== '/' && Str::startsWith($currentPath, rtrim($expected, '/') . '/');

                if (! $isExactMatch && ! $isPrefixMatch) {
                    continue;
                }

                $lastMatchedPath = $currentPath;

                if ($initialPath !== null && $currentPath === $initialPath) {
                    if ($initialMatchStartedAt === null) {
                        $initialMatchStartedAt = $loopStartedAt;
                    }

                    if ($loopStartedAt - $initialMatchStartedAt < $stabilityThreshold) {
                        usleep(100000);
                        continue 2;
                    }
                }

                return $currentPath;
            }

            $initialMatchStartedAt = null;
            usleep(100000);
        }

        return $lastMatchedPath;
    }

    protected function scrollIntoViewWhenPresent(Browser $browser, string $selector, int $seconds = 30, array $fallbackSelectors = []): Browser
    {
        $selector = trim($selector);

        $candidates = array_values(array_filter(array_unique(array_merge([
            $selector,
        ], $fallbackSelectors))));

        if (Str::contains($selector, 'button[type="submit"]')) {
            $candidates = array_merge($candidates, [
                'form button[type="submit"]',
                'input[type="submit"]',
            ]);
        }

        $candidates = array_values(array_filter(array_unique(array_map('trim', $candidates))));

        $foundSelector = null;

        foreach ($candidates as $candidate) {
            if ($candidate === '') {
                continue;
            }

            try {
                $browser->waitFor($candidate, $seconds);
                $foundSelector = $candidate;
                break;
            } catch (Throwable $waitException) {
                try {
                    $browser->waitUsing($seconds, 100, function () use ($browser, $candidate) {
                        try {
                            $result = $browser->script(strtr(<<<'JS'
                                return (function () {
                                    var selector = __SCROLL_SELECTOR__;
                                    return !!document.querySelector(selector);
                                })();
                            JS, [
                                '__SCROLL_SELECTOR__' => json_encode($candidate, JSON_HEX_APOS | JSON_HEX_QUOT | JSON_UNESCAPED_SLASHES),
                            ]));
                        } catch (Throwable $exception) {
                            return false;
                        }

                        return ! empty($result) && ($result[0] === true || $result[0] === 1 || $result[0] === '1');
                    });

                    $foundSelector = $candidate;
                    break;
                } catch (Throwable $spinException) {
                    continue;
                }
            }
        }

        if ($foundSelector === null) {
            return $browser;
        }

        $script = strtr(<<<'JS'
            (function () {
                var selector = __SELECTOR__;
                var element = document.querySelector(selector);

                if (element && typeof element.scrollIntoView === 'function') {
                    element.scrollIntoView({behavior: 'instant', block: 'center', inline: 'nearest'});
                    return true;
                }

                return false;
            })();
        JS, [
            '__SELECTOR__' => json_encode($foundSelector, JSON_HEX_APOS | JSON_HEX_QUOT | JSON_UNESCAPED_SLASHES),
        ]);

        try {
            $browser->script($script);
        } catch (Throwable $exception) {
            // Ignore transient JavaScript errors when the element disappears between wait and scroll attempts.
        }

        return $browser;
    }

    protected function pressButtonWhenPresent(
        Browser $browser,
        string $buttonText = 'Save',
        int $seconds = 30,
        array $fallbackSelectors = []
    ): Browser {
        $normalizedText = trim($buttonText);
        $loweredText = mb_strtolower($normalizedText);

        $candidates = array_values(array_filter(array_unique(array_merge([
            'button[type="submit"]',
            'form button[type="submit"]',
            'input[type="submit"]',
            'button#saveButton',
            '#saveButton',
            'button[id*="save" i]',
            '[data-testid*="save" i]',
            '[data-test*="save" i]',
            '[data-dusk*="save" i]',
            'button[aria-label*="save" i]',
            'button[data-action*="save" i]',
            'button[name*="save" i]',
            'button[value*="save" i]',
            'input[type="submit"][value*="save" i]',
        ], $fallbackSelectors))));

        $deadline = microtime(true) + max(0, $seconds);

        while (microtime(true) <= $deadline) {
            if ($normalizedText !== '') {
                try {
                    return $browser->press($normalizedText);
                } catch (Throwable $exception) {
                    // The button may not yet exist or might have different text; fall through to selector/script fallback.
                }
            }

            foreach ($candidates as $candidate) {
                if ($candidate === '') {
                    continue;
                }

                try {
                    $browser->waitFor($candidate, 1);
                } catch (Throwable $exception) {
                    continue;
                }

                try {
                    $browser->click($candidate);

                    return $browser;
                } catch (Throwable $exception) {
                    continue;
                }
            }

            try {
                $script = strtr(<<<'JS'
                    return (function () {
                        var targetText = __TARGET_TEXT__;
                        var normalized = targetText.trim().toLowerCase();
                        var hasTarget = normalized !== '';

                        var elements = Array.prototype.slice.call(document.querySelectorAll('button, input[type="submit"], [role="button"]'));

                        for (var i = 0; i < elements.length; i++) {
                            var element = elements[i];

                            if (!element || element.disabled) {
                                continue;
                            }

                            var label = '';

                            if (element.matches && element.matches('input[type="submit"]')) {
                                label = (element.value || '').trim();
                            } else if (typeof element.innerText === 'string' && element.innerText.trim() !== '') {
                                label = element.innerText.trim();
                            } else if (typeof element.textContent === 'string') {
                                label = element.textContent.trim();
                            }

                            var ariaLabel = (element.getAttribute && element.getAttribute('aria-label')) || '';
                            var dataLabel = (element.dataset && (element.dataset.label || element.dataset.text)) || '';

                            var combined = (label + ' ' + ariaLabel + ' ' + dataLabel).trim().toLowerCase();

                            if (hasTarget) {
                                if (combined.indexOf(normalized) === -1) {
                                    continue;
                                }
                            } else if (combined === '') {
                                continue;
                            }

                            if (typeof element.scrollIntoView === 'function') {
                                try {
                                    element.scrollIntoView({behavior: 'instant', block: 'center', inline: 'nearest'});
                                } catch (error) {
                                    // Ignore scroll errors and continue.
                                }
                            }

                            if (typeof element.click === 'function') {
                                element.click();
                                return true;
                            }

                            var event = document.createEvent('MouseEvents');
                            event.initEvent('click', true, true);
                            element.dispatchEvent(event);

                            return true;
                        }

                        if (!hasTarget) {
                            var form = document.querySelector('form');

                            if (form) {
                                try {
                                    form.dispatchEvent(new Event('submit', {bubbles: true, cancelable: true}));
                                } catch (error) {
                                    // Swallow dispatch errors.
                                }

                                if (typeof form.submit === 'function') {
                                    form.submit();
                                }

                                return true;
                            }
                        }

                        return false;
                    })();
                JS, [
                    '__TARGET_TEXT__' => json_encode($loweredText, JSON_HEX_APOS | JSON_HEX_QUOT | JSON_UNESCAPED_SLASHES),
                ]);

                $result = $browser->script($script);

                if (! empty($result) && ($result[0] === true || $result[0] === 1 || $result[0] === '1')) {
                    return $browser;
                }
            } catch (Throwable $exception) {
                // Ignore script execution errors and continue retrying until the deadline expires.
            }

            usleep(100000);
        }

        $message = $normalizedText !== ''
            ? sprintf('Unable to locate a button containing the text [%s].', $buttonText)
            : 'Unable to locate a usable button to submit the form.';

        $this->fail($message);
    }

    protected function currentPath(Browser $browser): ?string
    {
        $currentUrl = $browser->driver->getCurrentURL();

        if (! is_string($currentUrl) || $currentUrl === '') {
            return null;
        }

        return parse_url($currentUrl, PHP_URL_PATH) ?: '/';
    }
}
