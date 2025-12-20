<?php

namespace Tests\Feature;

use Tests\TestCase;
use Illuminate\Foundation\Testing\RefreshDatabase;

class E2ESeedTest extends TestCase
{
    use RefreshDatabase;

    public function test_seed_marks_admin_verified_and_returns_expected_fields()
    {
        $response = $this->postJson('/__test/seed');

        $response->assertStatus(200);
        $response->assertJsonStructure(['admin_email', 'admin_password', 'created_user_ids', 'admin_email_verified']);

        $data = $response->json();
        $this->assertTrue((bool) ($data['admin_email_verified'] ?? false));
        $this->assertNotEmpty($data['created_user_ids']);
        $this->assertNotEmpty($data['admin_email']);

        $this->assertDatabaseHas('users', ['email' => $data['admin_email']]);
        $user = \App\Models\User::where('email', $data['admin_email'])->first();
        $this->assertNotNull($user->email_verified_at);
    }
}
