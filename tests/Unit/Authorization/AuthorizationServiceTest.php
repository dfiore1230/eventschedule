<?php

namespace Tests\Unit\Authorization;

use App\Models\Permission;
use App\Models\SystemRole;
use App\Models\User;
use App\Services\Authorization\AuthorizationService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AuthorizationServiceTest extends TestCase
{
    use RefreshDatabase;

    public function test_permissions_are_warmed_and_cached_per_user(): void
    {
        // Use firstOrCreate to avoid duplicate key errors if default permissions are present
        $permission = Permission::query()->firstOrCreate([
            'key' => 'resources.manage'
        ], [
            'description' => 'Create and update venues, talent, and curators within scope',
        ]);

        // Ensure system role exists (avoid duplicate slug on MySQL where seed ran)
        $role = SystemRole::query()->firstOrCreate(['slug' => 'admin'], ['name' => 'Admin']);
        $role->permissions()->attach($permission);

        $user = User::factory()->create();
        $user->systemRoles()->attach($role);

        $service = $this->app->make(AuthorizationService::class);

        $warmed = $service->warmUserPermissions($user);

        $this->assertContains('resources.manage', $warmed);
        $this->assertTrue($service->userHasPermission($user, 'resources.manage'));

        $service->forgetUserPermissions($user);
        $user->systemRoles()->detach($role);

        $this->assertFalse($service->userHasPermission($user, 'resources.manage'));
    }

    public function test_user_has_any_permission_accepts_empty_sets(): void
    {
        $user = User::factory()->create();
        $service = $this->app->make(AuthorizationService::class);

        $this->assertTrue($service->userHasAnyPermission($user, []));
    }
}
