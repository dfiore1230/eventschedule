<x-auth-layout>
    <!-- Session Status -->
    <x-auth-session-status class="mb-4" :status="session('status')" />

    <form method="POST" action="{{ route('login') }}">
        @csrf

        <!-- Email Address -->
        <div>
            <x-input-label for="email" :value="__('messages.email')" />
            <x-text-input id="email" class="block mt-1 w-full" type="email" name="email" :value="old('email')" required autofocus autocomplete="username" />

            <div class="flex justify-end pt-3">
                <a class="hover:underline text-sm text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-gray-100 rounded-md focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-[#4E81FA] dark:focus:ring-offset-gray-800" href="{{ route('password.request') }}">
                    {{ __('messages.reset_password') }}
                </a>
            </div>

            <x-input-error :messages="$errors->get('email')" class="mt-2" />
        </div>

        <!-- Password -->
        <div class="mt-4">
            <x-input-label for="password" :value="__('messages.password')" />

            <x-text-input id="password" class="block mt-1 w-full"
                            type="password"
                            name="password"
                            required autocomplete="current-password" />

            <x-input-error :messages="$errors->get('password')" class="mt-2" />
        </div>

        <!-- Remember Me -->
        <div class="block mt-4 hidden">
            <label for="remember_me" class="inline-flex items-center">
                <input id="remember_me" type="checkbox" class="rounded dark:bg-gray-900 border-gray-300 dark:border-gray-700 text-[#4E81FA] shadow-sm focus:ring-[#4E81FA] dark:focus:ring-[#4E81FA] dark:focus:ring-offset-gray-800" name="remember" CHECKED>
                <span class="ms-2 text-sm text-gray-600 dark:text-gray-400">{{ __('messages.remember_me') }}</span>
            </label>
        </div>

        <div class="flex items-center justify-between mt-4">
            @if (config('app.hosted'))
            <a class="hover:underline text-sm text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-gray-100 rounded-md focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-[#4E81FA] dark:focus:ring-offset-gray-800" href="{{ route('sign_up') }}">
                {{ __('messages.create_new_account') }}
            </a>
            @else
            <div></div>
            @endif

            <x-primary-button dusk="log-in-button" class="ml-4">
                {{ __('messages.log_in') }}
            </x-primary-button>
        </div>
    </form>

    @if (config('app.is_testing'))
    <script>
        // Testing-only marker: expose a deterministic readiness flag when the login email input
        // is present and visibly interactable to help Dusk tests avoid timing/hydration races.
        (function () {
            function checkReady() {
                try {
                    var el = document.querySelector('input[name="email"]');
                    if (!el) return false;
                    var rects = el.getClientRects();
                    if (!rects || rects.length === 0) return false;
                    var style = window.getComputedStyle(el);
                    if (!style) return false;
                    if (style.visibility === 'hidden' || style.display === 'none') return false;
                    if (el.offsetParent === null) return false;
                    window.__evs_login_ready = true;
                    return true;
                } catch (e) {
                    return false;
                }
            }

            if (!checkReady()) {
                var attempts = 0;
                var iv = setInterval(function () {
                    attempts++;
                    if (checkReady() || attempts > 60) {
                        clearInterval(iv);
                        if (!window.__evs_login_ready) {
                            window.__evs_login_ready = false;
                        }
                    }
                }, 500);
            }
        })();
    </script>
    @endif

</x-auth-layout>
