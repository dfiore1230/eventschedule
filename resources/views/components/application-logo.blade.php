@php($logoAlt = branding_logo_alt())

<div class="p-6">
    <img class="h-10 md:h-12 w-auto dark:hidden" src="{{ branding_logo_url('light') }}" alt="{{ $logoAlt }}" />
    <img class="h-10 md:h-12 w-auto hidden dark:block" src="{{ branding_logo_url('dark') }}" alt="{{ $logoAlt }}" />
</div>
