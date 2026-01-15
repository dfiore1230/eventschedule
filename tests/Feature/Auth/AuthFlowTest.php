<?php

namespace Tests\Feature\Auth;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Notification;
use Illuminate\Auth\Notifications\ResetPassword;
use Tests\TestCase;

class AuthFlowTest extends TestCase
{
    use RefreshDatabase;

    public function test_registration_flow_creates_verified_user_and_authenticates(): void
    {
        config(['app.hosted' => true, 'app.is_testing' => true]);

        // Load the registration page to establish session and CSRF token
        $this->get('/sign_up');
        $token = session('_token');

        $response = $this->post('/sign_up', [
            '_token' => $token,
            'name' => 'New User',
            'email' => 'newuser@planify.test',
            'password' => 'password123',
            'language_code' => 'en',
        ]);

        $response->assertRedirect(route('home'));
        $this->assertAuthenticated();

        $user = User::where('email', 'newuser@planify.test')->first();
        $this->assertNotNull($user);
        $this->assertNotNull($user->email_verified_at);
    }

    public function test_user_can_login_and_logout(): void
    {
        $user = User::factory()->create(['password' => bcrypt('secret123')]);

        // Load the login page to set session and CSRF token
        $this->get('/login');
        $token = session('_token');

        $login = $this->post('/login', [
            '_token' => $token,
            'email' => $user->email,
            'password' => 'secret123',
        ]);

        if ($login->status() === 419) {
            echo "LOGIN RESPONSE: \n" . $login->getContent();
        }

        $login->assertRedirect();
        $this->assertAuthenticatedAs($user);

        // Include CSRF token for logout post
        $this->get('/');
        $logout = $this->post('/logout', ['_token' => session('_token')]);
        $logout->assertRedirect();
        $this->assertGuest();
    }

    public function test_password_reset_request_is_sent_for_verified_users(): void
    {
        Notification::fake();

        $user = User::factory()->create();

        $this->get(route('password.request'));
        $token = session('_token');

        $response = $this->post(route('password.email'), [
            '_token' => $token,
            'email' => $user->email,
        ]);

        if ($response->status() === 419) {
            echo "PASSWORD EMAIL RESPONSE: \n" . $response->getContent();
        }

        $response->assertSessionHas('status');
        Notification::assertSentTo($user, ResetPassword::class);
    }
}
