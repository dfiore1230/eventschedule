<?php

namespace App\Http\Requests;

use App\Models\Role;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use App\Utils\UrlUtils;
use App\Rules\NoFakeEmail;
use App\Rules\SquareImage;

class RoleUpdateRequest extends FormRequest
{
    /**
     * Get the validation rules that apply to the request.
     *
     * @return array<string, \Illuminate\Contracts\Validation\Rule|array|string>
     */
    public function rules(): array
    {
        $role = Role::subdomain(request()->subdomain)->firstOrFail();

        return [
            'name' => ['required', 'string', 'max:255'],
            'email' => array_merge(
                ['required', 'string', 'email', 'max:255'],
                config('app.hosted') ? [new NoFakeEmail] : []
            ),
            'new_subdomain' => ['required', 'string', 'max:255', 'min:4', 'max:50'],
            'custom_domain' => ['nullable', 'string', 'url', 'max:255'],
            'profile_image' => ['image', 'max:2500', new SquareImage],
            'background_image_url' => ['image', 'max:2500'],
            'header_image_url' => ['image', 'max:2500'],
            'contacts' => ['nullable', 'array'],
            'contacts.*.name' => ['nullable', 'string', 'max:255'],
            'contacts.*.email' => array_merge(
                ['nullable', 'string', 'email', 'max:255'],
                config('app.hosted') ? [new NoFakeEmail] : []
            ),
            'contacts.*.phone' => ['nullable', 'string', 'max:255'],
        ];
    }
}
