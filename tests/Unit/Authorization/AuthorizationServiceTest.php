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
        // Use syncWithoutDetaching to avoid duplicate entry errors on MySQL
        $role->permissions()->syncWithoutDetaching([$permission->id]);

        $user = User::factory()->create();
        $user->systemRoles()->attach($role);

        $service = $this->app->make(AuthorizationService::class);

        $warmed = $service->warmUserPermissions($user);

        $this->assertContains('resources.manage', $warmed);
        $this->assertTrue($service->userHasPermission($user, 'resources.manage'));

        // Detach role first then forget cache to ensure permissions reflect the DB state
        $user->systemRoles()->detach($role);
        // Also detach superadmin if it was auto-attached during user creation
        $user->systemRoles()->where('slug', 'superadmin')->detach();
        $service->forgetUserPermissions($user);

        // Ensure role detach persisted
        $this->assertFalse($user->systemRoles()->where('slug', 'admin')->exists());
        $this->assertFalse($user->systemRoles()->where('slug', 'superadmin')->exists());

        // Recompute permissions and ensure the specific permission is not present
        $recomputed = $service->warmUserPermissions($user);
        $this->assertNotContains('resources.manage', $recomputed, 'resources.manage should not be present after detaching admin role');

        $this->assertFalse($service->userHasPermission($user, 'resources.manage'));
    }

    public function test_user_has_any_permission_accepts_empty_sets(): void
    {
        $user = User::factory()->create();
        $service = $this->app->make(AuthorizationService::class);

        $this->assertTrue($service->userHasAnyPermission($user, []));
    }
}
