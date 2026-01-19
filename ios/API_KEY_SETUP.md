# API Key Setup Guide for Planify Backend

This guide is for backend administrators who need to create and manage API keys for the Planify iOS app.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Method 1: Laravel Sanctum (Recommended)](#method-1-laravel-sanctum-recommended)
4. [Method 2: Custom API Key System](#method-2-custom-api-key-system)
5. [Method 3: OAuth2/Passport](#method-3-oauth2passport)
6. [Testing API Keys](#testing-api-keys)
7. [Managing API Keys](#managing-api-keys)
8. [Security Best Practices](#security-best-practices)
9. [Troubleshooting](#troubleshooting)

## Overview

The Planify iOS app requires API key authentication to access your backend. This guide shows you how to:

- Generate API keys for users
- Configure your backend to accept API keys
- Test and validate API keys
- Manage and revoke keys

## Prerequisites

- Administrative access to your Planify backend
- SSH access to the server (for CLI methods)
- Database access (for direct methods)
- Laravel 8+ if using Sanctum/Passport

## Method 1: Laravel Sanctum (Recommended)

Laravel Sanctum is the recommended authentication method for the iOS app.

### Step 1: Install Sanctum (if not already installed)

```bash
composer require laravel/sanctum
php artisan vendor:publish --provider="Laravel\Sanctum\SanctumServiceProvider"
php artisan migrate
```

### Step 2: Configure the User Model

Ensure your `User` model uses the `HasApiTokens` trait:

```php
<?php

namespace App\Models;

use Illuminate\Foundation\Auth\User as Authenticatable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens;
    
    // ... rest of your model
}
```

### Step 3: Create API Keys via Artisan Command

Create a custom artisan command for generating API keys:

```bash
php artisan make:command CreateApiKey
```

Edit `app/Console/Commands/CreateApiKey.php`:

```php
<?php

namespace App\Console\Commands;

use App\Models\User;
use Illuminate\Console\Command;

class CreateApiKey extends Command
{
    protected $signature = 'api:key:create 
                            {user : The user ID or email}
                            {--name=iOS App : The token name}
                            {--abilities=* : The abilities to grant}';

    protected $description = 'Create an API key for a user';

    public function handle()
    {
        $userIdentifier = $this->argument('user');
        $name = $this->option('name');
        $abilities = $this->option('abilities');
        
        // Default to full access if no abilities specified
        if (empty($abilities)) {
            $abilities = ['*'];
        }

        // Find user by ID or email
        $user = is_numeric($userIdentifier)
            ? User::find($userIdentifier)
            : User::where('email', $userIdentifier)->first();

        if (!$user) {
            $this->error("User not found: {$userIdentifier}");
            return 1;
        }

        $token = $user->createToken($name, $abilities);

        $this->info("API Key created successfully for {$user->email}");
        $this->line('');
        $this->line("Token Name: {$name}");
        $this->line("User: {$user->name} ({$user->email})");
        $this->line('');
        $this->warn('API Key (save this, it will not be shown again):');
        $this->line($token->plainTextToken);
        $this->line('');
        $this->info('Abilities: ' . implode(', ', $abilities));

        return 0;
    }
}
```

### Step 4: Generate an API Key

```bash
# By user ID
php artisan api:key:create 1 --name="John's iPhone"

# By email
php artisan api:key:create admin@example.com --name="iOS App - Admin"

# With specific abilities
php artisan api:key:create 1 --name="Door Scanner" --abilities="scan:checkin,scan:checkout"
```

**Output:**
```
API Key created successfully for admin@example.com

Token Name: John's iPhone
User: John Doe (admin@example.com)

API Key (save this, it will not be shown again):
1|AbCdEfGhIjKlMnOpQrStUvWxYz1234567890

Abilities: *
```

### Step 5: Configure Sanctum Middleware

Update `app/Http/Kernel.php`:

```php
protected $middlewareGroups = [
    'api' => [
        \Laravel\Sanctum\Http\Middleware\EnsureFrontendRequestsAreStateful::class,
        'throttle:api',
        \Illuminate\Routing\Middleware\SubstituteBindings::class,
    ],
];
```

### Step 6: Configure Routes

In `routes/api.php`:

```php
use Illuminate\Support\Facades\Route;

Route::middleware(['auth:sanctum'])->group(function () {
    Route::get('/events', [EventController::class, 'index']);
    Route::post('/events', [EventController::class, 'store']);
    Route::get('/events/{event}', [EventController::class, 'show']);
    Route::put('/events/{event}', [EventController::class, 'update']);
    Route::delete('/events/{event}', [EventController::class, 'destroy']);
    
    Route::get('/venues', [VenueController::class, 'index']);
    Route::get('/talent', [TalentController::class, 'index']);
    Route::get('/tickets', [TicketController::class, 'index']);
    
    // Add other protected routes
});

// Public routes for discovery
Route::get('/meta/branding', [MetaController::class, 'branding']);
```

### Step 7: Support X-API-Key Header (Optional Enhancement)

The iOS app sends API keys in the `X-API-Key` header. Create middleware to support this:

```bash
php artisan make:middleware ConvertApiKeyToBearer
```

Edit `app/Http/Middleware/ConvertApiKeyToBearer.php`:

```php
<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

class ConvertApiKeyToBearer
{
    public function handle(Request $request, Closure $next)
    {
        // If X-API-Key header is present, convert it to Bearer token
        if ($request->hasHeader('X-API-Key')) {
            $apiKey = $request->header('X-API-Key');
            $request->headers->set('Authorization', "Bearer {$apiKey}");
        }

        return $next($request);
    }
}
```

Register in `app/Http/Kernel.php`:

```php
protected $middleware = [
    // ... other middleware
    \App\Http\Middleware\ConvertApiKeyToBearer::class,
];
```

## Method 2: Custom API Key System

If not using Sanctum, you can implement a custom API key system.

### Step 1: Create API Keys Table

```bash
php artisan make:migration create_api_keys_table
```

Edit the migration:

```php
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up()
    {
        Schema::create('api_keys', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->onDelete('cascade');
            $table->string('name');
            $table->string('key', 64)->unique();
            $table->text('abilities')->nullable();
            $table->timestamp('last_used_at')->nullable();
            $table->timestamp('expires_at')->nullable();
            $table->timestamps();
            
            $table->index('key');
            $table->index(['user_id', 'key']);
        });
    }

    public function down()
    {
        Schema::dropIfExists('api_keys');
    }
};
```

Run the migration:

```bash
php artisan migrate
```

### Step 2: Create ApiKey Model

```bash
php artisan make:model ApiKey
```

Edit `app/Models/ApiKey.php`:

```php
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Str;

class ApiKey extends Model
{
    protected $fillable = ['user_id', 'name', 'key', 'abilities', 'expires_at'];

    protected $casts = [
        'abilities' => 'array',
        'last_used_at' => 'datetime',
        'expires_at' => 'datetime',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public static function generate(User $user, string $name, array $abilities = ['*'], $expiresInDays = null)
    {
        $key = Str::random(64);
        
        $expiresAt = $expiresInDays 
            ? now()->addDays($expiresInDays) 
            : null;

        return self::create([
            'user_id' => $user->id,
            'name' => $name,
            'key' => $key,
            'abilities' => $abilities,
            'expires_at' => $expiresAt,
        ]);
    }

    public function isValid()
    {
        if ($this->expires_at && $this->expires_at->isPast()) {
            return false;
        }
        return true;
    }

    public function updateLastUsed()
    {
        $this->update(['last_used_at' => now()]);
    }
}
```

### Step 3: Create Authentication Middleware

```bash
php artisan make:middleware AuthenticateApiKey
```

Edit `app/Http/Middleware/AuthenticateApiKey.php`:

```php
<?php

namespace App\Http\Middleware;

use App\Models\ApiKey;
use Closure;
use Illuminate\Http\Request;

class AuthenticateApiKey
{
    public function handle(Request $request, Closure $next)
    {
        $apiKey = $request->header('X-API-Key');

        if (!$apiKey) {
            return response()->json(['error' => 'Unauthorized - API key required'], 401);
        }

        $key = ApiKey::where('key', $apiKey)->first();

        if (!$key || !$key->isValid()) {
            return response()->json(['error' => 'Unauthorized - Invalid or expired API key'], 401);
        }

        // Set the authenticated user
        auth()->setUser($key->user);
        
        // Update last used timestamp (optional - can be done async)
        $key->updateLastUsed();

        return $next($request);
    }
}
```

Register in `app/Http/Kernel.php`:

```php
protected $middlewareAliases = [
    // ... other middleware
    'auth.apikey' => \App\Http\Middleware\AuthenticateApiKey::class,
];
```

### Step 4: Create API Key Generation Command

```bash
php artisan make:command GenerateApiKey
```

Edit `app/Console/Commands/GenerateApiKey.php`:

```php
<?php

namespace App\Console\Commands;

use App\Models\ApiKey;
use App\Models\User;
use Illuminate\Console\Command;

class GenerateApiKey extends Command
{
    protected $signature = 'api:key:generate 
                            {user : User ID or email}
                            {--name=iOS App : Key name}
                            {--expires= : Expiration in days}';

    protected $description = 'Generate an API key for a user';

    public function handle()
    {
        $userIdentifier = $this->argument('user');
        $name = $this->option('name');
        $expires = $this->option('expires');

        $user = is_numeric($userIdentifier)
            ? User::find($userIdentifier)
            : User::where('email', $userIdentifier)->first();

        if (!$user) {
            $this->error("User not found: {$userIdentifier}");
            return 1;
        }

        $apiKey = ApiKey::generate($user, $name, ['*'], $expires);

        $this->info("API Key generated successfully!");
        $this->line('');
        $this->line("Name: {$apiKey->name}");
        $this->line("User: {$user->name} ({$user->email})");
        $this->line('');
        $this->warn('API Key (save this securely):');
        $this->line($apiKey->key);
        $this->line('');
        
        if ($apiKey->expires_at) {
            $this->info("Expires: {$apiKey->expires_at->toDateString()}");
        } else {
            $this->info("Expires: Never");
        }

        return 0;
    }
}
```

### Step 5: Use the Middleware in Routes

In `routes/api.php`:

```php
Route::middleware(['auth.apikey'])->group(function () {
    Route::apiResource('events', EventController::class);
    Route::apiResource('venues', VenueController::class);
    Route::apiResource('talent', TalentController::class);
    // ... other routes
});
```

### Step 6: Generate Keys

```bash
# Generate a key
php artisan api:key:generate 1 --name="iPhone 15"

# Generate with expiration
php artisan api:key:generate admin@example.com --name="Temporary Access" --expires=30
```

## Method 3: OAuth2/Passport

If using Laravel Passport for OAuth2:

### Step 1: Install Passport

```bash
composer require laravel/passport
php artisan migrate
php artisan passport:install
```

### Step 2: Create Personal Access Client

```bash
php artisan passport:client --personal
```

### Step 3: Generate Tokens via Artisan

Create a command similar to the Sanctum example above, but use Passport's token creation:

```php
$token = $user->createToken('iOS App')->accessToken;
```

## Testing API Keys

### Test with cURL

```bash
# Test events endpoint
curl -H "X-API-Key: YOUR_API_KEY_HERE" \
     https://your-domain.com/api/events

# Test with verbose output
curl -v -H "X-API-Key: YOUR_API_KEY_HERE" \
     https://your-domain.com/api/events

# Test discovery endpoint
curl https://your-domain.com/.well-known/planify.json

# Test branding endpoint
curl -H "X-API-Key: YOUR_API_KEY_HERE" \
     https://your-domain.com/api/meta/branding
```

### Expected Responses

**Success (200):**
```json
{
  "data": [
    {
      "id": "1",
      "name": "Concert Night",
      "starts_at": "2025-01-15T19:00:00Z",
      ...
    }
  ]
}
```

**Unauthorized (401):**
```json
{
  "error": "Unauthorized"
}
```

**Rate Limited (429):**
```json
{
  "error": "Too many requests"
}
```

## Managing API Keys

### List All Keys (Sanctum)

```bash
php artisan tinker
```

```php
use Laravel\Sanctum\PersonalAccessToken;

// List all tokens
PersonalAccessToken::all();

// List for specific user
$user = User::find(1);
$user->tokens;

// Get token details
PersonalAccessToken::where('name', "John's iPhone")->first();
```

### Revoke a Key (Sanctum)

```php
// By token name
$user = User::find(1);
$user->tokens()->where('name', "John's iPhone")->delete();

// By token ID
PersonalAccessToken::find($tokenId)->delete();

// Revoke all tokens for a user
$user->tokens()->delete();
```

### Revoke a Key (Custom)

```bash
php artisan tinker
```

```php
use App\Models\ApiKey;

// Find and delete
$key = ApiKey::where('key', 'the-key-string')->first();
$key->delete();

// Or by name
ApiKey::where('name', 'iPhone 15')->delete();
```

### List Active Keys

Create a command:

```php
php artisan make:command ListApiKeys
```

```php
public function handle()
{
    $keys = ApiKey::with('user')->get();
    
    $this->table(
        ['ID', 'Name', 'User', 'Last Used', 'Expires'],
        $keys->map(fn($k) => [
            $k->id,
            $k->name,
            $k->user->email,
            $k->last_used_at?->diffForHumans() ?? 'Never',
            $k->expires_at?->toDateString() ?? 'Never',
        ])
    );
}
```

## Security Best Practices

### 1. Rate Limiting

Implement rate limiting in `app/Http/Kernel.php`:

```php
protected $middlewareGroups = [
    'api' => [
        'throttle:60,1',  // 60 requests per minute
        \Illuminate\Routing\Middleware\SubstituteBindings::class,
    ],
];
```

Or per-route:

```php
Route::middleware(['auth:sanctum', 'throttle:100,1'])->group(function () {
    // High-frequency endpoints like check-ins
    Route::post('/checkins', [CheckInController::class, 'store']);
});
```

### 2. Key Rotation

Rotate API keys periodically:

```bash
# Revoke old key
php artisan tinker
>>> $user->tokens()->where('name', 'old-key')->delete()

# Create new key
php artisan api:key:create 1 --name="new-key"
```

### 3. Scoped Abilities

Use abilities to limit API key permissions:

```php
// Door scanner - limited to check-ins only
$token = $user->createToken('Door Scanner', ['scan:checkin', 'scan:checkout']);

// Read-only analytics
$token = $user->createToken('Analytics', ['read:events', 'read:checkins']);
```

Check abilities in controllers:

```php
public function store(Request $request)
{
    if (!$request->user()->tokenCan('scan:checkin')) {
        return response()->json(['error' => 'Forbidden'], 403);
    }
    
    // Process check-in
}
```

### 4. Key Expiration

Set expiration dates:

```php
// 90-day expiration
$token = $user->createToken('Temporary', ['*'], now()->addDays(90));
```

### 5. Audit Logging

Log API key usage:

```php
public function handle(Request $request, Closure $next)
{
    $apiKey = $request->header('X-API-Key');
    
    Log::info('API request', [
        'key_name' => $request->user()?->currentAccessToken()?->name,
        'user' => $request->user()?->email,
        'endpoint' => $request->path(),
        'method' => $request->method(),
        'ip' => $request->ip(),
    ]);
    
    return $next($request);
}
```

### 6. HTTPS Only

Enforce HTTPS in production:

```php
// app/Http/Middleware/EnforceHttps.php
public function handle(Request $request, Closure $next)
{
    if (!$request->secure() && app()->environment('production')) {
        return redirect()->secure($request->getRequestUri());
    }
    
    return $next($request);
}
```

## Troubleshooting

### API Key Not Working

1. **Check key format**: Sanctum tokens are in format `{id}|{token}`
2. **Verify middleware**: Ensure `auth:sanctum` or custom middleware is applied
3. **Check header name**: Must be `X-API-Key` or `Authorization: Bearer`
4. **Database check**: Verify token exists in `personal_access_tokens` table

```sql
SELECT * FROM personal_access_tokens WHERE tokenable_id = 1;
```

### 401 Unauthorized

1. **Key expired**: Check `expires_at` column
2. **Key revoked**: Verify key exists in database
3. **Wrong user**: Token may belong to different user
4. **Middleware not applied**: Check route middleware

### CORS Errors

Configure CORS in `config/cors.php`:

```php
return [
    'paths' => ['api/*', '.well-known/*'],
    'allowed_methods' => ['*'],
    'allowed_origins' => ['*'],  // Restrict in production
    'allowed_headers' => ['*'],
    'exposed_headers' => [],
    'max_age' => 0,
    'supports_credentials' => true,
];
```

### Rate Limit Issues

Increase limits for specific routes:

```php
Route::middleware(['auth:sanctum', 'throttle:1000,1'])->group(function () {
    Route::post('/checkins', [CheckInController::class, 'store']);
});
```

## Web UI for API Key Management

Create a web interface for non-technical users:

```php
// routes/web.php
Route::middleware(['auth', 'web'])->group(function () {
    Route::get('/settings/api-keys', [ApiKeyController::class, 'index']);
    Route::post('/settings/api-keys', [ApiKeyController::class, 'store']);
    Route::delete('/settings/api-keys/{id}', [ApiKeyController::class, 'destroy']);
});
```

```php
// app/Http/Controllers/ApiKeyController.php
public function store(Request $request)
{
    $request->validate([
        'name' => 'required|string|max:255',
    ]);
    
    $token = $request->user()->createToken($request->name);
    
    return response()->json([
        'name' => $request->name,
        'token' => $token->plainTextToken,  // Only shown once
        'created_at' => now(),
    ]);
}
```

## Conclusion

Choose the method that best fits your backend:

- **Laravel Sanctum**: Best for most use cases, simple and secure
- **Custom System**: Maximum flexibility, more maintenance
- **OAuth2/Passport**: If you need OAuth2 flows

Once configured, users can generate API keys and use them in the iOS app for secure, token-based authentication.

---

**Need Help?**
- Laravel Sanctum Docs: https://laravel.com/docs/sanctum
- Laravel Passport Docs: https://laravel.com/docs/passport
- Planify iOS App README: See README.md in the app repository
