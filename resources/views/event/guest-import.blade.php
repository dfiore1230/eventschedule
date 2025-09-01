<x-app-guest-layout :role="$role">

  @if ($role->profile_image_url && ! $role->header_image && ! $role->header_image && $role->language_code == 'en')
  <div class="pt-8"></div>
  @endif

  <main>
    <div>
      <div class="container mx-auto pt-7 pb-20 px-5 max-w-2xl">
        <div class="bg-white dark:bg-gray-800 mb-4 {{ !$role->header_image && !$role->header_image_url && $role->profile_image_url ? 'pt-16' : '' }} rounded-lg shadow-md">
          <div
            class="relative before:block before:absolute before:bg-[#00000033] before:-inset-0"
          >
            
            @if ($role->header_image)
            <img
              class="block max-h-72 w-full object-cover rounded-t-2xl"
              src="{{ asset('images/headers') }}/{{ $role->header_image }}.png"
            />
            @elseif ($role->header_image_url)
            <img
              class="block max-h-72 w-full object-cover rounded-t-2xl"
              src="{{ $role->header_image_url }}"
            />
            @endif
          </div>
          <div class="px-4 sm:px-8 pb-4 relative z-10">
            @if ($role->profile_image_url)
            <div class="rounded-lg w-[130px] h-[130px] -mt-[100px] -ml-1 mb-6 bg-white dark:bg-gray-800 flex items-center justify-center">
              <img
                class="rounded-lg w-[120px] h-[120px] object-cover"
                src="{{ $role->profile_image_url }}"
                alt="person"
              />
            </div>
            @else
            <div style="height: 42px;"></div>
            @endif
    
            <div class="flex justify-between items-center gap-6 mb-5">
            @if (is_rtl())
                <!-- RTL Layout: View Schedule button on left, title on right -->
                <div class="hidden sm:flex items-center gap-3">
                    <a href="{{ $role->getGuestUrl() }}" type="button" class="px-4 py-2 bg-gray-200 dark:bg-gray-700 text-gray-900 dark:text-gray-100 rounded-md hover:bg-gray-300 dark:hover:bg-gray-600 transition-colors">
                        {{ __('messages.view_schedule') }}
                    </a>
                </div>
                
                <div class="w-full sm:w-auto text-right">
                    <h2 class="text-xl font-bold leading-7 text-gray-900 dark:text-gray-100 sm:truncate sm:text-2xl sm:tracking-tight">
                        {{ __('messages.add_event') }}
                    </h2>
                    <h3 class="text-gray-700 dark:text-gray-300">
                        {{ $role->name }}
                    </h3>
                </div>
            @else
                <!-- LTR Layout: Title on left, cancel button on right -->
                <div>
                    <h2 class="text-xl font-bold leading-7 text-gray-900 dark:text-gray-100 sm:truncate sm:text-2xl sm:tracking-tight">
                        {{ __('messages.add_event') }}
                    </h2>
                    <h3 class="text-gray-700 dark:text-gray-300">
                        {{ $role->getDisplayName(true) }}
                    </h3>
                </div>

                <div class="hidden sm:flex items-center gap-3">
                    <a href="{{ $role->getGuestUrl() }}" type="button" class="px-4 py-2 bg-gray-200 dark:bg-gray-700 text-gray-900 dark:text-gray-100 rounded-md hover:bg-gray-300 dark:hover:bg-gray-600 transition-colors">
                        {{ __('messages.view_schedule') }}
                    </a>
                </div>
                
            @endif

            </div>
          </div>
        </div>

        @include('event.import')
      </div>
    </div>

  </main>

</x-app-guest-layout>