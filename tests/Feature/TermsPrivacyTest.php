<?php

namespace Tests\Feature;

use App\Models\Setting;
use App\Models\User;
use App\Models\Permission;
use App\Models\SystemRole;
use App\Services\Authorization\AuthorizationService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class TermsPrivacyTest extends TestCase
{
    use RefreshDatabase;

    public function test_terms_page_renders_markdown_html(): void
    {
        Setting::setGroup('general', [
            'terms_markdown' => "# Title\n\nThis is **bold** text.",
        ]);

        $response = $this->get(route('terms.show'));

        $response->assertStatus(200);
        $response->assertSee('<h1>', false);
        $response->assertSee('<strong>', false);
    }

    public function test_terms_page_converts_legacy_plaintext_html(): void
    {
        Setting::setGroup('general', [
            'terms_html' => "# Title\n\nLegacy **bold** text.",
        ]);

        $response = $this->get(route('terms.show'));

        $response->assertStatus(200);
        $response->assertSee('<h1>', false);
        $response->assertSee('<strong>', false);
    }

    public function test_privacy_page_renders_markdown_html(): void
    {
        Setting::setGroup('general', [
            'privacy_markdown' => "# Privacy\n\nWe use **cookies**.",
        ]);

        $response = $this->get(route('privacy.show'));

        $response->assertStatus(200);
        $response->assertSee('<h1>', false);
        $response->assertSee('<strong>', false);
    }

    public function test_privacy_page_converts_legacy_plaintext_html(): void
    {
        Setting::setGroup('general', [
            'privacy_html' => "# Privacy\n\nLegacy **cookies**.",
        ]);

        $response = $this->get(route('privacy.show'));

        $response->assertStatus(200);
        $response->assertSee('<h1>', false);
        $response->assertSee('<strong>', false);
    }

    public function test_markdown_converter_renders_headings(): void
    {
        $html = \App\Utils\MarkdownUtils::convertToHtml("# Heading\n\nContent");

        $this->assertStringContainsString('<h1>', $html);
        $this->assertStringContainsString('Heading', $html);
    }

    public function test_admin_can_update_privacy_settings(): void
    {
        $admin = $this->createManagerWithPermission('settings.manage');

        $response = $this->actingAs($admin)->patch(route('settings.privacy.update'), [
            'privacy_markdown' => '# Privacy',
        ]);

        $response->assertRedirect(route('settings.privacy'));
        $stored = Setting::forGroup('general');
        $this->assertSame('# Privacy', $stored['privacy_markdown'] ?? null);
        $this->assertNotNull($stored['privacy_html'] ?? null);
    }

    public function test_admin_can_refresh_terms_formatting(): void
    {
        $admin = $this->createManagerWithPermission('settings.manage');

        Setting::setGroup('general', [
            'terms_html' => "# Title\n\nLegacy **bold** text.",
        ]);

        $response = $this->actingAs($admin)->post(route('settings.terms.refresh'));

        $response->assertRedirect(route('settings.terms'));

        $stored = Setting::forGroup('general');
        $this->assertStringContainsString('<h1>', $stored['terms_html'] ?? '');
        $this->assertStringContainsString('<strong>', $stored['terms_html'] ?? '');
    }

    public function test_admin_can_refresh_privacy_formatting(): void
    {
        $admin = $this->createManagerWithPermission('settings.manage');

        Setting::setGroup('general', [
            'privacy_html' => "# Privacy\n\nLegacy **cookies**.",
        ]);

        $response = $this->actingAs($admin)->post(route('settings.privacy.refresh'));

        $response->assertRedirect(route('settings.privacy'));

        $stored = Setting::forGroup('general');
        $this->assertStringContainsString('<h1>', $stored['privacy_html'] ?? '');
        $this->assertStringContainsString('<strong>', $stored['privacy_html'] ?? '');
    }

    protected function createManagerWithPermission(string $permissionKey): User
    {
        $permission = Permission::query()->firstOrCreate(
            ['key' => $permissionKey],
            ['description' => 'Test permission']
        );

        $role = SystemRole::query()->firstOrCreate(['slug' => 'admin'], ['name' => 'Admin']);
        $role->permissions()->syncWithoutDetaching([$permission->id]);

        $user = User::factory()->create();
        $user->systemRoles()->attach($role);

        app(AuthorizationService::class)->warmUserPermissions($user);

        return $user;
    }
}
