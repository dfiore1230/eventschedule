<x-app-layout :title="(request()->path() != '/' ? implode(' > ', array_map('ucwords', array_slice(explode('/', str_replace(['-', '_'], ' ', request()->path())), 0, 2))) : '') . ' | Event Schedule'">

    <x-slot name="head">
        <link rel="preconnect" href="https://rsms.me/">
        <link rel="stylesheet" href="https://rsms.me/inter/inter.css">        

        <script {!! nonce_attr() !!}>
            $(document).ready(function() {
                const sidebar = document.getElementById('sidebar');
                const openButton = document.getElementById('open-sidebar');
                const closeButton = document.getElementById('close-sidebar');

                function toggleMenu() {
                    const isOpen = sidebar.getAttribute('data-state') === 'open';
                    if (isOpen) {
                        $('#sidebar').hide();
                        sidebar.setAttribute('data-state', 'closed');
                    } else {
                        $('#sidebar').show();
                        sidebar.setAttribute('data-state', 'open');
                    }
                }

                openButton.addEventListener('click', toggleMenu);
                closeButton.addEventListener('click', toggleMenu);

                $('[data-collapse-trigger]').each(function() {
                    const $trigger = $(this);
                    const $container = $trigger.closest('[data-collapse-container]');
                    const contentId = $trigger.attr('aria-controls');
                    let $content = $container.find('[data-collapse-content]');

                    if (contentId) {
                        $content = $content.filter(function() {
                            return $(this).attr('id') === contentId;
                        });
                    }
                    const $icon = $trigger.find('[data-collapse-icon]');
                    const initialOpen = $container.attr('data-collapse-state') === 'open';

                    const setState = function(isOpen) {
                        if ($content.length) {
                            if (isOpen) {
                                $content.removeClass('hidden');
                            } else {
                                $content.addClass('hidden');
                            }
                        }

                        $container.attr('data-collapse-state', isOpen ? 'open' : 'closed');
                        $trigger.attr('aria-expanded', isOpen ? 'true' : 'false');

                        if ($icon.length) {
                            if (isOpen) {
                                $icon.addClass('rotate-180');
                            } else {
                                $icon.removeClass('rotate-180');
                            }
                        }
                    };

                    setState(initialOpen);

                    $trigger.on('click', function() {
                        const isOpen = $container.attr('data-collapse-state') === 'open';
                        setState(!isOpen);
                    });
                });
            });
        </script>

        {{ isset($head) ? $head : '' }}
    </x-slot>

    <div>
        <!-- Off-canvas menu for mobile, show/hide based on off-canvas menu state. -->
        <div data-state="closed" id="sidebar" class="relative z-50 hidden" role="dialog" aria-modal="true">
            <div class="fixed inset-0 bg-gray-900/80" aria-hidden="true"></div>

            <div class="fixed inset-0 flex">
                <div class="relative mr-16 flex w-full max-w-xs flex-1">
                    <div class="absolute left-full top-0 flex w-16 justify-center pt-5">
                        <button id="close-sidebar" type="button" class="-m-2.5 p-2.5">
                            <span class="sr-only">{{ __('messages.close_sidebar') }}</span>
                            <svg class="h-6 w-6 text-white" fill="none" viewBox="0 0 24 24" stroke-width="1.5"
                                stroke="currentColor" aria-hidden="true">
                                <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
                            </svg>
                        </button>
                    </div>

                    <!-- Sidebar component, swap this element with another sidebar if you like -->
                    <div class="flex grow flex-col gap-y-5 overflow-y-auto bg-gray-900 px-6 pb-4 ring-1 ring-white/10">

                        @include('layouts.navigation')                        

                    </div>
                </div>
            </div>
        </div>

        <!-- Static sidebar for desktop -->
        <div class="hidden lg:fixed lg:inset-y-0 lg:z-50 lg:flex lg:w-72 lg:flex-col">
            <!-- Sidebar component, swap this element with another sidebar if you like -->
            <div class="flex grow flex-col gap-y-5 overflow-y-auto bg-gray-900 px-6 pb-4">

                @include('layouts.navigation')

            </div>
        </div>

        <div class="lg:pl-72 flex flex-col min-h-screen">
            <div
                class="sticky top-0 z-40 flex h-16 shrink-0 items-center gap-x-4 border-b border-gray-200 bg-white px-4 shadow-sm sm:gap-x-6 sm:px-6 lg:px-8">
                <button id="open-sidebar" type="button" class="-m-2.5 p-2.5 text-gray-700 lg:hidden">
                    <span class="sr-only">{{ __('messages.open_sidebar') }}</span>
                    <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor"
                        aria-hidden="true">
                        <path stroke-linecap="round" stroke-linejoin="round"
                            d="M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5" />
                    </svg>
                </button>

                <!-- Separator -->
                <div class="h-6 w-px bg-gray-900/10 lg:hidden" aria-hidden="true"></div>

                <div class="flex flex-1 gap-x-4 self-stretch lg:gap-x-6">
                    <div class="relative flex flex-1"></div>
                    <!--
                    <form class="relative flex flex-1" action="#" method="GET">
                    <label for="search-field" class="sr-only">Search</label>
                    <svg class="pointer-events-none absolute inset-y-0 left-0 h-full w-5 text-gray-400" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
                        <path fill-rule="evenodd" d="M9 3.5a5.5 5.5 0 100 11 5.5 5.5 0 000-11zM2 9a7 7 0 1112.452 4.391l3.328 3.329a.75.75 0 11-1.06 1.06l-3.329-3.328A7 7 0 012 9z" clip-rule="evenodd" />
                    </svg>
                    <input id="search-field" class="block h-full w-full border-0 py-0 pl-8 pr-0 text-gray-900 placeholder:text-gray-400 focus:ring-0 sm:text-sm" placeholder="Search..." type="search" name="search">
                    </form>
                    -->
                    <div class="flex items-center gap-x-4 lg:gap-x-6">

                        <!--
                        <button type="button" class="-m-2.5 p-2.5 text-gray-400 hover:text-gray-500">
                            <span class="sr-only">View notifications</span>
                            <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke-width="1.5"
                                stroke="currentColor" aria-hidden="true">
                                <path stroke-linecap="round" stroke-linejoin="round"
                                    d="M14.857 17.082a23.848 23.848 0 005.454-1.31A8.967 8.967 0 0118 9.75v-.7V9A6 6 0 006 9v.75a8.967 8.967 0 01-2.312 6.022c1.733.64 3.56 1.085 5.455 1.31m5.714 0a24.255 24.255 0 01-5.714 0m5.714 0a3 3 0 11-5.714 0" />
                            </svg>
                        </button>
                        -->

                        <!-- Separator -->
                        <div class="hidden lg:block lg:h-6 lg:w-px lg:bg-gray-900/10" aria-hidden="true"></div>


                        <!-- Settings Dropdown -->
                        <div class="sm:flex sm:items-center sm:ms-6">
                            <x-dropdown align="right" width="48">
                                <x-slot name="trigger">
                                    @php
                                        $authenticatedUser = Auth::user();
                                        $userName = trim((string) data_get($authenticatedUser, 'name', ''));
                                        $userEmail = trim((string) data_get($authenticatedUser, 'email', ''));
                                        $displayName = $userName !== '' ? $userName : $userEmail;
                                    @endphp
                                    <button
                                        class="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-gray-500 bg-white hover:text-gray-700 focus:outline-none transition ease-in-out duration-150">
                                        <div>{{ $displayName }}</div>

                                        <div class="ms-1">
                                            <svg class="fill-current h-4 w-4" xmlns="http://www.w3.org/2000/svg"
                                                viewBox="0 0 24 24">
                                                <path fill-rule="evenodd"
                                                    d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z"
                                                    clip-rule="evenodd" />
                                            </svg>
                                        </div>
                                    </button>
                                </x-slot>

                                <x-slot name="content">
                                    <x-dropdown-link :href="route('profile.edit')">
                                        {{ __('messages.manage_account') }}
                                    </x-dropdown-link>

                                    <!-- Authentication -->
                                    <form method="POST" action="{{ route('logout') }}">
                                        @csrf

                                        <x-dropdown-link :href="route('logout')" onclick="event.preventDefault();
                                                this.closest('form').submit();">
                                            {{ __('messages.log_out') }}
                                        </x-dropdown-link>
                                    </form>
                                </x-slot>
                            </x-dropdown>
                        </div>

                    </div>
                </div>
            </div>

            <main class="pb-10">
                <div class="px-4 sm:px-6 lg:px-8">

                    @if ($errors->any())
                    <div class="p-4 sm:p-8 bg-white dark:bg-gray-800 shadow-md sm:rounded-lg">
                        <b>{{ __('messages.there_was_a_problem') . ':' }}</b>
                        <ul>
                            @foreach ($errors->all() as $error)
                            <li>{{ $error }}</li>
                            @endforeach
                        </ul>
                    </div>
                    @endif

                    {{ $slot }}

                </div>
            </main>

            <div class="mt-auto pb-8 px-8 text-sm text-gray-500">                
                @if (config('app.hosted'))                
                    {!! str_replace(':email', '<a href="mailto:contact@eventschedule.com?subject=Feedback" class="hover:underline">contact@eventschedule.com</a>', __('messages.questions_or_suggestions')) !!}
                @else
                    <!-- Per the AAL license, please do not remove the link to Event Schedule -->
                    {!! str_replace(':link', '<a href="https://www.eventschedule.com" class="hover:underline" target="_blank">eventschedule.com</a>', __('messages.powered_by_eventschedule')) !!} 
                    • 
                    <a href="{{ config('self-update.repository_types.github.repository_url') }}" target="_blank" class="hover:underline">{{ config('self-update.version_installed') }}</a>
                @endif
            </div>

        </div>
    </div>

</x-app-layout>
