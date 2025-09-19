@php
    $schedules = isset($schedules) ? $schedules : collect();
    $venues = isset($venues) ? $venues : collect();
    $curators = isset($curators) ? $curators : collect();
@endphp

<a href="https://www.eventschedule.com">
    <div class="flex h-16 pt-2 shrink-0 items-center">
        <img class="h-10 w-auto" src="{{ url('images/light_logo.png') }}"
            alt="Event Schedule">
    </div>
</a>
<nav class="flex flex-1 flex-col">
    <ul role="list" class="flex flex-1 flex-col gap-y-7">
        <li>
            <ul role="list" class="-mx-2 space-y-1">

            <li>
                    <a href="{{ route('home') }}"
                        class="group flex gap-x-3 rounded-md p-2 text-sm font-semibold leading-6 text-gray-400 hover:bg-gray-800 hover:text-white {{ request()->is('events') ? 'bg-gray-800 text-white' : '' }}">
                        <svg class="h-6 w-6 shrink-0" viewBox="0 0 24 24"
                            fill="{{ request()->is('events') ? '#ccc' : '#666' }}" aria-hidden="true">
                            <path d="M9,10V12H7V10H9M13,10V12H11V10H13M17,10V12H15V10H17M19,3A2,2 0 0,1 21,5V19A2,2 0 0,1 19,21H5C3.89,21 3,20.1 3,19V5A2,2 0 0,1 5,3H6V1H8V3H16V1H18V3H19M19,19V8H5V19H19M9,14V16H7V14H9M13,14V16H11V14H13M17,14V16H15V14H17Z" />
                        </svg>
                        {{ __('messages.events') }}
                    </a>
                </li>

                <li>
                    <a href="{{ route('following') }}"
                        class="group flex gap-x-3 rounded-md p-2 text-sm font-semibold leading-6 text-gray-400 hover:bg-gray-800 hover:text-white {{ request()->is('following') ? 'bg-gray-800 text-white' : '' }}">
                        <svg class="h-6 w-6 shrink-0" viewBox="0 0 24 24"
                            fill="{{ request()->is('following') ? '#ccc' : '#666' }}" aria-hidden="true">
                            <path d="M7,5H21V7H7V5M7,13V11H21V13H7M4,4.5A1.5,1.5 0 0,1 5.5,6A1.5,1.5 0 0,1 4,7.5A1.5,1.5 0 0,1 2.5,6A1.5,1.5 0 0,1 4,4.5M4,10.5A1.5,1.5 0 0,1 5.5,12A1.5,1.5 0 0,1 4,13.5A1.5,1.5 0 0,1 2.5,12A1.5,1.5 0 0,1 4,10.5M7,19V17H21V19H7M4,16.5A1.5,1.5 0 0,1 5.5,18A1.5,1.5 0 0,1 4,19.5A1.5,1.5 0 0,1 2.5,18A1.5,1.5 0 0,1 4,16.5Z" />
                        </svg>
                        {{ __('messages.following') }}
                    </a>
                </li>

                <li>
                    <a href="{{ route('role.venues') }}"
                        class="group flex gap-x-3 rounded-md p-2 text-sm font-semibold leading-6 text-gray-400 hover:bg-gray-800 hover:text-white {{ request()->routeIs('role.venues') ? 'bg-gray-800 text-white' : '' }}">
                        <svg class="h-6 w-6 shrink-0" viewBox="0 0 24 24" fill="none"
                            stroke="{{ request()->routeIs('role.venues') ? '#ccc' : '#666' }}" stroke-width="1.5" aria-hidden="true">
                            <path stroke-linecap="round" stroke-linejoin="round"
                                d="M3 21h18M4.5 21V9l7.5-4.5L19.5 9V21M9 21v-6h6v6" />
                        </svg>
                        {{ __('messages.venues') }}
                    </a>
                </li>

                <li>
                    <a href="{{ route('role.curators') }}"
                        class="group flex gap-x-3 rounded-md p-2 text-sm font-semibold leading-6 text-gray-400 hover:bg-gray-800 hover:text-white {{ request()->routeIs('role.curators') ? 'bg-gray-800 text-white' : '' }}">
                        <svg class="h-6 w-6 shrink-0" viewBox="0 0 24 24"
                            fill="{{ request()->routeIs('role.curators') ? '#ccc' : '#666' }}" aria-hidden="true">
                            <path d="M12 4l2.47 5.02 5.53.8-4 3.91.94 5.5L12 16.9l-4.94 2.33.94-5.5-4-3.91 5.53-.8L12 4z" />
                        </svg>
                        {{ __('messages.curators') }}
                    </a>
                </li>

                <li>
                    <a href="{{ route('role.talent') }}"
                        class="group flex gap-x-3 rounded-md p-2 text-sm font-semibold leading-6 text-gray-400 hover:bg-gray-800 hover:text-white {{ request()->routeIs('role.talent') ? 'bg-gray-800 text-white' : '' }}">
                        <svg class="h-6 w-6 shrink-0" viewBox="0 0 24 24"
                            fill="{{ request()->routeIs('role.talent') ? '#ccc' : '#666' }}" aria-hidden="true">
                            <path d="M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8zm0 2c-3.33 0-6 2.24-6 5v1h12v-1c0-2.76-2.67-5-6-5z" />
                        </svg>
                        {{ \Illuminate\Support\Str::plural(__('messages.talent')) }}
                    </a>
                </li>

                @if (config('app.hosted'))
                <li>
                    <a href="{{ route('tickets') }}"
                        class="group flex gap-x-3 rounded-md p-2 text-sm font-semibold leading-6 text-gray-400 hover:bg-gray-800 hover:text-white {{ request()->is('tickets') ? 'bg-gray-800 text-white' : '' }}">
                        <svg class="h-6 w-6 shrink-0" viewBox="0 0 24 24"
                            fill="{{ request()->is('tickets') ? '#ccc' : '#666' }}" aria-hidden="true">
                            <path d="M13,8.5H11V6.5H13V8.5M13,13H11V11H13V13M13,17.5H11V15.5H13V17.5M22,10V6C22,4.89 21.1,4 20,4H4A2,2 0 0,0 2,6V10C3.11,10 4,10.9 4,12A2,2 0 0,1 2,14V18A2,2 0 0,0 4,20H20A2,2 0 0,0 22,18V14A2,2 0 0,1 20,12A2,2 0 0,1 22,10Z" />
                        </svg>
                        {{ __('messages.tickets') }}
                    </a>
                </li>
                @endif

                <li>
                    <a href="{{ route('sales') }}"
                        class="group flex gap-x-3 rounded-md p-2 text-sm font-semibold leading-6 text-gray-400 hover:bg-gray-800 hover:text-white {{ request()->is('sales') ? 'bg-gray-800 text-white' : '' }}">
                        <svg class="h-6 w-6 shrink-0" viewBox="0 0 24 24"
                            fill="{{ request()->is('sales') ? '#ccc' : '#666' }}" aria-hidden="true">
                            <path d="M20,8H4V6H20M20,18H4V12H20M20,4H4C2.89,4 2,4.89 2,6V18A2,2 0 0,0 4,20H20A2,2 0 0,0 22,18V6C22,4.89 21.1,4 20,4Z" />
                        </svg>
                        {{ __('messages.sales') }}
                    </a>
                </li>

                @if (config('app.hosted') && auth()->user()->isAdmin())
                <li>
                    <a href="{{ route('blog.admin.index') }}"
                        class="group flex gap-x-3 rounded-md p-2 text-sm font-semibold leading-6 text-gray-400 hover:bg-gray-800 hover:text-white {{ request()->is('admin/blog*') ? 'bg-gray-800 text-white' : '' }}">
                        <svg class="h-6 w-6 shrink-0" viewBox="0 0 24 24"
                            fill="{{ request()->is('admin/blog*') ? '#ccc' : '#666' }}" aria-hidden="true">
                            <path d="M19,3H5C3.89,3 3,3.89 3,5V19A2,2 0 0,0 5,21H19A2,2 0 0,0 21,19V5C21,3.89 20.1,3 19,3M19,19H5V5H19V19M17,17H7V15H17V17M17,13H7V11H17V13M17,9H7V7H17V9Z" />
                        </svg>
                        Blog
                    </a>
                </li>
                @endif

            </ul>
        </li>

    
        @if ($schedules->isNotEmpty())
        <li>
            <div class="text-xs font-semibold leading-6 text-gray-400">{{ __('messages.talent_schedules') }}</div>

            <ul role="list" class="-mx-2 mt-2 space-y-1">

                @foreach ($schedules as $each)
                <li>
                    <a href="{{ route('role.view_admin', ['subdomain' => $each->subdomain, 'tab' => $each->subdomain == request()->subdomain ? 'schedule' : (request()->tab ? request()->tab : 'schedule')]) }}"
                        class="group flex gap-x-3 rounded-md p-2 text-sm font-semibold leading-6 hover:bg-gray-800 hover:text-white {{ request()->is($each->subdomain) || request()->is($each->subdomain . '/*') ? 'bg-gray-800 text-white' : 'text-gray-400' }}">
                        <span
                            class="flex h-6 w-6 shrink-0 items-center justify-center rounded-lg border border-gray-700 bg-gray-800 text-[0.625rem] font-medium group-hover:text-white {{ request()->is($each->subdomain) || request()->is($each->subdomain . '/*') ? 'text-white' : 'text-gray-400' }}">{{ strtoupper(substr($each->name, 0, 1)) }}</span>
                        <span class="truncate">{{ $each->name }}</span>
                    </a>
                </li>
                @endforeach

            </ul>
        </li>
        @endif


        @if ($venues->isNotEmpty())
        <li>
            <div class="text-xs font-semibold leading-6 text-gray-400">{{ __('messages.venue_schedules') }}</div>

            <ul role="list" class="-mx-2 mt-2 space-y-1">

                @foreach ($venues as $venue)
                <li>
                    <a href="{{ route('role.view_admin', ['subdomain' => $venue->subdomain, 'tab' => $venue->subdomain == request()->subdomain ? 'schedule' : (request()->tab ? request()->tab : 'schedule')]) }}"
                        class="group flex gap-x-3 rounded-md p-2 text-sm font-semibold leading-6 hover:bg-gray-800 hover:text-white {{ request()->is($venue->subdomain) || request()->is($venue->subdomain . '/*') ? 'bg-gray-800 text-white' : 'text-gray-400' }}">
                        <span
                            class="flex h-6 w-6 shrink-0 items-center justify-center rounded-lg border border-gray-700 bg-gray-800 text-[0.625rem] font-medium group-hover:text-white {{ request()->is($venue->subdomain) || request()->is($venue->subdomain . '/*') ? 'text-white' : 'text-gray-400' }}">{{ strtoupper(substr($venue->name, 0, 1)) }}</span>
                        <span class="truncate">{{ $venue->name }}</span>
                    </a>
                </li>
                @endforeach

            </ul>
        </li>
        @endif

        @if ($curators->isNotEmpty())
        <li>
            <div class="text-xs font-semibold leading-6 text-gray-400">{{ __('messages.curator_schedules') }}</div>

            <ul role="list" class="-mx-2 mt-2 space-y-1">

                @foreach ($curators as $curator)
                <li>
                    <a href="{{ route('role.view_admin', ['subdomain' => $curator->subdomain, 'tab' => $curator->subdomain == request()->subdomain ? 'schedule' : (request()->tab ? request()->tab : 'schedule')]) }}"
                        class="group flex gap-x-3 rounded-md p-2 text-sm font-semibold leading-6 hover:bg-gray-800 hover:text-white {{ request()->is($curator->subdomain) || request()->is($curator->subdomain . '/*') ? 'bg-gray-800 text-white' : 'text-gray-400' }}">
                        <span
                            class="flex h-6 w-6 shrink-0 items-center justify-center rounded-lg border border-gray-700 bg-gray-800 text-[0.625rem] font-medium group-hover:text-white {{ request()->is($curator->subdomain) || request()->is($curator->subdomain . '/*') ? 'text-white' : 'text-gray-400' }}">{{ strtoupper(substr($curator->name, 0, 1)) }}</span>
                        <span class="truncate">{{ $curator->name }}</span>
                    </a>
                </li>
                @endforeach

            </ul>
        </li>
        @endif

        @if (auth()->user()->isAdmin())
        <li class="mt-auto">
            <a href="{{ route('settings.index') }}"
                class="group -mx-2 flex gap-x-3 rounded-md p-2 text-sm font-semibold leading-6 text-gray-400 hover:bg-gray-800 hover:text-white {{ request()->is('settings*') ? 'bg-gray-800 text-white' : '' }}">
                <svg class="h-6 w-6 shrink-0" fill="none" viewBox="0 0 24 24" stroke-width="1.5"
                    stroke="currentColor" aria-hidden="true">
                    <path stroke-linecap="round" stroke-linejoin="round"
                        d="M9.594 3.94c.09-.542.56-.94 1.11-.94h2.593c.55 0 1.02.398 1.11.94l.213 1.281c.063.374.313.686.645.87.074.04.147.083.22.127.324.196.72.257 1.075.124l1.217-.456a1.125 1.125 0 011.37.49l1.296 2.247a1.125 1.125 0 01-.26 1.431l-1.003.827c-.293.24-.438.613-.431.992a6.759 6.759 0 010 .255c-.007.378.138.75.43.99l1.005.828c.424.35.534.954.26 1.43l-1.298 2.247a1.125 1.125 0 01-1.369.491l-1.217-.456c-.355-.133-.75-.072-1.076.124a6.57 6.57 0 01-.22.128c-.331.183-.581.495-.644.869l-.213 1.28c-.09.543-.56.941-1.11.941h-2.594c-.55 0-1.02-.398-1.11-.94l-.213-1.281c-.062-.374-.312-.686-.644-.87a6.52 6.52 0 01-.22-.127c-.325-.196-.72-.257-1.076-.124l-1.217.456a1.125 1.125 0 01-1.369-.49l-1.297-2.247a1.125 1.125 0 01.26-1.431l1.004-.827c.292-.24.437-.613.43-.992a6.932 6.932 0 010-.255c.007-.378-.138-.75-.43-.99l-1.004-.828a1.125 1.125 0 01-.26-1.43l1.297-2.247a1.125 1.125 0 011.37-.491l1.216.456c.356.133.751.072 1.076-.124.072-.044.146-.087.22-.128.332-.183.582-.495.644-.869l.214-1.281z" />
                    <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                </svg>
                {{ __('messages.settings') }}
            </a>
        </li>
        @endif
    </ul>
</nav>
