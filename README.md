# EventSchedule iOS App

A native iOS application for managing EventSchedule instances, providing full administrative access to events, venues, talent, ticketing, and at-door scanning capabilities.

## Features

### Currently Implemented
- ✅ **Multi-Instance Management**: Connect to multiple EventSchedule backends
- ✅ **API Key Authentication**: Secure API key-based authentication per instance
- ✅ **Instance Discovery**: Auto-discovery via `.well-known/eventschedule.json`
- ✅ **Dynamic Branding**: Per-instance theming with colors, logos, and styling
- ✅ **Event CRUD**: Create, read, update, and delete events with full metadata
- ✅ **Venue Support**: Venue references and display in events
- ✅ **Ticket Types**: Manage ticket types and pricing per event
- ✅ **Timezone Handling**: Robust timezone support for event scheduling

### Planned Features (per requirements)
- ⏳ **Talent Management**: Full CRUD for talent/performers
- ⏳ **Venue Management**: Complete venue management with rooms and capacity
- ⏳ **Ticketing Suite**: Issue, refund, void, reassign tickets
- ⏳ **QR/Barcode Scanning**: At-door check-in/check-out with offline queue
- ⏳ **Dashboards**: Sales metrics, capacity, check-in throughput
- ⏳ **Reports**: Export CSV/PDF reports from device
- ⏳ **Notifications**: Operational alerts and push notifications
- ⏳ **Offline Support**: Queue operations when offline, sync when online

## Requirements

- iOS 16.0 or later
- iPadOS 16.0 or later
- Xcode 15.0 or later (for development)
- Swift 5.10 or later

## Getting Started

### 1. Backend Setup: Creating an API Key

The EventSchedule iOS app uses **API key authentication** instead of username/password login. You must create an API key from your EventSchedule backend before connecting the app.

#### Creating an API Key (Backend Instructions)

**Option A: Using the Web UI (if available)**

1. Log in to your EventSchedule web interface as an administrator
2. Navigate to **Settings** → **Integrations & API** (or similar)
3. Click **"Create New API Key"** or **"Generate API Key"**
4. Give your key a descriptive name (e.g., "iOS App - John's iPhone")
5. Set appropriate permissions/scopes for the key
6. Copy the generated API key immediately (it may only be shown once)
7. Store it securely - you'll need it to connect the iOS app

**Option B: Using the Backend CLI/Console**

If your EventSchedule backend is Laravel-based:

```bash
# SSH into your backend server
ssh user@your-eventschedule-server.com

# Navigate to your EventSchedule directory
cd /path/to/eventschedule

# Run the API key generation command
php artisan api:key:create --name="iOS App" --user-id=1

# Or use tinker for manual creation
php artisan tinker
```

In tinker:
```php
// Create a new API key
$user = App\Models\User::find(1); // Replace 1 with your user ID
$token = $user->createToken('iOS App')->plainTextToken;
echo $token;
```

**Option C: Database Direct Method**

If your backend uses Laravel Sanctum:

```sql
-- Generate a random token (64 characters)
-- Use a secure method to generate the token first

INSERT INTO personal_access_tokens (
    tokenable_type,
    tokenable_id,
    name,
    token,
    abilities,
    created_at,
    updated_at
)
VALUES (
    'App\\Models\\User',
    1,  -- Replace with your user ID
    'iOS App',
    'hashed_token_here',  -- Use SHA256 hash of your plain token
    '["*"]',  -- Full permissions (adjust as needed)
    NOW(),
    NOW()
);
```

⚠️ **Security Notes:**
- API keys provide full access to your EventSchedule instance
- Treat API keys like passwords - never share them publicly
- Create separate API keys for each device/user
- Revoke API keys immediately if compromised
- Consider setting expiration dates for keys
- Use environment-specific keys (dev/staging/prod)

### 2. Backend Configuration

Ensure your EventSchedule backend has the following endpoints configured:

#### Required: Well-Known Discovery Endpoint

Create a file at `/.well-known/eventschedule.json` in your backend:

```json
{
  "api_base_url": "https://your-domain.com/api",
  "auth": {
    "type": "sanctum",
    "endpoints": {
      "login": "/api/login",
      "logout": "/api/logout"
    }
  },
  "branding_endpoint": "/api/meta/branding",
  "features": {
    "events": true,
    "venues": true,
    "talent": true,
    "tickets": true,
    "scanning": true
  },
  "versions": {
    "api": "1.0",
    "backend": "2.0"
  },
  "min_app_version": "1.0.0",
  "rate_limits": {
    "events": 100,
    "checkins": 1000
  }
}
```

#### Required: Branding Endpoint

Create an endpoint at `/api/meta/branding`:

```json
{
  "logo_url": "https://your-domain.com/logo.png",
  "wordmark_url": "https://your-domain.com/wordmark.png",
  "primary_hex": "#007AFF",
  "secondary_hex": "#8E8E93",
  "accent_hex": "#34C759",
  "text_hex": "#000000",
  "bg_hex": "#FFFFFF",
  "button_radius": 10,
  "legal_footer": "© 2025 Your Organization"
}
```

#### Required: API Key Authentication Middleware

Ensure your backend accepts the `X-API-Key` header:

```php
// Laravel example middleware
public function handle($request, $next)
{
    $apiKey = $request->header('X-API-Key');
    
    if (!$apiKey) {
        return response()->json(['error' => 'Unauthorized'], 401);
    }
    
    // Validate the API key
    $token = PersonalAccessToken::findToken($apiKey);
    
    if (!$token || !$token->tokenable) {
        return response()->json(['error' => 'Unauthorized'], 401);
    }
    
    // Set the authenticated user
    Auth::setUser($token->tokenable);
    
    return $next($request);
}
```

### 3. Connecting the iOS App

1. **Launch the app** on your iOS device or simulator
2. You'll see the **"Add an EventSchedule Instance"** screen
3. **Enter your backend URL**:
   - Example: `https://events.yourcompany.com`
   - The app will auto-discover settings from `/.well-known/eventschedule.json`
4. **Enter your API key**:
   - Paste the API key you created in Step 1
   - The key is stored securely in the iOS Keychain
5. **Tap "Connect"**
6. The app will:
   - Fetch capabilities from your backend
   - Load branding and theme
   - Verify API key authentication
   - Store the instance profile locally

### 4. Managing API Keys in the App

Once connected:

1. Navigate to **Settings** tab
2. View your **Active Instance** details
3. Update or change your **API Key** if needed
4. **Save API Key** to update stored credentials
5. **Remove API Key** to disconnect (instance remains configured)

## Architecture

### Technology Stack
- **Language**: Swift 5.10+
- **UI Framework**: SwiftUI
- **Architecture**: MVVM with feature modules
- **Networking**: URLSession + Codable
- **Persistence**: UserDefaults for instance profiles, Keychain for API keys
- **Authentication**: API key via `X-API-Key` header

### Project Structure

```
EventSchedule/
├── Core/
│   ├── AppSettings.swift          # Global app settings
│   ├── Auth/
│   │   ├── AuthService.swift      # API key authentication
│   │   ├── AuthTokenStore.swift   # Token management
│   │   └── AuthEnvironment.swift  # Auth environment key
│   ├── Instances/
│   │   └── InstanceStore.swift    # Multi-instance management
│   ├── Models/
│   │   ├── Event.swift            # Event model with timezone support
│   │   ├── Venue.swift            # Venue model
│   │   ├── InstanceProfile.swift  # Instance configuration
│   │   ├── CapabilitiesDocument.swift  # Discovery document
│   │   └── Branding.swift         # Theme/branding model
│   ├── Networking/
│   │   ├── HTTPClient.swift       # HTTP client with API key injection
│   │   └── APIError.swift         # Error handling
│   ├── Repositories/
│   │   └── EventRepository.swift  # Event data access
│   ├── Services/
│   │   ├── DiscoveryService.swift # Well-known discovery
│   │   └── BrandingService.swift  # Branding fetch
│   ├── Theming/
│   │   └── ThemeEnvironment.swift # Dynamic theming
│   └── Utils/
│       ├── DateFormatterFactory.swift  # Date formatting utilities
│       ├── DebugLogger.swift      # Debug logging
│       └── Color+Hex.swift        # Hex color parsing
├── UI/
│   ├── RootView.swift             # Root navigation
│   ├── Features/
│   │   └── Events/
│   │       ├── EventsListViewModel.swift
│   │       ├── EventDetailView.swift
│   │       └── EventFormView.swift
│   ├── Components/
│   │   └── InstanceSwitcherToolbarItem.swift
│   └── Screens/
│       └── Placeholders.swift     # Onboarding and settings
└── EventScheduleApp.swift         # App entry point
```

## API Integration

### Authentication

All API requests include the `X-API-Key` header:

```swift
request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
```

### Expected Backend Endpoints

#### Events
- `GET /api/events` - List events
- `POST /api/events` - Create event
- `GET /api/events/{id}` - Get event details
- `PUT /api/events/{id}` - Update event
- `DELETE /api/events/{id}` - Delete event

#### Venues
- `GET /api/venues` - List venues
- `POST /api/venues` - Create venue
- `GET /api/venues/{id}` - Get venue details
- `PUT /api/venues/{id}` - Update venue
- `DELETE /api/venues/{id}` - Delete venue

#### Talent (Planned)
- `GET /api/talent` - List talent
- `POST /api/talent` - Create talent
- `GET /api/talent/{id}` - Get talent details
- `PUT /api/talent/{id}` - Update talent
- `DELETE /api/talent/{id}` - Delete talent

#### Tickets (Planned)
- `GET /api/tickets` - List/search tickets
- `POST /api/tickets` - Issue ticket
- `POST /api/tickets/{id}/refund` - Refund ticket
- `POST /api/tickets/{id}/void` - Void ticket
- `POST /api/tickets/{id}/reassign` - Reassign ticket

#### Check-ins (Planned)
- `POST /api/checkins` - Record check-in/out
- `GET /api/checkins?event_id={id}` - Get check-in stream

### Response Format

The app expects JSON responses with the following structure:

```json
{
  "data": [...],  // For list endpoints
  "meta": {
    "pagination": {...}
  }
}
```

Or for single resources:

```json
{
  "id": "...",
  "name": "...",
  ...
}
```

## Development

### Building the App

1. **Open the project in Xcode**:
   ```bash
   open EventSchedule.xcodeproj
   ```

2. **Select a simulator or device**:
   - iPhone 15 Simulator recommended for development
   - iOS 16.0+ required

3. **Build and run**:
   - Press `Cmd+R` or click the Play button
   - The app will build and launch in the simulator

### Running Tests

```bash
# Run all tests
xcodebuild test -project EventSchedule.xcodeproj -scheme EventSchedule -destination 'platform=iOS Simulator,name=iPhone 15'

# Or use Xcode: Cmd+U
```

### Code Style

- Follow Swift API Design Guidelines
- Use SwiftLint for linting (if configured)
- Use SwiftFormat for formatting (if configured)
- Prefer composition over inheritance
- Use `async/await` for asynchronous operations
- Use `@MainActor` for UI-related classes

## Troubleshooting

### "Connection Failed" when adding instance

1. **Check the URL**: Ensure the backend URL is correct and accessible
2. **Verify `.well-known` endpoint**: 
   - Visit `https://your-domain.com/.well-known/eventschedule.json` in a browser
   - Should return valid JSON
3. **Check SSL certificate**: HTTPS is required (HTTP will fail unless in development)
4. **Review backend logs**: Look for CORS or authentication errors

### "Unauthorized" when accessing data

1. **Verify API key**: Check that the key is valid and not expired
2. **Check permissions**: Ensure the API key has appropriate scopes/abilities
3. **Backend validation**: Confirm the backend accepts the `X-API-Key` header
4. **Re-save API key**: Go to Settings and re-enter the API key

### Events not loading

1. **Check API endpoint**: Ensure `/api/events` is accessible
2. **Verify response format**: Backend must return valid JSON
3. **Review app logs**: Check Xcode console for detailed errors
4. **Test with curl**:
   ```bash
   curl -H "X-API-Key: your-key-here" https://your-domain.com/api/events
   ```

### Timezone issues

⚠️ **Important**: The current timezone handling implementation is working correctly and should not be modified without careful consideration. The app handles:
- Server-provided timezone identifiers
- Wall-time preservation for event start/end times
- Multiple date format parsing strategies
- UTC fallbacks and local timezone display

If you experience timezone display issues:
1. Check that your backend returns consistent timezone identifiers
2. Verify the `timezone` field in event payloads
3. Adjust your local timezone in app Settings if needed

## Security

### API Key Storage
- API keys are stored in the iOS Keychain
- Keys are never logged or transmitted except in API headers
- Each instance has separate key storage

### Network Security
- HTTPS/TLS required for production
- Certificate pinning optional (not currently implemented)
- No sensitive data in logs

### Permissions
- Camera access required for scanning (when implemented)
- Network access required
- No location or contacts access needed

## Contributing

When contributing to this project:

1. Maintain existing code style and patterns
2. **Do not modify the Event model's date/time handling** without explicit approval
3. Add tests for new functionality
4. Update documentation for new features
5. Follow the existing MVVM architecture

## License

[Specify your license here]

## Support

For issues or questions:
- Check the troubleshooting section above
- Review backend API documentation
- Contact your EventSchedule instance administrator
- File issues in the project repository

## Roadmap

See the issue description for the complete v1.0 requirements including:
- Talent and Venue management UIs
- Complete ticketing suite
- QR/Barcode scanning with offline support
- Real-time dashboards and reporting
- Push notifications
- Multi-gate device assignment
- Export functionality

---

**Version**: 1.0.0-beta  
**Last Updated**: 2025-12-14
