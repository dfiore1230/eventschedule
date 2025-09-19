<x-app-admin-layout>

    @vite([
    'resources/js/countrySelect.min.js',
    'resources/css/countrySelect.min.css',
    ])

    <!-- Step Indicator for Add Event Flow -->
    @if(session('pending_request'))
        <div class="my-6">
            <x-step-indicator :compact="true" />
        </div>
    @endif

    <x-slot name="head">

        <style>
        button {
            min-width: 100px;
            min-height: 40px;
        }

        .country-select {
            width: 100%;
        }

        #preview {
            border: 1px solid #dbdbdb;
            border-radius: 4px;
            height: 150px;
            width: 100%;
            text-align: center;
            vertical-align: middle;
            display: flex;
            align-items: center;
            justify-content: center;
            margin: auto;
            font-size: 3rem;
        }

        .color-select-container {
            display: flex;
            align-items: center;
            gap: 0.5rem;
        }

        .color-nav-button {
            padding: 0.5rem;
            display: flex;
            align-items: center;
            justify-content: center;
            border-radius: 0.375rem;
            border: 1px solid #e5e7eb;
            background: white;
            cursor: pointer;
        }

        .color-nav-button:disabled {
            opacity: 0.5;
            cursor: not-allowed;
        }

        .color-nav-button:hover:not(:disabled) {
            background: #f3f4f6;
        }

        </style>

        <script {!! nonce_attr() !!}>
        document.addEventListener('DOMContentLoaded', () => {
            $("#country").countrySelect({
                defaultCountry: '{{ old('country_code', $role->country_code) }}',
            });
            $('#background').val('{{ old('background', $role->background) }}');
            $('#background_colors').val('{{ old('background_colors', $role->background_colors) }}');
            $('#font_family').val('{{ old('font_family', $role->font_family) }}');
            $('#language_code').val('{{ old('language_code', $role->language_code) }}');
            $('#timezone').val('{{ old('timezone', $role->timezone) }}');
            
            $('#header_image').trigger('input');
            
            updatePreview();
            onChangeBackground();
            onChangeCountry();
            onChangeFont();
            updateImageNavButtons();
            toggleCustomImageInput();
            updateHeaderNavButtons();
            toggleCustomHeaderInput();
            
            // Handle accept_requests checkbox
            const acceptRequestsCheckbox = document.querySelector('input[name="accept_requests"][type="checkbox"]');
            const requireApprovalSection = document.getElementById('require_approval_section');
            const requestTermsSection = document.getElementById('request_terms_section');

            if (acceptRequestsCheckbox && requireApprovalSection) {
                requireApprovalSection.style.display = acceptRequestsCheckbox.checked ? 'block' : 'none';                
                acceptRequestsCheckbox.addEventListener('change', function() {
                    requireApprovalSection.style.display = this.checked ? 'block' : 'none';
                });
            }

            if (acceptRequestsCheckbox && requestTermsSection) {
                requestTermsSection.style.display = acceptRequestsCheckbox.checked ? 'block' : 'none';                
                acceptRequestsCheckbox.addEventListener('change', function() {
                    requestTermsSection.style.display = this.checked ? 'block' : 'none';
                });
            }

            function previewImage(input, previewId) {
                const preview = document.getElementById(previewId);
                const warningElement = document.getElementById(previewId.split('_')[0] + '_image_size_warning');

                if (!input || !input.files || !input.files[0]) {
                    console.log('no file')
                    if (preview) {
                        preview.src = '';
                        preview.style.display = 'none';
                    }
                    if (warningElement) {
                        warningElement.textContent = '';
                        warningElement.style.display = 'none';
                    }
                    updatePreview();
                    return;
                }

                const file = input.files[0];
                const reader = new FileReader();

                reader.onloadend = function () {
                    const img = new Image();
                    img.onload = function() {
                        const width = this.width;
                        const height = this.height;
                        const fileSize = file.size / 1024 / 1024; // in MB
                        let warningMessage = '';

                        if (fileSize > 2.5) {
                            warningMessage += "{{ __('messages.image_size_warning') }}";
                        }

                        if (width !== height && previewId == 'profile_image_preview') {
                            if (warningMessage) warningMessage += " ";
                            warningMessage += "{{ __('messages.image_not_square') }}";
                        }

                        if (warningElement) {
                            if (warningMessage) {
                                warningElement.textContent = warningMessage;
                                warningElement.style.display = 'block';
                            } else {
                                warningElement.textContent = '';
                                warningElement.style.display = 'none';
                            }
                        }

                        if (warningMessage == '') {
                            preview.src = reader.result;
                            preview.style.display = 'block';
                            updatePreview();
                            
                            if (previewId === 'background_image_preview') {
                                $('#style_background_image img:not(#background_image_preview)').hide();
                                $('#style_background_image a').hide();
                            }
                        } else {
                            preview.src = '';
                            preview.style.display = 'none';
                        }
                    };
                    img.src = reader.result;
                }

                if (file) {
                    reader.readAsDataURL(file);
                } else {
                    preview.src = '';
                    preview.style.display = 'none';
                    if (warningElement) {
                        warningElement.textContent = '';
                        warningElement.style.display = 'none';
                    }
                    updatePreview();
                }
            }

            $('#profile_image').on('change', function() {
                previewImage(this, 'profile_image_preview');
            });

            $('#header_image').on('input', function() {
                var headerImageUrl = $(this).find(':selected').val();
                if (headerImageUrl) {
                    headerImageUrl = "{{ asset('images/headers') }}" + '/' + headerImageUrl + '.png';
                    $('#header_image_preview').attr('src', headerImageUrl).show();
                    $('#delete_header_image').hide();
                } else if ({{ $role->header_image_url ? 'true' : 'false' }}) {
                    $('#header_image_preview').attr('src', '{{ $role->header_image_url }}').show();
                    $('#delete_header_image').show();
                } else {
                    $('#header_image_preview').hide();
                    $('#delete_header_image').hide();
                }
            });

            $('#header_image_url').on('change', function() {
                previewImage(this, 'header_image_preview');
                $('#header_image_preview').show();
            });

            $('#background_image_url').on('change', function() {
                previewImage(this, 'background_image_preview');
                updatePreview();
            });
        });

        function onChangeCountry() {
            var selected = $('#country').countrySelect('getSelectedCountryData');
            $('#country_code').val(selected.iso2);
        }

        function onChangeBackground() {
            var background = $('input[name="background"]:checked').val();

            $('#style_background_image').hide();
            $('#style_background_gradient').hide();
            $('#style_background_solid').hide();
            
            if (background == 'image') {
                $('#style_background_image').show();
            } else if (background == 'gradient') {
                $('#style_background_gradient').show();
            } else if (background == 'solid') {
                $('#style_background_solid').show();
            }
        }

        function onChangeFont() {
            /*
            var font_family = $('#font_family').find(':selected').text();
            var link = document.createElement('link');

            link.href = 'https://fonts.googleapis.com/css2?family=' + encodeURIComponent(font_family.trim()) + ':wght@400;700&display=swap';
            link.rel = 'stylesheet';

            document.head.appendChild(link);

            link.onload = function() {
                updatePreview();
            };
            */
        }

        function updatePreview() {
            var background = $('input[name="background"]:checked').val();
            var backgroundColor = $('#background_color').val();
            var backgroundColors = $('#background_colors').val();
            var backgroundRotation = $('#background_rotation').val();
            var fontColor = $('#font_color').val();
            var fontFamily = $('#font_family').find(':selected').val();
            var name = $('#name').val();

            if (! name) {
                name = "{{ __('messages.preview') }}";
            } else if (name.length > 10) {
                name = name.substring(0, 10) + '...';
            }

            $('#preview')
                .css('color', fontColor)
                .css('font-family', fontFamily)
                .css('background-size', 'cover')
                .css('background-position', 'center')
                .html('<div class="bg-[#F5F9FE] rounded-lg px-6 py-4 flex flex-col">' + name + '</div>');

            if (background == 'gradient') {
                $('#custom_colors').toggle(backgroundColors == '');
                if (backgroundColors == '') {
                    var customColor1 = $('#custom_color1').val();
                    var customColor2 = $('#custom_color2').val();
                    backgroundColors = customColor1 + ', ' + customColor2;
                }

                if (!backgroundRotation) {
                    backgroundRotation = '0';
                }

                var gradient = 'linear-gradient(' + backgroundRotation + 'deg, ' + backgroundColors + ')';

                $('#preview')
                    .css('background-color', '')
                    .css('background-image', gradient);
            } else if (background == 'image') {

                var backgroundImageUrl = $('#background_image').find(':selected').val();
                if (backgroundImageUrl) {
                    backgroundImageUrl = "{{ asset('images/backgrounds') }}" + '/' + $('#background_image').find(':selected').val() + '.png';
                } else {
                    backgroundImageUrl = $('#background_image_preview').attr('src') || "{{ $role->background_image_url }}";
                }

                $('#preview')
                    .css('background-color', '')
                    .css('background-image', 'url("' + backgroundImageUrl + '")');
            } else {
                $('#preview').css('background-image', '')
                    .css('background-color', backgroundColor);
            }
        }

        function onValidateClick() {
            $('#address_response').text("{{ __('messages.searching') }}...").show();
            $('#accept_button').hide();
            var country = $('#country').countrySelect('getSelectedCountryData');
            $.post({
                url: '{{ route('validate_address') }}',
                data: {
                    _token: '{{ csrf_token() }}',
                    address1: $('#address1').val(),
                    city: $('#city').val(),
                    state: $('#state').val(),
                    postal_code: $('#postal_code').val(),                    
                    country_code: country ? country.iso2 : '',
                },
                success: function(response) {
                    if (response) {
                        var address = response['data']['formatted_address'];
                        $('#address_response').text(address);
                        $('#accept_button').show();
                        $('#address_response').data('validated_address', response['data']);
                    } else {
                        $('#address_response').text("{{ __('messages.address_not_found') }}");    
                    }
                },
                error: function(xhr, status, error) {
                    $('#address_response').text("{{ __('messages.an_error_occurred') }}");
                }
            });
        }

        function viewMap() {
            var address = [
                $('#address1').val(),
                $('#city').val(),
                $('#state').val(),
                $('#postal_code').val(),
                $('#country').countrySelect('getSelectedCountryData').name
            ].filter(Boolean).join(', ');

            if (address) {
                var url = 'https://www.google.com/maps/search/?api=1&query=' + encodeURIComponent(address);
                window.open(url, '_blank');
            } else {
                alert("{{ __('messages.please_enter_address') }}");
            }
        }

        function acceptAddress(event) {
            event.preventDefault();
            var validatedAddress = $('#address_response').data('validated_address');
            if (validatedAddress) {
                $('#address1').val(validatedAddress['address1']);
                $('#city').val(validatedAddress['city']);
                $('#state').val(validatedAddress['state']);
                $('#postal_code').val(validatedAddress['postal_code']);
                                
                // Hide the address response and accept button after accepting
                $('#address_response').hide();
                $('#accept_button').hide();
            }
        }

        function updateColorNavButtons() {
            const select = document.getElementById('background_colors');
            const prevButton = document.getElementById('prev_color');
            const nextButton = document.getElementById('next_color');
            
            prevButton.disabled = select.selectedIndex === 0;
            nextButton.disabled = select.selectedIndex === select.options.length - 1;
        }

        function changeBackgroundColor(direction) {
            const select = document.getElementById('background_colors');
            const newIndex = select.selectedIndex + direction;
            
            if (newIndex >= 0 && newIndex < select.options.length) {
                select.selectedIndex = newIndex;
                select.dispatchEvent(new Event('input'));
                updateColorNavButtons();
            }
        }

        function updateImageNavButtons() { 
            const select = document.getElementById('background_image');
            const prevButton = document.getElementById('prev_image');
            const nextButton = document.getElementById('next_image');

            prevButton.disabled = select.selectedIndex === 0;
            nextButton.disabled = select.selectedIndex === select.options.length - 1;
        }

        function changeBackgroundImage(direction) {
            const select = document.getElementById('background_image');
            const newIndex = select.selectedIndex + direction;
            
            if (newIndex >= 0 && newIndex < select.options.length) {
                select.selectedIndex = newIndex;
                select.dispatchEvent(new Event('input'));
                updateImageNavButtons();
            }
        }

        function toggleCustomImageInput() {
            const select = document.getElementById('background_image');
            const customInput = document.getElementById('custom_image_input');
            customInput.style.display = select.value === '' ? 'block' : 'none';
        }

        function updateHeaderNavButtons() { 
            const select = document.getElementById('header_image');
            const prevButton = document.getElementById('prev_header');
            const nextButton = document.getElementById('next_header');

            prevButton.disabled = select.selectedIndex === 0;
            nextButton.disabled = select.selectedIndex === select.options.length - 1;
        }

        function changeHeaderImage(direction) {
            const select = document.getElementById('header_image');
            const newIndex = select.selectedIndex + direction;
            
            if (newIndex >= 0 && newIndex < select.options.length) {
                select.selectedIndex = newIndex;
                select.dispatchEvent(new Event('input'));
                updateHeaderNavButtons();
            }
        }

        function toggleCustomHeaderInput() {
            const select = document.getElementById('header_image');
            const customInput = document.getElementById('custom_header_input');
            customInput.style.display = select.value === '' ? 'block' : 'none';
        }


        </script>

    </x-slot>

    <h2 class="pt-2 my-4 text-xl font-bold leading-7 text-gray-900 dark:text-gray-100x sm:truncate sm:text-2xl sm:tracking-tight">
        {{ $title }}
    </h2>

    <form method="post"
        action="{{ $role->exists ? route('role.update', ['subdomain' => $role->subdomain]) : route('role.store') }}"
        enctype="multipart/form-data">

        @csrf
        @if($role->exists)
        @method('put')
        @endif

        <div class="py-5">
            <div class="max-w-7xl mx-auto space-y-6">
                <div class="p-4 sm:p-8 bg-white dark:bg-gray-800 shadow-md sm:rounded-lg">
                    <div class="max-w-xl">

                        <h2 class="text-lg font-medium text-gray-900 dark:text-gray-100 mb-6">
                            {{ __('messages.' . $role->type . '_details') }}
                        </h2>

                        @if(! $role->exists)
                        <input type="hidden" name="type" value="{{ $role->type }}"/>
                        @endif

                        <input type="hidden" name="sync_direction" id="sync_direction_hidden" value="{{ old('sync_direction', $role->sync_direction) }}" />

                        <div class="mb-6">
                            <x-input-label for="name" :value="__('messages.name') . ' *'" />
                            <x-text-input id="name" name="name" type="text" class="mt-1 block w-full"
                                :value="old('name', $role->name)" required autofocus oninput="updatePreview()" />
                            <x-input-error class="mt-2" :messages="$errors->get('name')" />
                        </div>

                        @if ($role->name_en)
                        <div class="mb-6">
                            <x-input-label for="name_en" :value="__('messages.name_en')" />
                            <x-text-input id="name_en" name="name_en" type="text" class="mt-1 block w-full"
                                :value="old('name_en', $role->name_en)" />
                            <x-input-error class="mt-2" :messages="$errors->get('name_en')" />
                        </div>
                        @endif

                        <div class="mb-6">
                            <x-input-label for="description" :value="__('messages.description')" />
                            <textarea id="description" name="description"
                                class="html-editor mt-1 block w-full border-gray-300 dark:border-gray-700 dark:bg-gray-900 dark:text-gray-300 focus:border-[#4E81FA] dark:focus:border-[#4E81FA] focus:ring-[#4E81FA] dark:focus:ring-[#4E81FA] rounded-md shadow-sm">{{ old('description', $role->description) }}</textarea>
                            <x-input-error class="mt-2" :messages="$errors->get('description')" />
                        </div>

                        <div class="mb-6">
                            <x-input-label for="profile_image" :value="__('messages.square_profile_image')" />
                            <input id="profile_image" name="profile_image" type="file" class="mt-1 block w-full text-gray-900 dark:text-gray-100"
                                :value="old('profile_image')" accept="image/png, image/jpeg" />
                            <x-input-error class="mt-2" :messages="$errors->get('profile_image')" />
                            <p id="profile_image_size_warning" class="mt-2 text-sm text-red-600 dark:text-red-400" style="display: none;">
                                {{ __('messages.image_size_warning') }}
                            </p>

                            <img id="profile_image_preview" src="#" alt="Profile Image Preview" style="max-height:120px; display:none;" class="pt-3" />

                            @if ($role->profile_image_url)
                            <img src="{{ $role->profile_image_url }}" style="max-height:120px" class="pt-3" />
                            <a href="#"
                                onclick="var confirmed = confirm('{{ __('messages.are_you_sure') }}'); if (confirmed) { location.href = '{{ route('role.delete_image', ['subdomain' => $role->subdomain, 'image_type' => 'profile']) }}'; }"
                                class="hover:underline text-gray-900 dark:text-gray-100">
                                {{ __('messages.delete_image') }}
                            </a>
                            @endif
                        </div>

                        <div class="mb-6">
                            <x-input-label for="header_image" :value="__('messages.header_image')" />
                            <div class="color-select-container">
                                <select id="header_image" name="header_image"
                                    class="flex-grow border-gray-300 dark:border-gray-700 dark:bg-gray-900 dark:text-gray-300 focus:border-[#4E81FA] dark:focus:border-[#4E81FA] focus:ring-[#4E81FA] dark:focus:ring-[#4E81FA] rounded-md shadow-sm"
                                    oninput="updatePreview(); updateHeaderNavButtons(); toggleCustomHeaderInput();">
                                    @foreach($headers as $header => $name)
                                    <option value="{{ $header }}"
                                        {{ $role->header_image == $header ? 'SELECTED' : '' }}>
                                        {{ $name }}</option>
                                    @endforeach
                                </select>

                                <button type="button" 
                                        id="prev_header" 
                                        class="color-nav-button" 
                                        onclick="changeHeaderImage(-1)"
                                        title="{{ __('messages.previous') }}">
                                    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-5 h-5">
                                        <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 19.5L8.25 12l7.5-7.5" />
                                    </svg>
                                </button>
                                                                                
                                <button type="button" 
                                        id="next_header" 
                                        class="color-nav-button" 
                                        onclick="changeHeaderImage(1)"
                                        title="{{ __('messages.next') }}">
                                    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-5 h-5">
                                        <path stroke-linecap="round" stroke-linejoin="round" d="M8.25 4.5l7.5 7.5-7.5 7.5" />
                                    </svg>
                                </button>
                            </div>

                            <div id="custom_header_input" style="display:none" class="mt-2">
                                <input id="header_image_url" name="header_image_url" type="file" 
                                    class="mt-1 block w-full text-gray-900 dark:text-gray-100" 
                                    :value="old('header_image_url')" 
                                    accept="image/png, image/jpeg" />
                                <x-input-error class="mt-2" :messages="$errors->get('header_image_url')" />
                                <p id="header_image_size_warning" class="mt-2 text-sm text-red-600 dark:text-red-400" style="display: none;">
                                    {{ __('messages.image_size_warning') }}
                                </p>
                            </div>

                            <img id="header_image_preview" 
                                src="{{ $role->header_image ? asset('images/headers/' . $role->header_image . '.png') : $role->header_image_url }}" 
                                alt="Header Image Preview" 
                                style="max-height:120px; {{ $role->header_image || $role->header_image_url ? '' : 'display:none;' }}" 
                                class="pt-3" />

                            @if ($role->header_image_url)
                            <a href="#" id="delete_header_image" style="display: {{ $role->header_image ? 'none' : 'block' }};"
                                onclick="var confirmed = confirm('{{ __('messages.are_you_sure') }}'); if (confirmed) { location.href = '{{ route('role.delete_image', ['subdomain' => $role->subdomain, 'image_type' => 'header']) }}'; }"
                                class="hover:underline text-gray-900 dark:text-gray-100">
                                {{ __('messages.delete_image') }}
                            </a>
                            @endif

                        </div>
                    </div>
                </div>

                @if ($role->isVenue())
                <div class="p-4 sm:p-8 bg-white dark:bg-gray-800 shadow-md sm:rounded-lg">
                    <div class="max-w-xl">

                        <h2 class="text-lg font-medium text-gray-900 dark:text-gray-100 mb-6">
                            {{ __('messages.venue_address') }}
                        </h2>

                        <div class="mb-6">
                            <x-input-label for="address1" :value="__('messages.street_address') . ' *'" />
                            <x-text-input id="address1" name="address1" type="text" class="mt-1 block w-full"
                                :value="old('address1', $role->address1)" autocomplete="off" required />
                            <x-input-error class="mt-2" :messages="$errors->get('address1')" />
                        </div>

                        <div class="mb-6">
                            <x-input-label for="city" :value="__('messages.city')" />
                            <x-text-input id="city" name="city" type="text" class="mt-1 block w-full"
                                :value="old('city', $role->city)" autocomplete="off" />
                            <x-input-error class="mt-2" :messages="$errors->get('city')" />
                        </div>

                        <div class="mb-6">
                            <x-input-label for="state" :value="__('messages.state_province')" />
                            <x-text-input id="state" name="state" type="text" class="mt-1 block w-full"
                                :value="old('state', $role->state)" autocomplete="off" />
                            <x-input-error class="mt-2" :messages="$errors->get('state')" />
                        </div>

                        <div class="mb-6">
                            <x-input-label for="postal_code" :value="__('messages.postal_code')" />
                            <x-text-input id="postal_code" name="postal_code" type="text" class="mt-1 block w-full"
                                :value="old('postal_code', $role->postal_code)" autocomplete="off" />
                            <x-input-error class="mt-2" :messages="$errors->get('postal_code')" />
                        </div>

                        <div class="mb-6">
                            <x-input-label for="country" :value="__('messages.country')" />
                            <x-text-input id="country" name="country" type="text" class="mt-1 block w-full"
                                :value="old('country')" onchange="onChangeCountry()" autocomplete="off" />
                            <x-input-error class="mt-2" :messages="$errors->get('country')" />
                            <input type="hidden" id="country_code" name="country_code" />
                        </div>

                        <div class="mb-6">
                            <div class="flex items-center space-x-4">
                                <x-secondary-button id="view_map_button" onclick="viewMap()">{{ __('messages.view_map') }}</x-secondary-button>
                                @if (config('services.google.backend'))
                                <x-secondary-button id="validate_button" onclick="onValidateClick()">{{ __('messages.validate_address') }}</x-secondary-button>
                                <x-secondary-button id="accept_button" onclick="acceptAddress(event)" class="hidden">{{ __('messages.accept') }}</x-secondary-button>
                                @endif
                            </div>
                        </div>

                        <div id="address_response" class="mb-6 hidden text-gray-900 dark:text-gray-100"></div>

                    </div>
                </div>
                @endif

                <div class="p-4 sm:p-8 bg-white dark:bg-gray-800 shadow-md sm:rounded-lg">
                    <div class="max-w-xl">

                        <h2 class="text-lg font-medium text-gray-900 dark:text-gray-100 mb-6">
                            {{ __('messages.contact_info') }}
                        </h2>

                        <div class="mb-3">
                            <x-input-label for="email" :value="__('messages.email') . ' *'" />
                            <x-text-input id="email" name="email" type="email" class="mt-1 block w-full"
                                :value="old('email', $role->exists ? $role->email : $user->email)" required />
                            <x-input-error class="mt-2" :messages="$errors->get('email')" />
                        </div>

                        <div class="mb-6">
                            <x-checkbox name="show_email" label="{{ __('messages.show_email_address') }}"
                                checked="{{ old('show_email', $role->show_email) }}"
                                data-custom-attribute="value" />
                            <x-input-error class="mt-2" :messages="$errors->get('show_email')" />
                        </div>

                        <!--
                        <div class="mb-6">
                            <x-input-label for="phone" :value="__('messages.phone')" />
                            <x-text-input id="phone" name="phone" type="text" class="mt-1 block w-full"
                                :value="old('phone', $role->phone)" />
                            <x-input-error class="mt-2" :messages="$errors->get('phone')" />
                        </div>
                        -->

                        <div class="mb-6">
                            <x-input-label for="website" :value="__('messages.website')" />
                            <x-text-input id="website" name="website" type="url" class="mt-1 block w-full"
                                :value="old('website', $role->website)" />
                            <x-input-error class="mt-2" :messages="$errors->get('website')" />
                        </div>

                        @if ($role->isCurator())
                        <div class="mb-6">
                            <x-input-label for="city" :value="__('messages.city')" />
                            <x-text-input id="city" name="city" type="text" class="mt-1 block w-full"
                                :value="old('city', $role->city)" autocomplete="off" />
                            <x-input-error class="mt-2" :messages="$errors->get('city')" />
                        </div>
                        @endif

                        @if ($role->isCurator() || $role->isTalent())
                        <div class="mb-6">
                            <x-input-label for="country" :value="__('messages.country')" />
                            <x-text-input id="country" name="country" type="text" class="mt-1 block w-full"
                                :value="old('country')" onchange="onChangeCountry()" autocomplete="off" />
                            <x-input-error class="mt-2" :messages="$errors->get('country')" />
                            <input type="hidden" id="country_code" name="country_code" />
                        </div>
                        @endif


                    </div>
                </div>

                <div class="p-4 sm:p-8 bg-white dark:bg-gray-800 shadow-md sm:rounded-lg" id="address">
                    <div>

                    <h2 class="text-lg font-medium text-gray-900 dark:text-gray-100 mb-6">
                        {{ __('messages.schedule_style') }}
                    </h2>

                    <!--
                    <div class="mb-6">
                        <x-input-label :value="__('messages.layout')" />
                        <div class="mt-2 space-y-2">
                            @foreach(['calendar', 'list'] as $layout)
                            <div class="flex items-center">
                                <input type="radio" 
                                    id="event_layout_{{ $layout }}" 
                                    name="event_layout" 
                                    value="{{ $layout }}"
                                    {{ $role->event_layout == $layout ? 'checked' : '' }}
                                    class="border-gray-300 dark:border-gray-700 focus:ring-[#4E81FA] dark:focus:ring-[#4E81FA] h-4 w-4">
                                <label for="event_layout_{{ $layout }}" class="ml-2 text-gray-900 dark:text-gray-100">
                                    {{ __('messages.' . $layout) }}
                                </label>
                            </div>
                            @endforeach
                        </div>
                        <x-input-error class="mt-2" :messages="$errors->get('event_layout')" />
                    </div>
                    -->

                    <div class="flex flex-col xl:flex-row xl:gap-12">
                        <div class="w-full lg:w-1/2">
                            <!--
                            <div class="mb-6">
                                <x-input-label for="font_family" :value="__('messages.font_family')" />
                                <select id="font_family" name="font_family" onchange="onChangeFont()"
                                    class="border-gray-300 dark:border-gray-700 dark:bg-gray-900 dark:text-gray-300 focus:border-[#4E81FA] dark:focus:border-[#4E81FA] focus:ring-[#4E81FA] dark:focus:ring-[#4E81FA] rounded-md shadow-sm">
                                    @foreach($fonts as $font)
                                    <option value="{{ $font->value }}"
                                        {{ $role->font_family == $font->value ? 'SELECTED' : '' }}>
                                        {{ $font->label }}</option>
                                    @endforeach
                                </select>
                                <x-input-error class="mt-2" :messages="$errors->get('font_family')" />
                            </div>

                            <div class="mb-6">
                                <x-input-label for="font_color" :value="__('messages.font_color')" />
                                <x-text-input id="font_color" name="font_color" type="color" class="mt-1 block w-1/2"
                                    :value="old('font_color', $role->font_color)" oninput="updatePreview()" />
                                <x-input-error class="mt-2" :messages="$errors->get('font_color')" />
                            </div>
                            -->

                            

                            <div class="mb-6">
                                <x-input-label :value="__('messages.background')" />
                                <div class="mt-2 space-y-2">
                                    @foreach(['gradient', 'solid', 'image'] as $background)
                                    <div class="flex items-center">
                                        <input type="radio" 
                                            id="background_type_{{ $background }}" 
                                            name="background" 
                                            value="{{ $background }}"
                                            {{ $role->background == $background ? 'checked' : '' }}
                                            class="border-gray-300 dark:border-gray-700 focus:ring-[#4E81FA] dark:focus:ring-[#4E81FA] h-4 w-4"
                                            onchange="onChangeBackground(); updatePreview();">
                                        <label for="background_type_{{ $background }}" class="ml-2 text-gray-900 dark:text-gray-100">
                                            {{ __('messages.' . $background) }}
                                        </label>
                                    </div>
                                    @endforeach
                                </div>
                                <x-input-error class="mt-2" :messages="$errors->get('background')" />
                            </div>

                            <div class="mb-6" id="style_background_solid" style="display:none">
                                <x-input-label for="background_color" :value="__('messages.background_color')" />
                                <x-text-input id="background_color" name="background_color" type="color" class="mt-1 block w-1/2"
                                    :value="old('background_color', $role->background_color)" oninput="updatePreview()" />
                                <x-input-error class="mt-2" :messages="$errors->get('background_color')" />
                            </div>

                            <div class="mb-6" id="style_background_image" style="display:none">
                                <x-input-label for="image" :value="__('messages.image')" />
                                <div class="color-select-container">
                                    <select id="background_image" name="background_image"
                                        class="flex-grow border-gray-300 dark:border-gray-700 dark:bg-gray-900 dark:text-gray-300 focus:border-[#4E81FA] dark:focus:border-[#4E81FA] focus:ring-[#4E81FA] dark:focus:ring-[#4E81FA] rounded-md shadow-sm w-64 max-w-64"
                                        oninput="onChangeBackground(); updatePreview(); updateImageNavButtons(); toggleCustomImageInput();">
                                        @foreach($backgrounds as $background => $name)
                                        <option value="{{ $background }}"
                                            {{ $role->background_image == $background ? 'SELECTED' : '' }}>
                                            {{ $name }}</option>
                                        @endforeach
                                    </select>

                                    <button type="button" 
                                            id="prev_image" 
                                            class="color-nav-button" 
                                            onclick="changeBackgroundImage(-1)"
                                            title="{{ __('messages.previous') }}">
                                        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-5 h-5">
                                            <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 19.5L8.25 12l7.5-7.5" />
                                        </svg>
                                    </button>
                                                                                
                                    <button type="button" 
                                            id="next_image" 
                                            class="color-nav-button" 
                                            onclick="changeBackgroundImage(1)"
                                            title="{{ __('messages.next') }}">
                                        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-5 h-5">
                                            <path stroke-linecap="round" stroke-linejoin="round" d="M8.25 4.5l7.5 7.5-7.5 7.5" />
                                        </svg>
                                    </button>
        
                                </div>

                                <div id="custom_image_input" style="display:none">
                                    <input id="background_image_url" name="background_image_url" type="file" 
                                        class="mt-1 block w-full text-gray-900 dark:text-gray-100" 
                                        :value="old('background_image_url')" 
                                        oninput="updatePreview()" 
                                        accept="image/png, image/jpeg" />
                                    <p id="background_image_size_warning" class="mt-2 text-sm text-red-600 dark:text-red-400" style="display: none;">
                                        {{ __('messages.image_size_warning') }}
                                    </p>

                                    <img id="background_image_preview" src="" alt="Background Image Preview" style="max-height:120px; display:none;" class="pt-3" />

                                    @if ($role->background_image_url)
                                    <img src="{{ $role->background_image_url }}" style="max-height:120px" class="pt-3" />
                                    <a href="#"
                                        onclick="var confirmed = confirm('{{ __('messages.are_you_sure') }}'); if (confirmed) { location.href = '{{ route('role.delete_image', ['subdomain' => $role->subdomain, 'image_type' => 'background']) }}'; } return false;"
                                        class="hover:underline text-gray-900 dark:text-gray-100">
                                        {{ __('messages.delete_image') }}
                                    </a>
                                    @endif
                                </div>
                            </div>

                            <div id="style_background_gradient" style="display:none">
                                <div class="mb-6">
                                    <x-input-label for="background_colors" :value="__('messages.colors')" />
                                    <div class="color-select-container">
                                        <select id="background_colors" name="background_colors" oninput="updatePreview(); updateColorNavButtons()"
                                            class="flex-grow border-gray-300 dark:border-gray-700 dark:bg-gray-900 dark:text-gray-300 focus:border-[#4E81FA] dark:focus:border-[#4E81FA] focus:ring-[#4E81FA] dark:focus:ring-[#4E81FA] rounded-md shadow-sm w-64 max-w-64">
                                            @foreach($gradients as $gradient => $name)
                                            <option value="{{ $gradient }}"
                                                {{ $role->background_colors == $gradient || (! array_key_exists($role->background_colors, $gradients) && ! $gradient) ? 'SELECTED' : '' }}>
                                                {{ $name }}</option>
                                            @endforeach
                                        </select>
                                    
                                        <button type="button" 
                                                id="prev_color" 
                                                class="color-nav-button" 
                                                onclick="changeBackgroundColor(-1)"
                                                title="{{ __('messages.previous') }}">
                                            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-5 h-5">
                                                <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 19.5L8.25 12l7.5-7.5" />
                                            </svg>
                                        </button>
                                                                                
                                        <button type="button" 
                                                id="next_color" 
                                                class="color-nav-button" 
                                                onclick="changeBackgroundColor(1)"
                                                title="{{ __('messages.next') }}">
                                            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-5 h-5">
                                                <path stroke-linecap="round" stroke-linejoin="round" d="M8.25 4.5l7.5 7.5-7.5 7.5" />
                                            </svg>
                                        </button>
                                    </div>
                                    <div class="text-xs pt-1">
                                        <a href="https://uigradients.com" target="_blank" class="hover:underline text-gray-600 dark:text-gray-400">{{ __('messages.gradients_from', ['name' => 'uiGradients']) }}</a>
                                    </div>
                                    <x-input-error class="mt-2" :messages="$errors->get('background_colors')" />

                                    <div id="custom_colors" style="display:none" class="mt-4">
                                        <x-text-input id="custom_color1" name="custom_color1" type="color"
                                            class="mt-1 block w-1/2"
                                            :value="old('custom_color1', $role->background_colors ? explode(', ', $role->background_colors)[0] : '')"
                                            oninput="updatePreview()" />
                                        <x-text-input id="custom_color2" name="custom_color2" type="color"
                                            class="mt-1 block w-1/2"
                                            :value="old('custom_color2', $role->background_colors ? explode(', ', $role->background_colors)[1] : '')"
                                            oninput="updatePreview()" />
                                    </div>
                                </div>

                                <div class="mb-6">
                                    <x-input-label for="background_rotation" :value="__('messages.rotation')" />
                                    <x-text-input id="background_rotation" name="background_rotation" type="number"
                                        class="mt-1 block w-32 max-w-32" oninput="updatePreview()"
                                        :value="old('background_rotation', $role->background_rotation)" min="0" max="360" />
                                    <x-input-error class="mt-2" :messages="$errors->get('background_rotation')" />
                                </div>
                            </div>

                            <div class="mb-6">
                                <x-input-label for="accent_color" :value="__('messages.accent_color')" />
                                <x-text-input id="accent_color" name="accent_color" type="color" class="mt-1 block w-1/2"
                                    :value="old('accent_color', $role->accent_color)" />
                                <x-input-error class="mt-2" :messages="$errors->get('accent_color')" />
                            </div>

                        </div>

                        <div class="w-full flex-grow">
                            <x-input-label :value="__('messages.preview')" />
                            <div id="preview" class="h-full w-full flex-grow"></div>
                        </div>
                    </div>
                </div>

                </div>

                <div class="p-4 sm:p-8 bg-white dark:bg-gray-800 shadow-md sm:rounded-lg" id="address">
                    <div class="max-w-xl">

                        <h2 class="text-lg font-medium text-gray-900 dark:text-gray-100 mb-6">
                            {{ __('messages.schedule_settings') }}
                        </h2>
                        
                        @if ($role->exists)
                        <div class="mb-6" id="url-display">
                            <x-input-label :value="__('messages.schedule_url')" />
                            <p class="text-sm text-gray-500 flex items-center gap-2 mt-1">
                                <a href="{{ $role->getGuestUrl() }}" target="_blank" class="hover:underline">
                                    {{ \App\Utils\UrlUtils::clean($role->getGuestUrl()) }}
                                </a>
                                <button type="button" onclick="copyRoleUrl(this)" class="text-gray-500 hover:text-gray-700 dark:hover:text-gray-300" title="{{ __('messages.copy_url') }}">
                                    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-5 h-5">
                                        <path stroke-linecap="round" stroke-linejoin="round" d="M19,21H8V7H19M19,5H8A2,2 0 0,0 6,7V21A2,2 0 0,0 8,23H19A2,2 0 0,0 21,21V7A2,2 0 0,0 19,5M16,1H4A2,2 0 0,0 2,3V17H4V3H16V1Z" />
                                    </svg>
                                </button>
                                <button type="button" onclick="toggleSubdomainEdit()" class="text-gray-500 hover:text-gray-700 dark:hover:text-gray-300 ml-2" title="{{ __('messages.edit_url') }}">
                                    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-5 h-5">
                                        <path stroke-linecap="round" stroke-linejoin="round" d="M16.862 4.487l1.687-1.688a1.875 1.875 0 112.652 2.652L10.582 16.07a4.5 4.5 0 01-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 011.13-1.897l8.932-8.931zm0 0L19.5 7.125M18 14v4.75A2.25 2.25 0 0115.75 21H5.25A2.25 2.25 0 013 18.75V8.25A2.25 2.25 0 015.25 6H10" />
                                    </svg>
                                </button>
                            </p>
                        </div>
                        <div class="hidden" id="subdomain-edit">
                            <div class="mb-6">
                                <x-input-label for="new_subdomain" :value="__('messages.subdomain')" />
                                <x-text-input id="new_subdomain" name="new_subdomain" type="text" class="mt-1 block w-full"
                                    :value="old('new_subdomain', $role->subdomain)" required minlength="4" maxlength="50"
                                    pattern="[a-z0-9-]+" oninput="this.value = this.value.toLowerCase().replace(/[^a-z0-9-]/g, '')" />
                                <x-input-error class="mt-2" :messages="$errors->get('new_subdomain')" />
                            </div>

                            <div class="mb-6">
                                <x-input-label for="custom_domain" :value="__('messages.custom_domain')" />
                                <x-text-input id="custom_domain" name="custom_domain" type="url" class="mt-1 block w-full"
                                    :value="old('custom_domain', $role->custom_domain)" />
                                <x-input-error class="mt-2" :messages="$errors->get('custom_domain')" />
                            </div>
                        </div>
                        @endif

                        <div class="mb-6">
                            <x-input-label for="language_code" :value="__('messages.language') " />
                            <select name="language_code" id="language_code" required
                                class="border-gray-300 dark:border-gray-700 dark:bg-gray-900 dark:text-gray-300 focus:border-[#4E81FA] dark:focus:border-[#4E81FA] focus:ring-[#4E81FA] dark:focus:ring-[#4E81FA] rounded-md shadow-sm">
                                @foreach([
                                'ar' => 'arabic',
                                'en' => 'english',
                                'nl' => 'dutch',
                                'fr' => 'french',
                                'de' => 'german',
                                'he' => 'hebrew',
                                'it' => 'italian',
                                'pt' => 'portuguese',
                                'es' => 'spanish',
                                ] as $key => $value)
                                <option value="{{ $key }}" {{ $role->language_code == $key ? 'SELECTED' : '' }}>
                                    {{ __('messages.' . $value) }}
                                </option>
                                @endforeach
                            </select>
                            <x-input-error class="mt-2" :messages="$errors->get('language_code')" />
                        </div>

                        <div class="mb-6">
                            <x-input-label for="timezone" :value="__('messages.timezone')" />
                            <select name="timezone" id="timezone" required
                                class="border-gray-300 dark:border-gray-700 dark:bg-gray-900 dark:text-gray-300 focus:border-[#4E81FA] dark:focus:border-[#4E81FA] focus:ring-[#4E81FA] dark:focus:ring-[#4E81FA] rounded-md shadow-sm">
                                @foreach(\Carbon\CarbonTimeZone::listIdentifiers() as $timezone)
                                <option value="{{ $timezone }}" {{ $role->timezone == $timezone ? 'SELECTED' : '' }}>
                                    {{ $timezone }}
                                </option>
                                @endforeach
                            </select>
                            <x-input-error class="mt-2" :messages="$errors->get('timezone')" />
                        </div>

                        <div class="mb-6">
                            <x-checkbox name="use_24_hour_time" label="{{ __('messages.use_24_hour_time_format') }}"
                                checked="{{ old('use_24_hour_time', $role->use_24_hour_time) }}"
                                data-custom-attribute="value" />
                            <x-input-error class="mt-2" :messages="$errors->get('use_24_hour_time')" />
                        </div>

                        @if ((config('app.hosted') || config('app.is_testing')) && ($role->isVenue() || $role->isCurator()))
                        <div class="mb-6">
                            <x-checkbox name="accept_requests"
                                label="{{ __('messages.accept_requests') }}"
                                checked="{{ old('accept_requests', $role->accept_requests) }}"
                                data-custom-attribute="value" />
                            <x-input-error class="mt-2" :messages="$errors->get('accept_requests')" />
                        </div>
                        <div class="mb-6" id="require_approval_section">
                            <x-checkbox name="require_approval"
                                label="{{ __('messages.require_approval') }}"
                                checked="{{ old('require_approval', $role->exists ? $role->require_approval : true) }}"
                                data-custom-attribute="value" />
                            <x-input-error class="mt-2" :messages="$errors->get('require_approval')" />
                        </div>
                        <div class="mb-6" id="request_terms_section">
                            <x-input-label for="request_terms" :value="__('messages.request_terms')" />
                            <textarea id="request_terms" name="request_terms"
                                class="mt-1 block w-full border-gray-300 dark:border-gray-700 dark:bg-gray-900 dark:text-gray-300 focus:border-[#4E81FA] dark:focus:border-[#4E81FA] focus:ring-[#4E81FA] dark:focus:ring-[#4E81FA] rounded-md shadow-sm"
                                rows="4"
                                placeholder="{{ __('messages.enter_request_terms') }}">{{ old('request_terms', $role->request_terms) }}</textarea>
                            <x-input-error class="mt-2" :messages="$errors->get('request_terms')" />
                        </div>
                        @endif

                        <!--
                        <div class="mb-6">
                            <x-checkbox name="is_unlisted"
                                label="{{ __('messages.is_unlisted') }}"
                                checked="{{ old('is_unlisted', $role->is_unlisted) }}"
                                data-custom-attribute="value" />
                            <x-input-error class="mt-2" :messages="$errors->get('is_unlisted')" />
                        </div>
                        -->

                        
                    </div>
                </div>

                <div class="p-4 sm:p-8 bg-white dark:bg-gray-800 shadow-md sm:rounded-lg" id="address">
                    <div class="max-w-xl">

                        <h2 class="text-lg font-medium text-gray-900 dark:text-gray-100 mb-6">
                            {{ __('messages.subschedules') }}
                        </h2>

                        <div class="mb-6">
                            <div id="groups-list">
                                @php $groups = $role->groups ?? []; @endphp
                                <div id="group-items">
                                    @foreach(old('groups', $groups) as $i => $group)
                                        <div class="mb-4 p-4 border border-gray-200 dark:border-gray-700 rounded-lg">
                                            <div class="mb-4">
                                                <x-input-label for="group_name_{{ is_object($group) ? $group->id : $i }}" :value="__('messages.name')" />
                                                <x-text-input name="groups[{{ is_object($group) ? $group->id : $i }}][name]" type="text" class="mt-1 block w-full" :value="is_object($group) ? $group->name : $group['name'] ?? ''" />
                                            </div>
                                            @if($role->language_code !== 'en' || auth()->user()->language_code !== 'en')
                                            <div class="mb-4">
                                                <x-input-label for="group_name_en_{{ is_object($group) ? $group->id : $i }}" :value="__('messages.english_name')" />
                                                <x-text-input name="groups[{{ is_object($group) ? $group->id : $i }}][name_en]" type="text" class="mt-1 block w-full" :value="is_object($group) ? $group->name_en : $group['name_en'] ?? ''" />
                                            </div>
                                            @endif
                                            @if((is_object($group) && $group->slug) || (is_array($group) && !empty($group['slug'])))
                                            <div class="mb-4" id="group-url-display-{{ is_object($group) ? $group->id : $i }}">
                                                <p class="text-sm text-gray-500 flex items-center gap-2">
                                                    <a href="{{ $role->getGuestUrl() }}/{{ is_object($group) ? $group->slug : $group['slug'] ?? '' }}" target="_blank" class="hover:underline">
                                                        {{ \App\Utils\UrlUtils::clean($role->getGuestUrl()) }}/{{ is_object($group) ? $group->slug : $group['slug'] ?? '' }}
                                                    </a>
                                                    <button type="button" onclick="copyGroupUrl(this, '{{ $role->getGuestUrl() }}/{{ is_object($group) ? $group->slug : $group['slug'] ?? '' }}')" class="text-gray-500 hover:text-gray-700 dark:hover:text-gray-300" title="{{ __('messages.copy_url') }}">
                                                        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-5 h-5">
                                                            <path stroke-linecap="round" stroke-linejoin="round" d="M19,21H8V7H19M19,5H8A2,2 0 0,0 6,7V21A2,2 0 0,0 8,23H19A2,2 0 0,0 21,21V7A2,2 0 0,0 19,5M16,1H4A2,2 0 0,0 2,3V17H4V3H16V1Z" />
                                                        </svg>
                                                    </button>
                                                </p>
                                            </div>
                                            <div class="mb-4 {{ (is_object($group) && $group->slug) || (is_array($group) && !empty($group['slug'])) ? 'hidden' : '' }}" id="group-slug-edit-{{ is_object($group) ? $group->id : $i }}">
                                                <x-input-label for="group_slug_{{ is_object($group) ? $group->id : $i }}" :value="__('messages.slug')" />
                                                <x-text-input name="groups[{{ is_object($group) ? $group->id : $i }}][slug]" type="text" class="mt-1 block w-full" :value="is_object($group) ? $group->slug : $group['slug'] ?? ''" />
                                            </div>
                                            <div class="flex gap-4 items-center">
                                                <x-secondary-button type="button" onclick="toggleGroupSlugEdit('{{ is_object($group) ? $group->id : $i }}')" id="edit-button-{{ is_object($group) ? $group->id : $i }}">
                                                    {{ __('messages.edit') }}
                                                </x-secondary-button>
                                                @if((is_object($group) && $group->slug) || (is_array($group) && !empty($group['slug'])))
                                                <x-secondary-button type="button" onclick="toggleGroupSlugEdit('{{ is_object($group) ? $group->id : $i }}')" class="hidden" id="cancel-button-{{ is_object($group) ? $group->id : $i }}">
                                                    {{ __('messages.cancel') }}
                                                </x-secondary-button>
                                                @endif
                                                <x-secondary-button onclick="this.parentElement.parentElement.remove()" type="button">
                                                    {{ __('messages.remove') }}
                                                </x-secondary-button>
                                            </div>
                                            @else
                                            <div class="flex gap-4 items-center">
                                                <x-secondary-button onclick="this.parentElement.parentElement.remove()" type="button">
                                                    {{ __('messages.remove') }}
                                                </x-secondary-button>
                                            </div>
                                            @endif
                                        </div>
                                    @endforeach
                                </div>
                                <x-secondary-button type="button" onclick="addGroupField()">
                                    {{ __('messages.add') }}
                                </x-secondary-button>
                            </div>
                            <x-input-error class="mt-2" :messages="$errors->get('groups')" />
                        </div>

                    </div>
                </div>

                <div class="p-4 sm:p-8 bg-white dark:bg-gray-800 shadow-md sm:rounded-lg" id="import-settings">
                    <div class="max-w-xl">

                        <h2 class="text-lg font-medium text-gray-900 dark:text-gray-100 mb-6">
                            {{ __('messages.auto_import_settings') }}
                        </h2>

                        <div class="mb-6">
                            <h3 class="text-md font-medium text-gray-900 dark:text-gray-100 mb-4">
                                {{ __('messages.import_urls') }}
                            </h3>
                            <div id="import-urls-list">
                                <div id="import-url-items">
                                    @php $urls = $role->import_config['urls'] ?? []; @endphp
                                    @foreach(old('import_urls', $urls) as $i => $url)
                                        <div class="mb-4 p-4 border border-gray-200 dark:border-gray-700 rounded-lg">
                                            <div class="mb-4">
                                                <x-input-label for="import_url_{{ $i }}" :value="__('messages.url')" />
                                                <x-text-input name="import_urls[]" type="url" class="mt-1 block w-full" :value="$url" placeholder="https://example.com/events" />
                                            </div>
                                            <div class="flex gap-4 items-center">
                                                <x-secondary-button onclick="this.parentElement.parentElement.remove()" type="button">
                                                    {{ __('messages.remove') }}
                                                </x-secondary-button>
                                            </div>
                                        </div>
                                    @endforeach
                                </div>
                                <x-secondary-button type="button" onclick="addImportUrlField()">
                                    {{ __('messages.add') }}
                                </x-secondary-button>
                            </div>
                            <x-input-error class="mt-2" :messages="$errors->get('import_urls')" />
                        </div>

                        <div class="mb-6">
                            <h3 class="text-md font-medium text-gray-900 dark:text-gray-100 mb-4">
                                {{ __('messages.import_cities') }}
                            </h3>
                            <div id="import-cities-list">
                                <div id="import-city-items">
                                    @php $cities = $role->import_config['cities'] ?? []; @endphp
                                    @foreach(old('import_cities', $cities) as $i => $city)
                                        <div class="mb-4 p-4 border border-gray-200 dark:border-gray-700 rounded-lg">
                                            <div class="mb-4">
                                                <x-input-label for="import_city_{{ $i }}" :value="__('messages.city')" />
                                                <x-text-input name="import_cities[]" type="text" class="mt-1 block w-full" :value="$city" placeholder="New York" />
                                            </div>
                                            <div class="flex gap-4 items-center">
                                                <x-secondary-button onclick="this.parentElement.parentElement.remove()" type="button">
                                                    {{ __('messages.remove') }}
                                                </x-secondary-button>
                                            </div>
                                        </div>
                                    @endforeach
                                </div>
                                <x-secondary-button type="button" onclick="addImportCityField()">
                                    {{ __('messages.add') }}
                                </x-secondary-button>
                            </div>
                            <x-input-error class="mt-2" :messages="$errors->get('import_cities')" />
                        </div>

                        @if ($role->exists)
                        <div class="mb-6">
                            <x-secondary-button onclick="testImport()" type="button">
                                {{ __('messages.test_import') }}
                            </x-secondary-button>
                        </div>
                        @endif
                        
                    </div>
                </div>

                @if (auth()->user()->google_token || auth()->user()->isAdmin())
                <div class="p-4 sm:p-8 bg-white dark:bg-gray-800 shadow-md sm:rounded-lg">
                    <div class="max-w-xl">

                        <h2 class="text-lg font-medium text-gray-900 dark:text-gray-100 mb-6">
                            {{ __('Google Calendar Integration') }}
                        </h2>
                        <p class="text-sm text-gray-600 dark:text-gray-400 mb-6">
                            {{ __('Sync events between this role and your Google Calendar.') }}
                        </p>
                        
                        <div class="space-y-6">
                            <!-- Calendar Selection -->
                            <div>
                                <x-input-label for="google-calendar-select" :value="__('Select Google Calendar')" />
                                <select id="google-calendar-select" class="mt-1 block w-full border-gray-300 dark:border-gray-700 dark:bg-gray-900 dark:text-gray-300 focus:border-[#4E81FA] dark:focus:border-[#4E81FA] focus:ring-[#4E81FA] dark:focus:ring-[#4E81FA] rounded-md shadow-sm">
                                    <option value="">{{ __('Loading calendars...') }}</option>
                                </select>
                            </div>

                            <!-- Sync Direction Selection -->
                            <div>
                                <x-input-label :value="__('Sync Direction')" />
                                <div class="mt-2 space-y-2">
                                    <label class="flex items-center">
                                        <input type="radio" 
                                               name="sync_direction" 
                                               value="to" 
                                               {{ $role->sync_direction === 'to' ? 'checked' : '' }}
                                               class="border-gray-300 dark:border-gray-700 focus:ring-[#4E81FA] dark:focus:ring-[#4E81FA] h-4 w-4">
                                        <span class="ml-2 text-sm text-gray-700 dark:text-gray-300">
                                            {{ __('To Google Calendar') }} - {{ __('Events from Event Schedule will appear in Google Calendar') }}
                                        </span>
                                    </label>
                                    <label class="flex items-center">
                                        <input type="radio" 
                                               name="sync_direction" 
                                               value="from" 
                                               {{ $role->sync_direction === 'from' ? 'checked' : '' }}
                                               class="border-gray-300 dark:border-gray-700 focus:ring-[#4E81FA] dark:focus:ring-[#4E81FA] h-4 w-4">
                                        <span class="ml-2 text-sm text-gray-700 dark:text-gray-300">
                                            {{ __('From Google Calendar') }} - {{ __('Events from Google Calendar will appear in Event Schedule') }}
                                        </span>
                                    </label>
                                    <label class="flex items-center">
                                        <input type="radio" 
                                               name="sync_direction" 
                                               value="both" 
                                               {{ $role->sync_direction === 'both' ? 'checked' : '' }}
                                               class="border-gray-300 dark:border-gray-700 focus:ring-[#4E81FA] dark:focus:ring-[#4E81FA] h-4 w-4">
                                        <span class="ml-2 text-sm text-gray-700 dark:text-gray-300">
                                            {{ __('Bidirectional Sync') }} - {{ __('Events added in either place will appear in both') }}
                                        </span>
                                    </label>
                                    <label class="flex items-center">
                                        <input type="radio" 
                                               name="sync_direction" 
                                               value="" 
                                               {{ !$role->sync_direction ? 'checked' : '' }}
                                               class="border-gray-300 dark:border-gray-700 focus:ring-[#4E81FA] dark:focus:ring-[#4E81FA] h-4 w-4">
                                        <span class="ml-2 text-sm text-gray-700 dark:text-gray-300">
                                            {{ __('No Sync') }} - {{ __('Disable Google Calendar synchronization') }}
                                        </span>
                                    </label>
                                </div>
                            </div>

                            <!-- Manual Sync Button -->
                            <div>
                                <x-secondary-button type="button" onclick="syncEvents()" id="sync-events-button">
                                    {{ __('Sync Events') }}
                                </x-secondary-button>
                            </div>

                            <!-- Status Messages -->
                            <div id="sync-status" class="hidden">
                                <div class="flex items-center text-blue-600 dark:text-blue-400">
                                    <svg class="animate-spin -ml-1 mr-3 h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                                        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                                        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                                    </svg>
                                    <span class="text-sm">{{ __('Syncing...') }}</span>
                                </div>
                            </div>

                            <div id="sync-results" class="hidden">
                                <div class="p-3 bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800 rounded-lg">
                                    <div class="text-sm text-green-800 dark:text-green-200">
                                        <div id="sync-message"></div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
                @endif
                    
            </div>            
        </div>


        <div class="max-w-7xl mx-auto space-y-6 mt-3">
            @if (! $role->exists)
            <p class="text-base dark:text-gray-400 text-gray-600 pb-2">
                {{ __('messages.note_all_schedules_are_publicly_listed') }}
            </p>
            @endif

            <div class="flex gap-4 items-center justify-between">
                <div class="flex gap-4">
                    <x-primary-button>{{ __('messages.save') }}</x-primary-button>
                    <x-cancel-button></x-cancel-button>
                </div>

            </div>

        </div>

    </form>

</x-app-admin-layout>

<script {!! nonce_attr() !!}>
function addGroupField() {
    const container = document.getElementById('group-items');
    const idx = container.children.length;
    const div = document.createElement('div');
    div.className = 'mb-4 p-4 border border-gray-200 dark:border-gray-700 rounded-lg';
    div.innerHTML = `
        <div class="mb-4">
            <label for="group_name_new_${idx}" class="block font-medium text-sm text-gray-700 dark:text-gray-300">{{ __('messages.name') }}</label>
            <input name="groups[new_${idx}][name]" type="text" id="group_name_new_${idx}" class="mt-1 block w-full border-gray-300 dark:border-gray-700 dark:bg-gray-900 dark:text-gray-300 focus:border-[#4E81FA] dark:focus:border-[#4E81FA] focus:ring-[#4E81FA] dark:focus:ring-[#4E81FA] rounded-md shadow-sm" />
        </div>
        @if($role->language_code !== 'en' || auth()->user()->language_code !== 'en')
        <div class="mb-4">
            <label for="group_name_en_new_${idx}" class="block font-medium text-sm text-gray-700 dark:text-gray-300">{{ __('messages.english_name') }}</label>
            <input name="groups[new_${idx}][name_en]" type="text" id="group_name_en_new_${idx}" class="mt-1 block w-full border-gray-300 dark:border-gray-700 dark:bg-gray-900 dark:text-gray-300 focus:border-[#4E81FA] dark:focus:border-[#4E81FA] focus:ring-[#4E81FA] dark:focus:ring-[#4E81FA] rounded-md shadow-sm" />
        </div>
        @endif
        <div class="flex gap-4 items-center">
            <button type="button" class="inline-flex items-center px-4 py-2 bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-500 rounded-md font-semibold text-xs text-gray-700 dark:text-gray-300 uppercase tracking-widest shadow-sm hover:bg-gray-50 dark:hover:bg-gray-700 focus:outline-none focus:ring-2 focus:ring-[#4E81FA] focus:ring-offset-2 dark:focus:ring-offset-gray-800 disabled:opacity-25 transition ease-in-out duration-150" onclick="this.parentElement.parentElement.remove()">
                {{ __('messages.remove') }}
            </button>
        </div>
    `;
    container.appendChild(div);
}

function copyRoleUrl(button) {
    const url = '{{ $role->exists ? $role->getGuestUrl() : "" }}';
    navigator.clipboard.writeText(url).then(() => {
        const originalHTML = button.innerHTML;
        button.innerHTML = `
            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-5 h-5">
                <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5" />
            </svg>
        `;
        setTimeout(() => {
            button.innerHTML = originalHTML;
        }, 2000);
    });
}

function toggleSubdomainEdit() {
    const urlDisplay = document.getElementById('url-display');
    const subdomainEdit = document.getElementById('subdomain-edit');
    
    if (urlDisplay.classList.contains('hidden')) {
        urlDisplay.classList.remove('hidden');
        subdomainEdit.classList.add('hidden');
    } else {
        urlDisplay.classList.add('hidden');
        subdomainEdit.classList.remove('hidden');
        document.getElementById('new_subdomain').focus();
    }
}

function copyGroupUrl(button, url) {
    navigator.clipboard.writeText(url).then(() => {
        const originalHTML = button.innerHTML;
        button.innerHTML = `
            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-5 h-5">
                <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5" />
            </svg>
        `;
        setTimeout(() => {
            button.innerHTML = originalHTML;
        }, 2000);
    });
}

function toggleGroupSlugEdit(groupId) {
    const urlDisplay = document.getElementById(`group-url-display-${groupId}`);
    const slugEdit = document.getElementById(`group-slug-edit-${groupId}`);
    const cancelButton = document.getElementById(`cancel-button-${groupId}`);
    const editButton = document.getElementById(`edit-button-${groupId}`);
    
    if (urlDisplay.classList.contains('hidden')) {
        urlDisplay.classList.remove('hidden');
        slugEdit.classList.add('hidden');
        if (cancelButton) {
            cancelButton.classList.add('hidden');
        }
        if (editButton) {
            editButton.classList.remove('hidden');
        }
    } else {
        urlDisplay.classList.add('hidden');
        slugEdit.classList.remove('hidden');
        if (cancelButton) {
            cancelButton.classList.remove('hidden');
        }
        if (editButton) {
            editButton.classList.add('hidden');
        }
        document.getElementById(`group_slug_${groupId}`).focus();
    }
}

function testImport() {
    // Collect URLs from the new structure
    const urlInputs = document.querySelectorAll('input[name^="import_urls["]');
    const urls = Array.from(urlInputs).map(input => input.value.trim()).filter(url => url);
    
    // Collect cities from the new structure
    const cityInputs = document.querySelectorAll('input[name^="import_cities["]');
    const cities = Array.from(cityInputs).map(input => input.value.trim()).filter(city => city);
    
    if (urls.length === 0 && cities.length === 0) {
        alert('{{ __("messages.please_enter_urls_or_cities") }}');
        return;
    }
    
    // Show loading state
    const button = event.target;
    const originalText = button.textContent;
    button.textContent = '{{ __("messages.testing") }}...';
    button.disabled = true;
    
    // Only test import if we have a subdomain (existing role)
    @if($role->exists)
    // Make AJAX request to run console command
    fetch('{{ route("role.test_import", ["subdomain" => $role->subdomain]) }}', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'X-CSRF-TOKEN': '{{ csrf_token() }}'
        },
        body: JSON.stringify({
            urls: urls,
            cities: cities
        })
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            // Create a modal to show the detailed output
            showImportOutput(data.output, data.message);
        } else {
            // Show error output in modal
            showImportOutput(data.output || '', data.message, false);
        }
    })
    .catch(error => {
        showImportOutput('', '{{ __("messages.import_test_error") }}: ' + error.message, false);
    })
    .finally(() => {
        button.textContent = originalText;
        button.disabled = false;
    });
    @else
    // For new roles, just show a message
    alert('{{ __("messages.save_role_first_to_test_import") }}');
    button.textContent = originalText;
    button.disabled = false;
    @endif
}

function showImportOutput(output, message, isSuccess = true) {
    // Create modal HTML
    const modalHtml = `
        <div id="import-output-modal" class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50">
            <div class="relative top-20 mx-auto p-5 border w-11/12 md:w-3/4 lg:w-1/2 shadow-lg rounded-md bg-white dark:bg-gray-800">
                <div class="mt-3">
                    <div class="flex items-center justify-between mb-4">
                        <h3 class="text-lg font-medium text-gray-900 dark:text-gray-100">
                            {{ __("messages.import_test_results") }}
                        </h3>
                    </div>
                    
                    <div class="mb-4">
                        <div class="flex items-center mb-2">
                            <div class="w-3 h-3 rounded-full ${isSuccess ? 'bg-green-500' : 'bg-red-500'} mr-2"></div>
                            <span class="font-medium ${isSuccess ? 'text-green-700 dark:text-green-400' : 'text-red-700 dark:text-red-400'}">
                                ${message}
                            </span>
                        </div>
                    </div>
                    
                    ${output ? `
                        <div class="mb-4">
                            <h4 class="text-sm font-medium text-gray-900 dark:text-gray-100 mb-2">{{ __("messages.console_output") }}:</h4>
                            <div class="bg-gray-100 dark:bg-gray-700 rounded p-3 max-h-96 overflow-y-auto">
                                <pre class="text-xs text-gray-800 dark:text-gray-200 whitespace-pre-wrap">${output}</pre>
                            </div>
                        </div>
                    ` : ''}
                    
                    <div class="flex justify-end">
                        <button onclick="closeImportOutput()" class="px-4 py-2 bg-gray-300 dark:bg-gray-600 text-gray-700 dark:text-gray-300 rounded-md hover:bg-gray-400 dark:hover:bg-gray-500">
                            {{ __("messages.close") }}
                        </button>
                    </div>
                </div>
            </div>
        </div>
    `;
    
    // Add modal to page
    document.body.insertAdjacentHTML('beforeend', modalHtml);
}

function closeImportOutput() {
    const modal = document.getElementById('import-output-modal');
    if (modal) {
        modal.remove();
    }
}

function addImportUrlField() {
    const container = document.getElementById('import-url-items');
    const idx = container.children.length;
    const div = document.createElement('div');
    div.className = 'mb-4 p-4 border border-gray-200 dark:border-gray-700 rounded-lg';
    div.innerHTML = `
        <div class="mb-4">
            <label for="import_url_new_${idx}" class="block font-medium text-sm text-gray-700 dark:text-gray-300">{{ __('messages.url') }}</label>
            <input name="import_urls[new_${idx}]" type="url" id="import_url_new_${idx}" class="mt-1 block w-full border-gray-300 dark:border-gray-700 dark:bg-gray-900 dark:text-gray-300 focus:border-[#4E81FA] dark:focus:border-[#4E81FA] focus:ring-[#4E81FA] dark:focus:ring-[#4E81FA] rounded-md shadow-sm" placeholder="https://example.com/events" />
        </div>
        <div class="flex gap-4 items-center">
            <button type="button" class="inline-flex items-center px-4 py-2 bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-500 rounded-md font-semibold text-xs text-gray-700 dark:text-gray-300 uppercase tracking-widest shadow-sm hover:bg-gray-50 dark:hover:bg-gray-700 focus:outline-none focus:ring-2 focus:ring-[#4E81FA] focus:ring-offset-2 dark:focus:ring-offset-gray-800 disabled:opacity-25 transition ease-in-out duration-150" onclick="this.parentElement.parentElement.remove()">
                {{ __('messages.remove') }}
            </button>
        </div>
    `;
    container.appendChild(div);
}

function addImportCityField() {
    const container = document.getElementById('import-city-items');
    const idx = container.children.length;
    const div = document.createElement('div');
    div.className = 'mb-4 p-4 border border-gray-200 dark:border-gray-700 rounded-lg';
    div.innerHTML = `
        <div class="mb-4">
            <label for="import_city_new_${idx}" class="block font-medium text-sm text-gray-700 dark:text-gray-300">{{ __('messages.city') }}</label>
            <input name="import_cities[new_${idx}]" type="text" id="import_city_new_${idx}" class="mt-1 block w-full border-gray-300 dark:border-gray-700 dark:bg-gray-900 dark:text-gray-300 focus:border-[#4E81FA] dark:focus:border-[#4E81FA] focus:ring-[#4E81FA] dark:focus:ring-[#4E81FA] rounded-md shadow-sm" placeholder="New York" />
        </div>
        <div class="flex gap-4 items-center">
            <button type="button" class="inline-flex items-center px-4 py-2 bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-500 rounded-md font-semibold text-xs text-gray-700 dark:text-gray-300 uppercase tracking-widest shadow-sm hover:bg-gray-50 dark:hover:bg-gray-700 focus:outline-none focus:ring-2 focus:ring-[#4E81FA] focus:ring-offset-2 dark:focus:ring-offset-gray-800 disabled:opacity-25 transition ease-in-out duration-150" onclick="this.parentElement.parentElement.remove()">
                {{ __('messages.remove') }}
            </button>
        </div>
    `;
    container.appendChild(div);
}

// Google Calendar integration functions
document.addEventListener('DOMContentLoaded', function() {
    // Only load Google calendars if the Google Calendar section is present
    const googleCalendarSelect = document.getElementById('google-calendar-select');
    if (googleCalendarSelect) {
        loadGoogleCalendars();
    }
});

function loadGoogleCalendars() {
    const select = document.getElementById('google-calendar-select');
    if (!select) {
        console.warn('Google Calendar select element not found');
        return;
    }

    fetch('/google-calendar/calendars')
        .then(response => {
            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }
            return response.json();
        })
        .then(data => {
            select.innerHTML = '<option value="">{{ __("Select a calendar...") }}</option>';
            
            if (data.calendars && Array.isArray(data.calendars)) {
                data.calendars.forEach(calendar => {
                    const option = document.createElement('option');
                    option.value = calendar.id;
                    option.textContent = calendar.summary + (calendar.primary ? ' (Primary)' : '');
                    if (calendar.id === '{{ $role->google_calendar_id }}') {
                        option.selected = true;
                    }
                    select.appendChild(option);
                });
            } else {
                select.innerHTML = '<option value="">{{ __("No calendars available") }}</option>';
            }
        })
        .catch(error => {
            console.error('Error loading calendars:', error);
            let errorMessage = '{{ __("Error loading calendars") }}';
            
            if (error.message.includes('401')) {
                errorMessage = '{{ __("Google Calendar not connected. Please connect your account first.") }}';
            } else if (error.message.includes('403')) {
                errorMessage = '{{ __("Access denied. Please check your Google Calendar permissions.") }}';
            }
            
            select.innerHTML = `<option value="">${errorMessage}</option>`;
        });
}

function updateCalendarSelection() {
    const select = document.getElementById('google-calendar-select');
    const calendarId = select.value;
    
    if (!calendarId) return;
    
    fetch(`/google-calendar/role/{{ $role->subdomain }}`, {
        method: 'POST',
        headers: {
            'X-CSRF-TOKEN': document.querySelector('meta[name="csrf-token"]').getAttribute('content'),
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({ calendar_id: calendarId }),
    })
    .then(response => response.json())
    .then(data => {
        if (data.error) {
            alert('Error: ' + data.error);
        } else {
            showSyncMessage('Calendar updated successfully');
        }
    })
    .catch(error => {
        console.error('Error updating calendar:', error);
        alert('Error updating calendar: ' + error.message);
    });
}


function syncEvents() {
    const selectedDirection = document.querySelector('input[name="sync_direction"]:checked');
    const syncEventsButton = document.getElementById('sync-events-button');
    
    // Check if button is disabled
    if (syncEventsButton && syncEventsButton.disabled) {
        showSyncMessage('Please select a sync direction other than "No Sync" to enable syncing', 'error');
        return;
    }
    
    if (!selectedDirection || !selectedDirection.value) {
        showSyncMessage('Please select a sync direction first', 'error');
        return;
    }

    showSyncStatus();
    
    let url = '';
    let requestBody = {
        sync_direction: selectedDirection.value
    };
    
    if (selectedDirection.value === 'to') {
        url = '/google-calendar/sync-events';
    } else if (selectedDirection.value === 'from') {
        url = `/google-calendar/sync-from-google/{{ $role->subdomain }}`;
    } else if (selectedDirection.value === 'both') {
        // For bidirectional sync, we'll sync both directions
        syncBothDirections();
        return;
    } else {
        hideSyncStatus();
        showSyncMessage('Invalid sync direction selected', 'error');
        return;
    }
    
    fetch(url, {
        method: 'POST',
        headers: {
            'X-CSRF-TOKEN': document.querySelector('meta[name="csrf-token"]').getAttribute('content'),
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(requestBody),
    })
    .then(response => response.json())
    .then(data => {
        hideSyncStatus();
        if (data.error) {
            showSyncMessage('Error: ' + data.error, 'error');
        } else {
            showSyncMessage(data.message);
        }
    })
    .catch(error => {
        hideSyncStatus();
        showSyncMessage('Error: ' + error.message, 'error');
    });
}

function syncBothDirections() {
    showSyncStatus();
    
    const requestBody = {
        sync_direction: 'both'
    };
    
    // First sync to Google Calendar
    fetch('/google-calendar/sync-events', {
        method: 'POST',
        headers: {
            'X-CSRF-TOKEN': document.querySelector('meta[name="csrf-token"]').getAttribute('content'),
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(requestBody),
    })
    .then(response => response.json())
    .then(data => {
        if (data.error) {
            hideSyncStatus();
            showSyncMessage('Error syncing to Google Calendar: ' + data.error, 'error');
            return;
        }
        
        // Then sync from Google Calendar
        return fetch(`/google-calendar/sync-from-google/{{ $role->subdomain }}`, {
            method: 'POST',
            headers: {
                'X-CSRF-TOKEN': document.querySelector('meta[name="csrf-token"]').getAttribute('content'),
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(requestBody),
        });
    })
    .then(response => response.json())
    .then(data => {
        hideSyncStatus();
        if (data.error) {
            showSyncMessage('Error syncing from Google Calendar: ' + data.error, 'error');
        } else {
            showSyncMessage('Bidirectional sync completed successfully');
        }
    })
    .catch(error => {
        hideSyncStatus();
        showSyncMessage('Error during bidirectional sync: ' + error.message, 'error');
    });
}

function showSyncStatus() {
    document.getElementById('sync-status').classList.remove('hidden');
    document.getElementById('sync-results').classList.add('hidden');
}

function hideSyncStatus() {
    document.getElementById('sync-status').classList.add('hidden');
}

function showSyncMessage(message, type = 'success') {
    const resultsDiv = document.getElementById('sync-results');
    const messageDiv = document.getElementById('sync-message');
    
    messageDiv.textContent = message;
    
    if (type === 'error') {
        resultsDiv.querySelector('.bg-green-50').classList.remove('bg-green-50', 'border-green-200');
        resultsDiv.querySelector('.bg-green-50').classList.add('bg-red-50', 'border-red-200');
        resultsDiv.querySelector('.text-green-800').classList.remove('text-green-800');
        resultsDiv.querySelector('.text-green-800').classList.add('text-red-800');
    } else {
        resultsDiv.querySelector('.bg-red-50').classList.remove('bg-red-50', 'border-red-200');
        resultsDiv.querySelector('.bg-red-50').classList.add('bg-green-50', 'border-green-200');
        resultsDiv.querySelector('.text-red-800').classList.remove('text-red-800');
        resultsDiv.querySelector('.text-red-800').classList.add('text-green-800');
    }
    
    resultsDiv.classList.remove('hidden');
}

// Add event listeners for calendar selection and sync direction changes
document.addEventListener('DOMContentLoaded', function() {
    const calendarSelect = document.getElementById('google-calendar-select');
    if (calendarSelect) {
        calendarSelect.addEventListener('change', updateCalendarSelection);
    }
    
    // Add event listeners for sync direction radio buttons
    const syncDirectionRadios = document.querySelectorAll('input[name="sync_direction"]');
    const syncEventsButton = document.getElementById('sync-events-button');
    
    syncDirectionRadios.forEach(radio => {
        radio.addEventListener('change', function() {
            // Update the hidden field when radio button changes
            document.getElementById('sync_direction_hidden').value = this.value;
            
            // Enable/disable sync events button based on selection
            if (syncEventsButton) {
                syncEventsButton.disabled = !this.value || this.value === '';
            }
        });
    });
    
    // Set initial state of sync events button
    const selectedDirection = document.querySelector('input[name="sync_direction"]:checked');
    if (syncEventsButton && selectedDirection) {
        syncEventsButton.disabled = !selectedDirection.value || selectedDirection.value === '';
    }
});
</script>