## Project Overview

<div align="center">
    <picture>
        <source srcset="/public/images/planify_horizontal_dark.png" media="(prefers-color-scheme: light)">
        <img src="/public/images/planify_horizontal_light.png" alt="Planify Logo" width="350" media="(prefers-color-scheme: dark)">
    </picture>
</div>

---
# Planify Documentation

This file consolidates the supported documentation for Planify.

## Contents

- Project Overview
  - [Project Overview](#file-readme-md)
- Deployment
  - [Docker Deployment](#file-docs-docker-readme-md)
- Security & Access Control
  - [Authorization & Roles](#file-docs-authorization-md)
  - [Storage Permissions](#file-docs-storage-permissions-md)
- Testing
  - [Testing Guide](#file-docs-testing-guide-md)
- Integrations
  - [Google Calendar Setup](#file-docs-google-calendar-setup-md)
  - [Apple Wallet Setup](#file-docs-apple-wallet-pass-setup-md)
  - [Apple Wallet Testing Checklist](#file-docs-apple-wallet-testing-checklist-md)
- Tickets
  - [Ticket Scanning Quick Reference](#file-docs-ticket-scanning-quick-reference-md)
  - [Ticket Scanning API Guide](#file-docs-ticket-scanning-api-guide-md)
  - [Ticket Actions Quick Reference](#file-docs-ticket-actions-quick-ref-md)
- Mobile
  - [Mobile Events API Guide](#file-docs-mobile-events-api-guide-md)
  - [iOS Team Setup](#file-docs-ios-team-setup-md)
- API Reference
  - [Complete API Reference](#file-docs-complete-api-reference-md)
  - [OpenAPI Spec (YAML)](#file-docs-api-swagger-yaml)
  - [Postman Collection (Scan API)](#file-docs-postman-scanapi-postman-collection-json)

## Changelog (Docker Tags)

| Date | Build Version | Docker Tags | Notes |
| --- | --- | --- | --- |
| 2026-01-19 | 20260116-07b | `latest`, `main`, `sha-7cfd50d` | Docs consolidated, single-container Docker only, repo cleanup; backup/restore support (Issue #577). |

<a id="file-readme-md"></a>
<p>
    An open-source platform to create calendars, sell tickets and streamline event check-ins with QR codes
</p>

## Features

- 🗓️ **Event Calendars:** Create and share event calendars effortlessly to keep your audience informed.  
- 🎟️ **Sell Tickets Online:** Offer ticket sales directly through the platform with a seamless checkout process.  
- 💳 **Online Payments with Invoice Ninja Integration:** Accept secure online payments via [Invoice Ninja](https://www.invoiceninja.com) or payment links.
- 🤖 **AI Event Parsing:** Automatically extract event details using AI to quickly create new events.
- 🔗 **Third-Party Event Import:** Automatically import events from third-party websites to expand your calendar offerings.
- 🔁 **Recurring Events:** Schedule recurring events which occur on a regular basis.  
- 📲 **QR Code Ticketing:** Generate and scan QR codes for easy and secure event check-ins.  
- 💻 **Support for Online Events:** Use the platform to sell tickets to online events.  
- 👥 **Team Scheduling:** Collaborate with team members to manage availability and coordinate event calendars.  
- 🤖 **AI Translation:** Automatically translate your entire schedule into multiple languages using AI.
- 🎫 **Multiple Ticket Types:** Offer different ticket tiers, such as Standard or VIP, to meet various audience needs.  
- 🔢 **Ticket Quantity Limits:** Set a maximum number of tickets available for each event to manage capacity.  
- ⏳ **Ticket Reservation System:** Allow attendees to reserve tickets with a configurable release time before purchase.  
- 📅 **Calendar Integration:** Enable attendees to add events directly to Google, Apple, or Microsoft calendars.
- 🧾 **Mobile Wallet Tickets:** Offer Add to Apple Wallet and Save to Google Wallet passes for paid orders.
- 📋 **Sub-schedules:** Organize events into multiple sub-schedules for better categorization and management.
- 🔍 **Search Feature:** Powerful search functionality to help users find specific events or content across your schedule.
- 🎨 **Event Graphics Generator:** Create beautiful graphics of your upcoming events with flyers, QR codes, and event details for social media and marketing.
- 🔌 **REST API:** Access and manage your events programmatically through a REST API.
- 🛡️ **Role-Based Access Control:** Enforce least-privilege permissions for every route across the web UI and API; see [docs/authorization.md](#file-docs-authorization-md) for the role matrix and permission keys.
- 🚀 **Automatic App Updates:** Keep the platform up to date effortlessly with one-click automatic updates.
- 🧭 **Streamlined Admin Navigation:** Reach Venues, Talent, and Curators from top-level menus while keeping their detailed sub-navigation intact.

## API Reference

Comprehensive request/response samples for every REST endpoint, including authentication and failure handling, are available in [docs/COMPLETE_API_REFERENCE.md](#file-docs-complete-api-reference-md).

<div style="display: flex; gap: 10px;">
    <img src="https://github.com/dfiore1230/planify/blob/main/public/images/screenshots/screen_1.png?raw=true" width="49%" alt="Guest > Schedule">
    <img src="https://github.com/dfiore1230/planify/blob/main/public/images/screenshots/screen_2.png?raw=true" width="49%" alt="Guest > Event">
</div>

<div style="display: flex; gap: 10px;">
    <img src="https://github.com/dfiore1230/planify/blob/main/public/images/screenshots/screen_3.png?raw=true" width="49%" alt="Admin > Schedule">
    <img src="https://github.com/dfiore1230/planify/blob/main/public/images/screenshots/screen_4.png?raw=true" width="49%" alt="Admin > Event">
</div>

## Installation Guide

Follow these steps to set up Planify:

### 1. Set Up the Database

Run the following commands to create the MySQL database and user:

```sql
CREATE DATABASE planify;
CREATE USER 'planify'@'localhost' IDENTIFIED BY 'change_me';
GRANT ALL PRIVILEGES ON planify.* TO 'planify'@'localhost';
```

---

### 2. Set Up the Application

Copy [planify.zip](https://github.com/dfiore1230/planify/releases/latest) to your server and unzip it.

---

### 3. Set File Permissions

The self-updater copies new releases directly into your installation. Make sure the
project is owned by the web server user (replace `www-data` with the user that runs PHP on your server):

```bash
cd /path/to/planify
sudo chown -R www-data:www-data .
```

If you prefer to scope ownership more narrowly, ensure these directories remain writable by the web user:
`app`, `bootstrap`, `config`, `database`, `public`, `resources`, `routes`, and `storage`.

---

### 4. Set Up the Application

Copy the `.env.example` file to `.env` and then access the application at `https://your-domain.com`.

```bash
cp .env.example .env
```

<img src="https://github.com/dfiore1230/planify/blob/main/public/images/screenshots/setup.png?raw=true" width="100%" alt="Setup"/>

---

### 5. Set Up the Cron Job

Add the following line to your crontab to ensure scheduled tasks run automatically:

```bash
* * * * * php /path/to/planify/artisan schedule:run
```

---

## Docker Deployment

Planify ships with a single-container Docker runtime that bundles PHP-FPM, Nginx, the scheduler, and MariaDB. Multi-container Compose stacks are no longer supported.

```bash
cp .env.docker.example .env.docker
mkdir -p bind/storage bind/mysql
docker compose up --build -d
```

Visit `http://localhost:8080`.

### Operational tips

- `docker compose logs -f app` to follow application logs.
- `docker compose exec app php artisan ...` to run artisan commands.

### Backup & restore

Create a full backup (database, storage, and public images):

```bash
docker compose exec app /usr/local/bin/backup.sh
```

Restore from a backup archive:

```bash
docker compose exec app env CONFIRM_RESTORE=yes /usr/local/bin/restore.sh /var/www/html/storage/backups/planify-backup-<timestamp>.tar.gz
```

API endpoints for automation (API key required, `settings.manage` permission):

```bash
GET  /api/admin/backups
POST /api/admin/backups
POST /api/admin/backups/restore
```

Manual backup for versions prior to this release:
- Copy `.env` and `storage/`.
- Back up your database (`mysqldump` for MySQL/MariaDB or copy `bind/mysql` if using Docker).
- If you store images in `public/images`, copy that directory as well.

---

## Logging

Planify ships with a dedicated `syslog_server` channel for forwarding logs to a remote syslog endpoint.

1. Set `LOG_CHANNEL=syslog_server` (or include `syslog_server` in `LOG_STACK`) to start using the channel.
2. Configure the target server via `LOG_SYSLOG_HOST` and `LOG_SYSLOG_PORT` in your `.env` file or through **Settings → General** in the administration panel.
3. Optionally adjust the minimum severity with `LOG_LEVEL` (also available under **Settings → General**) or override the facility using `LOG_SYSLOG_FACILITY`.

By default, the handler emits RFC 5424-formatted messages with contextual placeholder replacement to keep structured log data intact.

---

You're all set! 🎉 Planify should now be up and running.

## Mobile Wallet Tickets

Planify can generate Apple Wallet passes and Google Wallet tickets for paid orders. Configure both services using the new environment variables in `.env`:

### Apple Wallet

1. Set `APPLE_WALLET_ENABLED=true`.
2. Provide the path to your PassKit certificate (`.p12`) via `APPLE_WALLET_CERTIFICATE_PATH` and its password with `APPLE_WALLET_CERTIFICATE_PASSWORD`.
3. Download the latest Apple WWDR certificate and set `APPLE_WALLET_WWDR_CERTIFICATE_PATH` to its location.
4. Specify your Pass Type Identifier (`APPLE_WALLET_PASS_TYPE_IDENTIFIER`) and Apple Developer Team ID (`APPLE_WALLET_TEAM_IDENTIFIER`).
5. Optionally customize the organization name and colors with the remaining `APPLE_WALLET_*` variables.
6. When debugging, set `APPLE_WALLET_DEBUG=true` and (optionally) `APPLE_WALLET_DEBUG_DUMP_PATH` to capture per-sale pass artifacts on disk.

### Google Wallet

1. Set `GOOGLE_WALLET_ENABLED=true`.
2. Create a Google Wallet issuer and note the issuer ID for `GOOGLE_WALLET_ISSUER_ID`.
3. Supply a service account credential file by either providing the file path in `GOOGLE_WALLET_SERVICE_ACCOUNT_JSON_PATH` or pasting the JSON/base64 contents into `GOOGLE_WALLET_SERVICE_ACCOUNT_JSON`.
4. Customize the ticket class suffix and issuer name if needed (`GOOGLE_WALLET_CLASS_SUFFIX`, `GOOGLE_WALLET_ISSUER_NAME`).

Once configured, paid ticket emails and the ticket viewer will surface “Add to Apple Wallet” and “Save to Google Wallet” actions automatically.

## Testing

Planify includes a comprehensive browser test suite powered by Laravel Dusk.

Pest (optional):
- To use Pest, install it locally (optional):
  - `composer require --dev pestphp/pest`
  - `php artisan pest:install`
- Run Pest tests: `./vendor/bin/pest` or `php artisan test`



> [!WARNING]  
> WARNING: Running the tests will empty the database. 

### Prerequisites

1. **Install Laravel Dusk:**
```bash
composer require --dev laravel/dusk
php artisan dusk:install
```

2. **Configure Chrome Driver:**
```bash
php artisan dusk:chrome-driver
```

3. **Set up test environment:**
```bash
cp .env .env.dusk.local
# Configure your test database in .env.dusk.local
```

### Running Tests

Run the automated tests locally or rely on CI to run them on PRs.

PHP tests (Pest/PHPUnit):
```bash
# Run PHP tests
php artisan test
```

GitHub Actions CI: `.github/workflows/ci.yml` runs PHP feature tests on push & PRs.

Seed test data (local/testing only):

```bash
curl -X POST http://127.0.0.1:8000/__test/seed
```

```bash
# Run all browser tests (if using Dusk)
php artisan dusk
```



<a id="file-docs-docker-changelog-md"></a>

<a id="file-docs-authorization-md"></a>
## Authorization & Roles

# Authorization & RBAC

Planify ships with a single-tenant role-based access control (RBAC) system that enforces the same permission model for the web UI and API. Every authenticated request is evaluated against cached permission sets so we can return `401/403` consistently, hide unauthorized actions, and keep checks O(1).

## Goals

- **Least-privilege defaults.** Users only inherit the abilities assigned to their system role(s).
- **Auditable changes.** Updates to global settings, login/logout activity, refunds, and check-ins are logged to `audit_logs` with IP and user-agent metadata.
- **Unified enforcement.** Routes opt into the `ability:<permission-key>` middleware (see `routes/api.php` and `routes/web.php`) so the same permission keys protect both APIs and Blade controllers.
- **Deterministic migrations.** The `AuthorizationSeeder` creates the roles, permissions, and initial mappings and assigns the first user to the `SuperAdmin` role when the `user_roles` table is empty.

## Data model

| Table | Purpose |
| --- | --- |
| `auth_roles` | System roles such as SuperAdmin, Admin, Viewer. |
| `permissions` | Canonical permission keys (e.g., `events.publish`, `tickets.refund`). |
| `role_permissions` | Pivot table mapping system roles to permissions. |
| `user_roles` | Pivot table mapping users to system roles. |
| `audit_logs` | Append-only log of authentication and operational actions. |

### Permission keys

`config/authorization.php` documents the cache and retention settings. `database/seeders/AuthorizationSeeder.php` seeds a slimmed-down set of permission keys:

- `settings.manage` – platform configuration
- `users.manage` – user invitations and updates
- `resources.manage` – create and edit venues, talent, and curators within scope
- `resources.view` – read-only access to scoped venues, talent, and curators

### Role matrix

| Role | Highlights |
| --- | --- |
| **SuperAdmin** | Full platform access across every resource. |
| **Admin** | Manage venues, talent, and curators inside their assigned scope. |
| **Viewer** | View-only access to the venues, talent, and curators in their scope. |

Admins and viewers are bound to a pick list of venues, talent, and curators configured on the user record. SuperAdmins ignore these scopes and can act on any resource.

The `AuthorizationService` warms a role→permission cache and exposes helper methods that `User::hasPermission()` uses throughout the codebase. The custom `ability` middleware (see `app/Http/Middleware/EnsureAbility.php`) enforces these keys on routes like:

```php
Route::middleware(['auth', 'ability:settings.manage'])->group(function () {
    // settings + admin routes
});
```

## Auditing

- **Login/logout**: `HandleSuccessfulLogin` and `HandleLogout` listeners capture each session transition.
- **Settings**: Every mutating action inside `SettingsController` calls `auditSettingsChange()` with metadata describing which keys were touched.
- **Orders/tickets**: Refunds, cancellations, deletions, mark-paid operations, and QR check-ins are written to `audit_logs` via `AuditLogger` in `TicketController`.
- **Retention**: `config/authorization.php` exposes `AUDIT_LOG_RETENTION_DAYS`; use `php artisan audit:prune` to purge older rows.

## CLI helpers

Use `php artisan authorization:assign-role {user} {role} [--remove]` to promote/demote users. The command accepts a user ID or email address and keeps the permission cache fresh by warming/flushing entries via `AuthorizationService`.

## UI cues

- The authenticated navigation sidebar now surfaces the user's system roles as badges.
- A dedicated Access Denied page (`resources/views/errors/403.blade.php`) explains why an action was blocked and links to a "Request access" CTA.
- Unauthorized actions in controllers fall back to `abort(403)` with the same translated messaging so the error page is consistently rendered.

For a complete list of permission keys and their descriptions, consult `database/seeders/AuthorizationSeeder.php`. Each key in that seeder maps directly to the `ability:<permission>` middleware and `User::hasPermission()` helper.



<a id="file-docs-api-swagger-yaml"></a>

<a id="file-docs-storage-permissions-md"></a>
## Storage Permissions

# Storage Directory Permissions

Laravel expects the directories under `storage/` to be both **writable** and **traversable** by the user that runs PHP (typically `www-data` or `nginx`). When a directory is missing the execute (`x`) bit Laravel cannot open files inside it, even if read (`r`) permissions are present. Likewise, without write (`w`) permissions the framework cannot create cache files, compiled views, or logs.

The listing below illustrates a problematic layout:

```
drw-r--r-- 5 82 82   5 Oct 16 09:52 framework
drw-r--r-- 5 82 82   5 Oct 16 09:52 framework
-rw-r--r-- 1 82 82 803 Oct 16 09:52 gradients.json
-rw-r--r-- 1 82 82 841 Oct 16 09:52 backgrounds.json
drw-r--r-- 2 82 82   3 Oct 16 09:53 logs
drw-r--r-- 2 82 82   2 Oct 16 10:40 app
```

Every directory (`framework`, `logs`, `app`) lacks the execute bit and is owned by UID/GID `82`. In this state Laravel cannot:

- read JSON configuration files that live below `storage/app/`
- write cache or compiled files under `storage/framework/`
- create the daily log file in `storage/logs/`

The usual symptom is an HTTP 500 error because the framework fails to write to the log or cache directory while bootstrapping the request.

## Running the Permission Inspector

Use the bundled Artisan command to check whether Laravel can access the expected directories and files:

```bash
php artisan storage:permissions
```

The command scans `storage/` and `bootstrap/cache`, reporting any entries that are not readable, writable, or (for directories) traversable. Add the `--json` flag when you want to feed the output to another tool.

## Fixing Ownership

Ensure the storage tree is owned by the same user that runs the PHP process. On many Linux distributions that is `www-data`:

```bash
sudo chown -R www-data:www-data /data/Docker/planifyr/storage
sudo chown -R www-data:www-data /data/Docker/planifyr/bootstrap/cache
```

If you deploy via Docker, run the command inside the container as `root` but target the user configured for the PHP-FPM process.

## Fixing Permissions

Grant the owner read, write, and execute access, and allow the group to traverse the directories:

```bash
sudo find /data/Docker/planifyr/storage -type d -exec chmod 775 {} +
sudo find /data/Docker/planifyr/storage -type f -exec chmod 664 {} +
sudo find /data/Docker/planifyr/bootstrap/cache -type d -exec chmod 775 {} +
sudo find /data/Docker/planifyr/bootstrap/cache -type f -exec chmod 664 {} +
```

This results in directory entries such as `drwxrwxr-x`, which lets PHP create and read files while preventing anonymous users from writing to the directory.

After adjusting the ownership and permissions, reload the application: the `/new/talent`, `/new/venue`, and `/new/curator` pages should respond normally once Laravel can read the JSON files and write its log and cache entries.

## Serving Public Assets from Storage

If your web server runs as a user that is **not** part of the `www-data` group, the default `775/664` permission scheme can still block it from reading images or documents exposed via `storage/app/public`. A common symptom is that profile or event artwork responds with `404 Not Found` even though the files exist on disk.

To make the assets world-readable while keeping ownership consistent, run the following commands (adjust the paths to match your deployment):

```bash
sudo chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache
sudo find /var/www/html/storage -type d -exec chmod 755 {} \;
sudo find /var/www/html/storage -type f -exec chmod 644 {} \;
sudo chmod 755 /var/www /var/www/html /var/www/html/public
```

The first command ensures Laravel can continue writing to the directories, while the `chmod` calls grant "read" access to everyone and leave the execute bit on directories so nginx (or another HTTP server) can traverse the tree. Making the parent directories traversable is required for nginx to follow the symlink created by `php artisan storage:link`.

Because `755/644` is more permissive than the earlier recommendation, prefer to scope it to the storage tree or to servers that do not share the host with untrusted users.



<a id="file-docs-tickets-api-authorization-fix-md"></a>

<a id="file-docs-testing-guide-md"></a>
## Testing Guide

# E2E & Manual Testing Guide (Quickstart)

This document summarizes how to run the manual and automated tests for Planify.

## Manual testing - prerequisites
1. Ensure local server is running: `php artisan serve --host=127.0.0.1 --port=8000`.
2. Ensure DB is seeded with test data (see `docs/e2e-test-plan-detailed.docx` for seeding tinker commands).

## Running automated tests

### CI
A GitHub Actions workflow is included at `.github/workflows/ci.yml` which runs PHP tests and Cypress E2E tests on push and pull requests. The workflow uses an in-memory SQLite DB and starts a local server to run Cypress.


### PHPUnit / Pest
- Run all PHP tests:
  - `php artisan test` (or `./vendor/bin/phpunit`)
- Run single test:
  - `php artisan test --filter ScanTicketApiTest`

### Cypress
- Install (if not installed): `npm install`.
- Seed test data (local/testing only): `curl -X POST http://127.0.0.1:8000/__test/seed`
- Open interactive runner: `npm run cypress:open`.
- Run headless: `npm run cypress:run`.

Debugging and diagnostics

- A debug GitHub Actions workflow is available at `.github/workflows/cypress-debug.yml`. It is intended for focused troubleshooting — it runs only the failing specs and uploads `cypress/screenshots`, `cypress/videos`, and `cypress/results` as artifacts so you can download them and inspect HTML snapshots and recordings.
- For on-demand local or CI debug output, set the env flag `CYPRESS_DEBUG=true` (Cypress exposes `CYPRESS_`-prefixed env vars to `Cypress.env()`). When set, tests write HTML snapshots and session cookie details to `cypress/results/` and capture screenshots for easier triage.
- The seed endpoint `/__test/seed` is intentionally allowed only in `local` and `testing` environments; it now returns `admin_email_verified` and the seeded admin will have `email_verified_at` set so tests do not get routed to the verify-email flow.


### Postman
- Import `docs/postman/ScanAPI.postman_collection.json` into Postman and run the requests against your `baseUrl`.

## Evidence collection
- For UI tests: screenshots of the page, note the URL and timestamp.
- For API tests: copy the JSON response and note HTTP status.
- For server errors: capture `storage/logs/laravel.log` lines around the timestamp.

## Reporting bugs
Include reproduction steps, environment, exact commands/URLs, screenshots, and log excerpts.



<a id="file-docs-mobile-events-api-guide-md"></a>

<a id="file-docs-google-calendar-setup-md"></a>
## Google Calendar Setup

# Google Calendar Integration Setup

This document explains how to set up and use the Google Calendar integration feature in the Planify application.

## Prerequisites

1. A Google Cloud Console project
2. Google Calendar API enabled
3. OAuth 2.0 credentials configured

## Setup Instructions

### 1. Google Cloud Console Setup

1. Go to the [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the Google Calendar API:
   - Go to "APIs & Services" > "Library"
   - Search for "Google Calendar API"
   - Click on it and press "Enable"

### 2. OAuth 2.0 Credentials

1. Go to "APIs & Services" > "Credentials"
2. Click "Create Credentials" > "OAuth 2.0 Client IDs"
3. Choose "Web application" as the application type
4. Add authorized redirect URIs:
   - For development: `http://localhost:8000/google-calendar/callback`
   - For production: `https://yourdomain.com/google-calendar/callback`
5. Save the credentials and note down the Client ID and Client Secret

### 3. Environment Configuration

Add the following environment variables to your `.env` file:

```env
GOOGLE_CLIENT_ID=your_google_client_id
GOOGLE_CLIENT_SECRET=your_google_client_secret
GOOGLE_REDIRECT_URI=https://yourdomain.com/google-calendar/callback
```


## Features

### User Features

1. **Connect Google Calendar**: Users can connect their Google Calendar account from their profile page
2. **Sync All Events**: Users can sync all their events to Google Calendar at once
3. **Individual Event Sync**: Users can sync individual events from the event edit page
4. **Automatic Sync**: Events are automatically synced when created, updated, or deleted (if user has Google Calendar connected)
5. **Bidirectional Sync**: Events added in either Google Calendar or Planify will appear in both places
6. **Calendar Selection**: Choose which Google Calendar to sync with for each role/schedule
7. **Real-time Updates**: Changes in Google Calendar are automatically synced to Planify via webhooks

### Event Information Synced

- Event name
- Event description (with venue and URL information)
- Start and end times
- Location (venue address)
- Event URL

### Sync Status

Events can have three sync statuses:
- **Not Connected**: User hasn't connected their Google Calendar
- **Not Synced**: User has connected Google Calendar but this event isn't synced
- **Synced**: Event is synced to Google Calendar

### Bidirectional Sync

When bidirectional sync is enabled:
- Events created in Planify are automatically added to Google Calendar
- Events created in Google Calendar are automatically added to Planify
- Changes in either system are reflected in the other
- Real-time updates via Google Calendar webhooks

## Usage

### For Users

1. **Connect Google Calendar**:
   - Go to your profile page (`/account`)
   - Scroll to the "Google Calendar Integration" section
   - Click "Connect Google Calendar"
   - Authorize the application in the Google OAuth flow

2. **Sync All Events**:
   - After connecting, click "Sync All Events" in your profile
   - This will sync all your events to your primary Google Calendar

3. **Sync Individual Events**:
   - Go to any event edit page
   - Scroll to the "Google Calendar Sync" section
   - Click "Sync to Google Calendar" or "Remove from Google Calendar"

4. **Enable Bidirectional Sync**:
   - Go to your role/schedule edit page
   - Scroll to the "Google Calendar Integration" section
   - Select which Google Calendar to sync with
   - Click "Enable" for bidirectional sync
   - Events will now sync both ways automatically

5. **Manual Sync Options**:
   - **Sync to Google Calendar**: Push all events from Planify to Google Calendar
   - **Sync from Google Calendar**: Pull all events from Google Calendar to Planify

### For Developers

#### Automatic Sync

Events are automatically synced when:
- Created (if user has Google Calendar connected)
- Updated (if user has Google Calendar connected)
- Deleted (if event was previously synced)

#### Manual Sync

You can manually sync events using the Event model:

```php
// Sync an event for all connected users
$event->syncToGoogleCalendar('create'); // or 'update', 'delete'

// Check sync status
$event->isSyncedToGoogleCalendar();

// Get sync status for a specific user
$event->getGoogleCalendarSyncStatus($user);
```

#### Background Jobs

Sync operations are handled by background jobs (`SyncEventToGoogleCalendar`) to avoid blocking the user interface.

## API Endpoints

- `GET /google-calendar/redirect` - Start OAuth flow
- `GET /google-calendar/callback` - OAuth callback
- `GET /google-calendar/disconnect` - Disconnect Google Calendar
- `GET /google-calendar/calendars` - Get user's calendars
- `POST /google-calendar/sync-events` - Sync all events
- `POST /google-calendar/sync-event/{eventId}` - Sync specific event
- `DELETE /google-calendar/unsync-event/{eventId}` - Remove event from Google Calendar
- `POST /google-calendar/role/{subdomain}` - Update role's Google Calendar selection
- `POST /google-calendar/bidirectional/{subdomain}/enable` - Enable bidirectional sync
- `POST /google-calendar/bidirectional/{subdomain}/disable` - Disable bidirectional sync
- `POST /google-calendar/sync-from-google/{subdomain}` - Sync from Google Calendar to Planify
- `GET /google-calendar/webhook` - Webhook verification (Google Calendar)
- `POST /google-calendar/webhook` - Webhook handler (Google Calendar)

## Troubleshooting

### Common Issues

1. **"Google Calendar not connected" error**:
   - User needs to connect their Google Calendar account first
   - Check if OAuth credentials are correctly configured

2. **"Failed to sync event" error**:
   - Check if Google Calendar API is enabled
   - Verify OAuth credentials are correct
   - Check application logs for detailed error messages

3. **Events not syncing automatically**:
   - Ensure queue workers are running for background jobs
   - Check if user has valid Google Calendar tokens

### Logs

Sync operations are logged in the application logs. Check `storage/logs/laravel.log` for detailed information about sync operations.

## Security Considerations

1. **Token Storage**: Google OAuth tokens are stored encrypted in the database
2. **Scope Limitation**: The integration only requests necessary Google Calendar permissions
3. **User Authorization**: Users can only sync events they have access to
4. **Token Refresh**: Access tokens are automatically refreshed when needed

## Future Enhancements

Potential future improvements:
- Support for multiple Google Calendars per role
- Enhanced conflict resolution for simultaneous edits
- Sync status dashboard with detailed logs
- Bulk sync operations with progress tracking
- Custom field mapping between systems
- Event category/tag synchronization
- Recurring event support improvements



<a id="file-docs-apple-wallet-testing-checklist-md"></a>

<a id="file-docs-apple-wallet-pass-setup-md"></a>
## Apple Wallet Setup

# Apple Wallet Pass Configuration Guide

This guide walks through preparing an Apple Wallet pass that you can issue from Planify once you have enrolled in the Apple Developer Program. It highlights all assets, certificates, and configuration values you need so you can align the app's pass generation code with Apple's requirements.

## 1. Confirm Developer Program Assets

Before you start, sign in to the [Apple Developer account portal](https://developer.apple.com/account/resources/). Verify that you have access to:

1. **Team ID** – You will use this identifier in the pass JSON payload (`teamIdentifier`).
2. **Organization Name** – Appears as the pass issuer (`organizationName`).
3. **Pass Type Identifier** – Create a new Pass Type ID (e.g., `pass.com.yourcompany.planify`). This string becomes the `passTypeIdentifier` in each pass.

Document these values so you can add them to the app's configuration later.

## 2. Create a Pass Type ID Certificate

Apple Wallet passes must be signed with a certificate generated for your Pass Type ID.

1. In Certificates, Identifiers & Profiles, open **Identifiers → Pass Type IDs** and select the identifier you just created.
2. Press **Create Certificate**, then download the Certificate Signing Request (CSR) utility from Apple or use Keychain Access to generate one (Keychain Access → Certificate Assistant → Request a Certificate From a Certificate Authority). Save the `.certSigningRequest` file locally.
3. Upload the CSR, download the resulting certificate (`pass.cer`), and double-click it to import it into your macOS keychain.
4. Export the certificate and the private key together as a `.p12` file (Keychain Access → right-click the certificate → **Export**). Apple will prompt for a password: remember it—you will add it to your environment secrets for Planify.

> **Tip:** Convert the `.p12` file into a PEM pair if your deployment environment requires it:
>
> ```bash
> # OpenSSL 3 (macOS 12+/Homebrew) requires the `-legacy` flag for RC2-encrypted bundles
> openssl pkcs12 -in Certificates.p12 -out PassCertificate.pem -clcerts -nokeys -legacy
> openssl pkcs12 -in Certificates.p12 -out PassKey.pem -nocerts -nodes -legacy
> ```

## 3. Prepare Pass Assets

Every pass template includes at least:

- `pass.json` – The metadata payload.
- `icon.png` and `icon@2x.png` – Required icons (29×29 and 58×58).
- `logo.png` and `logo@2x.png` – Branding at 160×50 and 320×100.
- `background.png` / `background@2x.png` – Optional background image.
- `strip.png` / `strip@2x.png` – Optional strip image for event tickets.

Keep assets in a folder structure such as `resources/passes/<pass-type>/`. Retina variants must be exactly 2× the base size, PNG format, and RGB colorspace.

## 4. Draft `pass.json`

Create a `pass.json` file that matches Apple's schema. Below is a minimal example for an event ticket issued by Planify:

```json
{
  "formatVersion": 1,
  "passTypeIdentifier": "pass.com.yourcompany.planify",
  "serialNumber": "EVENT-2024-0001",
  "teamIdentifier": "ABCDE12345",
  "organizationName": "Your Company",
  "description": "Planify Admission",
  "eventTicket": {
    "primaryFields": [
      {
        "key": "event",
        "label": "Event",
        "value": "Sample Conference"
      }
    ],
    "secondaryFields": [
      {
        "key": "date",
        "label": "Date",
        "value": "May 24, 2024"
      }
    ],
    "auxiliaryFields": [
      {
        "key": "venue",
        "label": "Venue",
        "value": "Main Hall"
      }
    ]
  },
  "barcode": {
    "format": "PKBarcodeFormatQR",
    "message": "https://planify.example.com/passes/EVENT-2024-0001",
    "messageEncoding": "iso-8859-1"
  }
}
```

### Localization

If you need localized field labels or content, add `.lproj` folders (e.g., `en.lproj/pass.strings`) alongside your pass assets. Each localization folder contains `pass.strings` with key/value pairs for translated strings.

## 5. Create the Manifest and Signature

Apple Wallet requires a manifest file (`manifest.json`) and a detached signature (`signature`) generated with your certificate.

1. From inside the pass folder, compute SHA-1 hashes for each asset:

   ```bash
   /usr/bin/openssl sha1 *.png pass.json > hashes.txt
   ```

2. Convert `hashes.txt` into valid JSON, mapping filenames to hash strings, and save it as `manifest.json`.
3. Sign the manifest with your Pass Type ID certificate:

   ```bash
   /usr/bin/openssl smime -binary -sign \
     -certfile WWDR.pem \
     -signer PassCertificate.pem \
     -inkey PassKey.pem \
     -in manifest.json \
     -out signature \
     -outform DER
   ```

   - `WWDR.pem` is the Apple Worldwide Developer Relations intermediate certificate (download from Apple).
   - `PassCertificate.pem` and `PassKey.pem` come from converting your `.p12` export, or you can sign directly with the `.p12` using `-pkcs12` on newer OpenSSL versions.

4. Zip the pass contents (assets, `pass.json`, `manifest.json`, and `signature`) into a `.pkpass` archive:

   ```bash
   zip -r EventTicket.pkpass pass.json manifest.json signature icon.png icon@2x.png logo.png logo@2x.png
   ```

## 6. Integrate with Planify

Update your application configuration with the certificate paths and passwords:

- Store the `.p12` (or PEM equivalents) in a secure location accessible to your app server.
- Expose the password via environment variable (e.g., `APPLE_WALLET_CERT_PASSWORD`).
- Configure the pass template path and default fields inside Planify's settings or environment config so the pass generator can fill dynamic data like attendee name, event date, and QR payload.

When generating a pass, your code should:

1. Copy the template assets to a temporary working directory.
2. Inject dynamic values into `pass.json` (serial number, attendee info, event metadata).
3. Rebuild `manifest.json`, sign it, and create a fresh `.pkpass` bundle per request.
4. Return the `.pkpass` file with `Content-Type: application/vnd.apple.pkpass`.

## 7. Test on Devices

1. Use the Wallet simulator in Xcode (`Debug → Simulate iOS Device`) or email/Airdrop the `.pkpass` to your own device.
2. Ensure the pass opens without warnings. If you see a signature or format error, re-check the certificate password and the manifest hashes.
3. Confirm the barcode scans correctly at the venue or using an iOS Wallet pass tester.

## 8. Prepare for Production

- Monitor certificate expiration dates; Pass Type ID certificates expire after one year.
- If you rotate certificates, keep distributing the old certificate alongside the new one until all older passes are reissued.
- Store pass serial numbers so you can send push updates (using the Apple Wallet web service) when event details change.
- Configure your production domain to serve the Apple Wallet web service endpoints if you plan to support pass updates or voiding.

## Additional References

- [Apple Wallet Developer Guide](https://developer.apple.com/library/archive/documentation/UserExperience/Conceptual/PassKit_PG/Chapters/Introduction.html)
- [PassKit Package Format Reference](https://developer.apple.com/documentation/walletpasses/pass_package_format)
- [WWDR Intermediate Certificate](https://www.apple.com/certificateauthority/)

With these items in place, your Planify deployment can generate and sign Wallet passes that satisfy Apple's validation rules.



<a id="file-docs-complete-api-reference-md"></a>

<a id="file-docs-apple-wallet-testing-checklist-md"></a>
## Apple Wallet Testing Checklist

# Apple Wallet Pass Regression Checklist

Use this checklist after deploying a build that touches Apple Wallet signing or ticket delivery. The steps verify the full pass lifecycle, from generation to on-device installation.

## 1. Pre-flight sanity checks

1. **Confirm configuration**
   - `php artisan tinker --execute="dump(config('wallet.apple'))"` to ensure the pass type identifier, team identifier, certificate paths, and password values are present.
   - On the server, verify the referenced certificate files exist and have the correct permissions (`ls -l /path/to/certs`).
   - (Optional) Enable verbose logging by setting `APPLE_WALLET_DEBUG=true` (and optionally `APPLE_WALLET_LOG_CHANNEL=<channel>`). Review `storage/logs/laravel.log` or the configured channel while exercising the flow.
2. **Clear cache** (if you changed configuration):
   ```bash
   php artisan config:clear
   php artisan cache:clear
   ```

## 2. Generate a fresh pass

1. Purchase or comp a ticket in the environment you just updated.
2. Navigate to the ticket detail page and tap **Add to Apple Wallet**. Confirm the browser starts a download with the `application/vnd.apple.pkpass` content type.

## 3. Inspect the `.pkpass` bundle

1. Download the pass file directly:
   ```bash
   curl -o test.pkpass "https://<your-domain>/ticket/wallet/apple/{event_id}/{secret}"
   ```
2. Unzip and list its contents:
   ```bash
   unzip -l test.pkpass
   ```
   Ensure you see:
   - `pass.json`
   - `manifest.json`
   - `signature`
   - Required image assets (icon/logo pairs, strip/background if configured)
3. Inspect `pass.json` to confirm the event name, attendee name, serial number, and barcodes look correct:
   ```bash
   unzip -p test.pkpass pass.json | jq
   ```

## 4. Validate the manifest signature

1. Extract the signature and manifest:
   ```bash
   unzip -p test.pkpass signature > signature
   unzip -p test.pkpass manifest.json > manifest.json
   ```
2. Verify the detached signature with OpenSSL. Concatenate your pass certificate with the WWDR intermediate first so OpenSSL can locate the signer:
   ```bash
   cat /path/to/PassCertificate.pem /path/to/WWDR.pem > /path/to/pass_chain.pem
   ```
   Then run the verification (requires the WWDR intermediate and Apple Root CA):
   ```bash
   openssl smime -verify -inform DER \
     -in signature \
     -content manifest.json \
     -certfile /path/to/pass_chain.pem \
     -CAfile /path/to/AppleRootCA.pem \
     -nointern -noverify > /dev/null
   ```
   A zero exit status confirms the signature was generated with the expected certificate chain.

## 5. Device installation smoke test

1. Send the `test.pkpass` file to an iOS device (AirDrop, email, or direct download).
2. Add it to Wallet and confirm:
   - The pass shows without the “Cannot Add Pass” error.
   - The barcode renders and matches the ticket secret/URL.
   - Relevant fields (event name, dates, venue, seat info) are populated.

## 6. Event updates (optional)

If you rely on Wallet push updates, trigger an event edit that should update the pass and confirm the device receives the change. Check the server logs for any pass update errors.

## 7. Clean up

Remove temporary files created during inspection:
```bash
rm -f test.pkpass signature manifest.json
```

Document any anomalies you encounter and roll back if the pass fails signature verification or cannot be installed on a device.



<a id="file-docs-cypress-debug-md"></a>

<a id="file-docs-complete-api-reference-md"></a>
## Complete API Reference

# Planify Complete API Reference

**Version:** 2.0.0  
**Last Updated:** December 15, 2025

## Table of Contents

1. Authentication
2. Error Handling
3. Schedules
4. Roles
5. Events
6. Tickets & Sales
7. Talent/Performers
8. Venues
9. Check-ins
10. Media Library
11. Profile
12. OpenAPI/Swagger Specification

---

## Authentication

All API endpoints require authentication using an API key. Generate your key from **Settings → Integrations & API** in the web interface.

### Headers

```http
X-API-Key: <your-api-key>
Accept: application/json
Content-Type: application/json
```

### Rate Limits & Security

- **Per IP:** 60 requests per minute (HTTP 429 when exceeded)
- **Brute-force protection:** After 10 failed API key attempts, the key is blocked for 15 minutes (HTTP 423)
- **Missing or invalid key:** HTTP 401 with error message

### Authorization

Endpoints enforce user-level authorization using Laravel's `ability` middleware:
- **`resources.view`** - Read-only access to user's resources
- **`resources.manage`** - Full CRUD access to user's resources

---

## Error Handling

All endpoints return standard HTTP status codes with JSON error payloads.

### Error Response Format

```json
{
  "error": "Error message",
  "message": "Detailed description"
}
```

### Status Codes

| Code | Reason | Example |
|------|--------|---------|
| 200 | OK | Successful GET/PATCH/DELETE |
| 201 | Created | Successful POST |
| 401 | Unauthorized | Missing or invalid API key |
| 403 | Forbidden | User lacks access to resource |
| 404 | Not Found | Resource doesn't exist |
| 422 | Validation Error | Invalid request data |
| 423 | Locked | API key temporarily blocked |
| 429 | Too Many Requests | Rate limit exceeded |

### Example Error Responses

**Missing API Key (401):**
```json
{
  "error": "API key is required"
}
```

**Invalid API Key (401):**
```json
{
  "error": "Invalid API key"
}
```

**Unauthorized Access (403):**
```json
{
  "error": "Unauthorized"
}
```

**Validation Error (422):**
```json
{
  "message": "The given data was invalid.",
  "errors": {
    "name": ["The name field is required."],
    "email": ["The email must be a valid email address."]
  }
}
```

---

## Schedules

Schedules represent the authenticated user's venues, talent, curators, and other roles.

### GET /api/schedules

List all schedules for the authenticated user.

**Ability:** `resources.view`

**Query Parameters:**
- `type` (optional) - Filter by type (comma-separated): `venue`, `curator`, `talent`
- `name` (optional) - Filter by name substring
- `per_page` (optional) - Results per page (max 1000, default 100)

**Example Request:**
```bash
curl -H "X-API-Key: $API_KEY" \
  "https://your-domain.com/api/schedules?type=venue&per_page=50"
```

**Success Response (200):**
```json
{
  "data": [
    {
      "id": "YmFzZTY0LWVuY29kZWQ=",
      "url": "https://planify.test/sample-venue",
      "type": "venue",
      "subdomain": "sample-venue",
      "name": "Sample Venue",
      "timezone": "UTC",
      "groups": [
        {
          "id": "R1JPVVAtMQ==",
          "name": "Main Stage",
          "slug": "main-stage"
        }
      ],
      "contacts": [
        {
          "name": "Support",
          "email": "support@example.com",
          "phone": "+1234567890"
        }
      ]
    }
  ],
  "meta": {
    "current_page": 1,
    "per_page": 100,
    "total": 1,
    "path": "https://planify.test/api/schedules"
  }
}
```

---

## Roles

Roles represent venues, curators, and talent. Use these endpoints to manage organizational entities.

### GET /api/roles

List roles owned by the authenticated user.

**Ability:** `resources.view`

**Query Parameters:**
- `type` (optional) - Filter by type (comma-separated): `venue`, `curator`, `talent`
- `name` (optional) - Filter by name substring
- `per_page` (optional) - Results per page (max 1000)

**Example Request:**
```bash
curl -H "X-API-Key: $API_KEY" \
  "https://your-domain.com/api/roles?type=venue,talent"
```

**Success Response (200):**
```json
{
  "data": [
    {
      "id": 1,
      "name": "The Jazz Club",
      "type": "venue",
      "subdomain": "jazz-club",
      "email": "info@jazzclub.com",
      "phone": "+1234567890",
      "website": "https://jazzclub.com",
      "address1": "123 Music St",
      "city": "New York",
      "state": "NY",
      "postal_code": "10001",
      "timezone": "America/New_York"
    }
  ]
}
```

### POST /api/roles

Create a new role (venue, curator, or talent).

**Ability:** `resources.manage`

**Request Body:**
```json
{
  "type": "venue",
  "name": "Downtown Hall",
  "email": "info@downtownhall.com",
  "address1": "123 Main St",
  "city": "Springfield",
  "state": "IL",
  "postal_code": "62701",
  "timezone": "America/Chicago",
  "groups": ["Main Stage", "Side Room"],
  "contacts": [
    {
      "name": "Box Office",
      "email": "tickets@downtownhall.com",
      "phone": "+15551234567"
    }
  ]
}
```

**Required Fields:**
- `type` - One of: `venue`, `curator`, `talent`
- `name` - String
- `email` - Valid email
- `address1` - Required for venues

**Success Response (201):**
```json
{
  "id": 12,
  "name": "Downtown Hall",
  "type": "venue",
  "subdomain": "downtown-hall",
  "email": "info@downtownhall.com"
}
```

### PATCH /api/roles/{role_id}

Update an existing role.

**Ability:** `resources.manage`

**Request Body:**
```json
{
  "name": "Updated Venue Name",
  "phone": "+1555999888"
}
```

**Success Response (200):**
```json
{
  "id": 12,
  "name": "Updated Venue Name",
  "type": "venue"
}
```

### DELETE /api/roles/{role_id}

Delete a role. Deleting a talent also removes events where they are the only member.

**Ability:** `resources.manage`

**Success Response (200):**
```json
{
  "success": true,
  "message": "Role deleted successfully"
}
```

### DELETE /api/roles/{role_id}/contacts/{index}

Remove a contact from a role by its array index.

**Ability:** `resources.manage`

**Example:**
```bash
curl -X DELETE \
  -H "X-API-Key: $API_KEY" \
  "https://your-domain.com/api/roles/12/contacts/0"
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "Contact removed successfully"
}
```

### POST /api/roles/{role_id}/members

Add a member to a role.

**Ability:** `resources.manage`

**Request Body:**
```json
{
  "email": "newmember@example.com",
  "role_label": "volunteer"
}
```

**Success Response (201):**
```json
{
  "id": 345,
  "user_id": 123,
  "email": "newmember@example.com",
  "role_label": "volunteer",
  "status": "invited"
}
```

### PATCH /api/roles/{role_id}/members/{member_id}

Update a role member.

**Ability:** `resources.manage`

**Request Body:**
```json
{
  "role_label": "admin",
  "status": "active"
}
```

### DELETE /api/roles/{role_id}/members/{member_id}

Remove a member from a role.

**Ability:** `resources.manage`

**Success Response (200):**
```json
{
  "success": true
}
```

---

## Events

Events are the core scheduling entities. They can be attached to venues, talent, or curators.

### GET /api/events

List all events owned by the authenticated user.

**Ability:** `resources.view`

**Query Parameters:**
- `per_page` (optional) - Results per page (default 100)

**Example Request:**
```bash
curl -H "X-API-Key: $API_KEY" \
  "https://your-domain.com/api/events?per_page=50"
```

**Success Response (200):**
```json
{
  "data": [
    {
      "id": "RVZFTlQtMQ==",
      "numeric_id": 1,
      "name": "Jazz Night",
      "slug": "jazz-night",
      "description": "An evening of smooth jazz",
      "starts_at": "2024-01-15T20:00:00Z",
      "ends_at": "2024-01-15T23:00:00Z",
      "duration": 180,
      "timezone": "America/New_York",
      "tickets_enabled": true,
      "ticket_currency_code": "USD",
      "payment_method": "stripe",
      "tickets": [
        {
          "id": "VElDS0VULTE=",
          "type": "General Admission",
          "price": 2500,
          "quantity": 100,
          "sold": 45
        }
      ],
      "members": {
        "Uk9MRS0y": {
          "name": "The Quartet",
          "email": "quartet@example.com",
          "youtube_url": null
        }
      },
      "venue": {
        "id": "Uk9MRS0z",
        "type": "venue",
        "name": "The Jazz Club",
        "address1": "123 Music St",
        "city": "New York"
      },
      "flyer_image_url": "https://cdn.example.com/flyers/jazz-night.jpg"
    }
  ],
  "meta": {
    "current_page": 1,
    "per_page": 100,
    "total": 25
  }
}
```

### GET /api/events/resources

Get a quick picker of all venues, curators, and talent for building event forms.

**Ability:** `resources.view`

**Success Response (200):**
```json
{
  "venues": [...],
  "curators": [...],
  "talent": [...],
  "meta": {
    "total_roles": 15
  }
}
```

### POST /api/events/{subdomain}

Create a new event under a schedule (identified by subdomain).

**Ability:** `resources.manage`

**URL Parameters:**
- `subdomain` - The subdomain of the venue/talent/curator (from `/api/schedules`)

**Request Body:**
```json
{
  "name": "Summer Concert",
  "starts_at": "2024-07-01 20:00:00",
  "timezone": "America/Los_Angeles",
  "venue_id": "Uk9MRS0z",
  "schedule": "main-stage",
  "category_name": "Concert",
  "description": "An outdoor summer concert",
  "duration": 180,
  "members": [
    {
      "name": "Headliner Band",
      "email": "booking@headliner.com"
    }
  ],
  "tickets_enabled": true,
  "ticket_currency_code": "USD",
  "tickets": [
    {
      "type": "General Admission",
      "price": 3500,
      "quantity": 200
    },
    {
      "type": "VIP",
      "price": 7500,
      "quantity": 50,
      "description": "Includes backstage pass"
    }
  ],
  "payment_method": "stripe",
  "event_url": "https://stream.example.com/summer"
}
```

**Required Fields:**
- `name` - String
- `starts_at` - Format: `Y-m-d H:i:s`
- `timezone` - IANA timezone (e.g., `America/New_York`)
- At least one of: `venue_id`, `venue_address1`, or `event_url`

**Optional Fields:**
- `description` - Event description
- `duration` - Duration in minutes
- `members` - Array of talent/performers
- `curators` - Array of curator IDs
- `schedule` - Sub-schedule slug
- `category_name` or `category_id` - Event category
- `tickets_enabled` - Boolean
- `tickets` - Array of ticket types
- `payment_method` - `cash`, `stripe`, `invoiceninja`, `payment_url`
- `payment_instructions` - Custom payment text
- `registration_url` - External registration link
- `event_url` - Online event URL
- `flyer_image_id` - Existing media asset ID

**Success Response (201):**
```json
{
  "data": {
    "id": "RVZFTlQtNQ==",
    "name": "Summer Concert",
    "starts_at": "2024-07-01T20:00:00Z",
    "tickets_enabled": true
  },
  "meta": {
    "message": "Event created successfully"
  }
}
```

### PATCH /api/events/{event_id}

Update an existing event.

**Ability:** `resources.manage`

**URL Parameters:**
- `event_id` - Encoded event ID

**Request Body:** (All fields optional)
```json
{
  "name": "Updated Event Name",
  "starts_at": "2024-07-01 21:00:00",
  "timezone": "America/Los_Angeles",
  "description": "Updated description",
  "members": [
    {
      "name": "New Performer"
    }
  ]
}
```

**Success Response (200):**
```json
{
  "data": {
    "id": "RVZFTlQtNQ==",
    "name": "Updated Event Name",
    "starts_at": "2024-07-01T21:00:00Z"
  },
  "meta": {
    "message": "Event updated successfully"
  }
}
```

### DELETE /api/events/{event_id}

Delete an event.

**Ability:** `resources.manage`

**Success Response (200):**
```json
{
  "meta": {
    "message": "Event deleted successfully"
  }
}
```

### POST /api/events/flyer/{event_id}

Upload or update an event flyer image.

**Ability:** `resources.view`

**Request Options:**

**Option 1: Upload new image (multipart/form-data)**
```bash
curl -X POST \
  -H "X-API-Key: $API_KEY" \
  -F "flyer_image=@/path/to/flyer.jpg" \
  "https://your-domain.com/api/events/flyer/RVZFTlQtNQ=="
```

**Option 2: Reuse existing media asset (JSON)**
```json
{
  "flyer_image_id": 42
}
```

**Success Response (200):**
```json
{
  "data": {
    "id": "RVZFTlQtNQ==",
    "flyer_image_url": "https://cdn.example.com/flyers/summer-concert.jpg"
  },
  "meta": {
    "message": "Flyer uploaded successfully"
  }
}
```

---

## Tickets & Sales

Manage ticket sales, scanning, and checkout processes.

### GET /api/tickets

List ticket sales for the authenticated user.

**Ability:** `resources.view`

**Query Parameters:**
- `event_id` (optional) - Filter by event ID
- `query` (optional) - Search by name or email

**Success Response (200):**
```json
{
  "data": [
    {
      "id": 123,
      "status": "paid",
      "name": "John Doe",
      "email": "john@example.com",
      "event_id": 1,
      "event": {
        "id": "RVZFTlQtMQ==",
        "name": "Jazz Night"
      },
      "tickets": [
        {
          "id": 456,
          "ticket_id": 789,
          "quantity": 2,
          "usage_status": "unused"
        }
      ]
    }
  ],
  "meta": {
    "current_page": 1,
    "last_page": 5,
    "per_page": 50,
    "total": 234
  }
}
```

### PATCH /api/tickets/{sale_id}

Update a ticket sale (mark as paid, refund, cancel, delete, or update holder info).

**Ability:** `resources.manage`

**Request Body:**
```json
{
  "action": "mark_paid",
  "name": "Jane Doe",
  "email": "jane@example.com"
}
```

**Available Actions:**
- `mark_paid` - Mark unpaid sale as paid (sets status to "paid")
- `mark_unpaid` - Mark paid or cancelled sale as unpaid (sets status to "unpaid")
- `refund` - Refund a paid sale (sets status to "refunded")
- `cancel` - Cancel an unpaid or paid sale (sets status to "cancelled")
- `delete` - Soft delete the sale (sets is_deleted flag, does not remove from database)
- `mark_used` - Mark all ticket entries in this sale as used (sets scanned_at timestamp)
- `mark_unused` - Mark all ticket entries in this sale as unused (clears scanned_at timestamp)

**Action Constraints:**
- `mark_paid`: Only works if status is "unpaid"
- `mark_unpaid`: Only works if status is "paid" or "cancelled"
- `refund`: Only works if status is "paid"
- `cancel`: Only works if status is "unpaid" or "paid"
- `delete`: Works on any sale
- `mark_used`: Marks only entries where scanned_at is null
- `mark_unused`: Clears scanned_at only for entries that have been scanned

**Success Response (200):**
```json
{
  "data": {
    "id": 123,
    "status": "paid"
  }
}
```

### POST /api/tickets/{sale_id}/scan

Record a ticket scan at the event.

**Ability:** `resources.manage`

**Request Body:**
```json
{
  "sale_ticket_id": 456,
  "seat_number": "A12"
}
```

**Success Response (201):**
```json
{
  "data": {
    "entry_id": 789,
    "scanned_at": "2024-01-15T20:30:00Z"
  }
}
```

### POST /api/tickets/{sale_id}/checkout

Create a Stripe checkout session for a sale.

**Ability:** `resources.manage`

**Success Response (201):**
```json
{
  "data": {
    "url": "https://checkout.stripe.com/pay/cs_test_ABC123",
    "id": "cs_test_ABC123"
  }
}
```

### POST /api/events/{subdomain}/checkout

Create a new ticket sale for an event.

**Ability:** `resources.manage`

**Request Body:**
```json
{
  "name": "Jane Smith",
  "email": "jane@example.com",
  "event_date": "2024-07-01",
  "tickets": {
    "VElDS0VULTE=": 2,
    "VElDS0VULTI=": 1
  }
}
```

**Success Response (201):**
```json
{
  "data": {
    "id": "U0FMRS0xMjM=",
    "status": "pending",
    "payment_method": "stripe"
  }
}
```

### POST /api/tickets/{sale_id}/reassign

Reassign a ticket to a new holder.

**Ability:** `resources.manage`

**Request Body:**
```json
{
  "new_holder_name": "Jane Smith",
  "new_holder_email": "jane@example.com"
}
```

**Success Response (200):**
```json
{
  "message": "Ticket reassigned successfully",
  "data": {
    "id": 123,
    "new_holder_name": "Jane Smith",
    "new_holder_email": "jane@example.com"
  }
}
```

### POST /api/tickets/{sale_id}/notes

Add an internal note to a ticket.

**Ability:** `resources.manage`

**Request Body:**
```json
{
  "note": "Customer requested aisle seat"
}
```

**Success Response (201):**
```json
{
  "message": "Note added successfully",
  "data": {
    "note": "Customer requested aisle seat",
    "created_at": "2024-01-15T14:30:00Z"
  }
}
```

---

## Talent/Performers

Manage talent and performers separately from the roles system.

### GET /api/talent

List all talent owned by the authenticated user.

**Ability:** `resources.view`

**Success Response (200):**
```json
{
  "data": [
    {
      "id": 1,
      "name": "The Jazz Quartet",
      "email": "booking@jazzquartet.com",
      "phone": "+1234567890",
      "website": "https://jazzquartet.com",
      "description": "Smooth jazz ensemble",
      "address1": "456 Music Ave",
      "city": "Nashville",
      "state": "TN",
      "postal_code": "37201",
      "country_code": "US",
      "timezone": "America/Chicago",
      "subdomain": "jazz-quartet",
      "created_at": "2024-01-01T00:00:00Z",
      "updated_at": "2024-01-15T10:30:00Z"
    }
  ]
}
```

### GET /api/talent/{id}

Get a single talent by ID.

**Ability:** `resources.view`

**Success Response (200):**
```json
{
  "id": 1,
  "name": "The Jazz Quartet",
  "email": "booking@jazzquartet.com",
  "description": "Smooth jazz ensemble",
  "subdomain": "jazz-quartet"
}
```

### POST /api/talent

Create new talent.

**Ability:** `resources.manage`

**Request Body:**
```json
{
  "name": "New Artist",
  "email": "artist@example.com",
  "phone": "+1555123456",
  "website": "https://newartist.com",
  "description": "Emerging talent in folk music",
  "address1": "789 Artist Lane",
  "city": "Austin",
  "state": "TX",
  "postal_code": "78701",
  "country_code": "US",
  "timezone": "America/Chicago"
}
```

**Required Fields:**
- `name` - String

**Success Response (201):**
```json
{
  "id": 2,
  "name": "New Artist",
  "email": "artist@example.com",
  "subdomain": "new-artist",
  "created_at": "2024-01-15T14:00:00Z"
}
```

### PUT /api/talent/{id}

Update existing talent.

**Ability:** `resources.manage`

**Request Body:** (All fields optional)
```json
{
  "name": "Updated Artist Name",
  "phone": "+1555999888"
}
```

**Success Response (200):**
```json
{
  "id": 2,
  "name": "Updated Artist Name",
  "phone": "+1555999888"
}
```

### DELETE /api/talent/{id}

Delete talent.

**Ability:** `resources.manage`

**Success Response (200):**
```json
{
  "message": "Talent deleted successfully"
}
```

---

## Venues

Manage venues independently from the roles system.

### GET /api/venues

List all venues owned by the authenticated user.

**Ability:** `resources.view`

**Success Response (200):**
```json
{
  "data": [
    {
      "id": 1,
      "name": "The Grand Theater",
      "email": "info@grandtheater.com",
      "phone": "+1234567890",
      "website": "https://grandtheater.com",
      "description": "Historic theater downtown",
      "address1": "100 Main Street",
      "address2": "Suite 200",
      "city": "Boston",
      "state": "MA",
      "postal_code": "02101",
      "country_code": "US",
      "formatted_address": "100 Main Street, Suite 200, Boston, MA 02101",
      "geo_lat": 42.3601,
      "geo_lon": -71.0589,
      "timezone": "America/New_York",
      "subdomain": "grand-theater",
      "created_at": "2024-01-01T00:00:00Z",
      "updated_at": "2024-01-15T10:30:00Z"
    }
  ]
}
```

### GET /api/venues/{id}

Get a single venue by ID.

**Ability:** `resources.view`

**Success Response (200):**
```json
{
  "id": 1,
  "name": "The Grand Theater",
  "address1": "100 Main Street",
  "city": "Boston",
  "geo_lat": 42.3601,
  "geo_lon": -71.0589
}
```

### POST /api/venues

Create a new venue.

**Ability:** `resources.manage`

**Request Body:**
```json
{
  "name": "New Venue",
  "email": "contact@newvenue.com",
  "phone": "+1555789456",
  "website": "https://newvenue.com",
  "description": "Modern event space",
  "address1": "200 Event Plaza",
  "city": "Chicago",
  "state": "IL",
  "postal_code": "60601",
  "country_code": "US",
  "timezone": "America/Chicago",
  "geo_lat": 41.8781,
  "geo_lon": -87.6298
}
```

**Required Fields:**
- `name` - String

**Success Response (201):**
```json
{
  "id": 2,
  "name": "New Venue",
  "subdomain": "new-venue",
  "created_at": "2024-01-15T14:00:00Z"
}
```

### PUT /api/venues/{id}

Update an existing venue.

**Ability:** `resources.manage`

**Request Body:** (All fields optional)
```json
{
  "name": "Updated Venue Name",
  "phone": "+1555999777"
}
```

**Success Response (200):**
```json
{
  "id": 2,
  "name": "Updated Venue Name",
  "phone": "+1555999777"
}
```

### DELETE /api/venues/{id}

Delete a venue.

**Ability:** `resources.manage`

**Success Response (200):**
```json
{
  "message": "Venue deleted successfully"
}
```

---

## Check-ins

Track event attendee check-ins.

### POST /api/checkins

Record a check-in for an event.

**Ability:** `resources.manage`

**Request Body:**
```json
{
  "event_id": 123,
  "attendee_name": "John Doe",
  "attendee_email": "john@example.com",
  "notes": "VIP guest, early arrival"
}
```

**Required Fields:**
- `event_id` - Integer
- `attendee_name` - String

**Success Response (201):**
```json
{
  "id": 456,
  "event_id": 123,
  "attendee_name": "John Doe",
  "attendee_email": "john@example.com",
  "checked_in_at": "2024-01-15T20:15:00Z",
  "notes": "VIP guest, early arrival"
}
```

### GET /api/checkins

List check-ins for an event.

**Ability:** `resources.view`

**Query Parameters:**
- `event_id` (required) - Event ID

**Example Request:**
```bash
curl -H "X-API-Key: $API_KEY" \
  "https://your-domain.com/api/checkins?event_id=123"
```

**Success Response (200):**
```json
{
  "data": [
    {
      "id": 456,
      "event_id": 123,
      "attendee_name": "John Doe",
      "attendee_email": "john@example.com",
      "checked_in_at": "2024-01-15T20:15:00Z",
      "notes": "VIP guest"
    },
    {
      "id": 457,
      "event_id": 123,
      "attendee_name": "Jane Smith",
      "attendee_email": "jane@example.com",
      "checked_in_at": "2024-01-15T20:18:00Z",
      "notes": null
    }
  ]
}
```

---

## Media Library

Manage media assets for events and roles.

### GET /api/media

List media assets.

**Ability:** `resources.view`

**Success Response (200):**
```json
{
  "data": [
    {
      "id": 1,
      "filename": "event-banner.jpg",
      "url": "https://cdn.example.com/media/event-banner.jpg",
      "mime_type": "image/jpeg",
      "size": 245678,
      "variants": [
        {
          "label": "thumb",
          "url": "https://cdn.example.com/media/event-banner_thumb.jpg"
        }
      ],
      "tags": [
        {"id": 1, "name": "banners"},
        {"id": 3, "name": "events"}
      ]
    }
  ]
}
```

### POST /api/media

Upload a new media asset.

**Ability:** `resources.manage`

**Request (multipart/form-data):**
```bash
curl -X POST \
  -H "X-API-Key: $API_KEY" \
  -F "file=@/path/to/image.jpg" \
  -F "tags[]=1" \
  -F "tags[]=3" \
  "https://your-domain.com/api/media"
```

**Success Response (201):**
```json
{
  "id": 555,
  "filename": "image.jpg",
  "url": "https://cdn.example.com/media/image.jpg",
  "mime_type": "image/jpeg",
  "size": 123456
}
```

### DELETE /api/media/{asset}

Delete a media asset.

**Ability:** `resources.manage`

**Success Response (200):**
```json
{
  "success": true
}
```

### POST /api/media/{asset}/variant

Upload a variant (e.g., thumbnail) for an existing asset.

**Ability:** `resources.manage`

**Request (multipart/form-data):**
```bash
curl -X POST \
  -H "X-API-Key: $API_KEY" \
  -F "file=@/path/to/thumbnail.jpg" \
  -F "label=thumb" \
  "https://your-domain.com/api/media/555/variant"
```

**Success Response (201):**
```json
{
  "label": "thumb",
  "url": "https://cdn.example.com/media/image_thumb.jpg"
}
```

### GET /api/media/tags

List all media tags.

**Ability:** `resources.view`

**Success Response (200):**
```json
{
  "data": [
    {"id": 1, "name": "photos"},
    {"id": 2, "name": "logos"},
    {"id": 3, "name": "banners"}
  ]
}
```

### POST /api/media/tags

Create a new media tag.

**Ability:** `resources.manage`

**Request Body:**
```json
{
  "name": "flyers"
}
```

**Success Response (201):**
```json
{
  "id": 4,
  "name": "flyers"
}
```

### DELETE /api/media/tags/{tag}

Delete a media tag.

**Ability:** `resources.manage`

**Success Response (200):**
```json
{
  "success": true
}
```

### POST /api/media/{asset}/sync-tags

Sync tags for a media asset (replaces all existing tags).

**Ability:** `resources.manage`

**Request Body:**
```json
{
  "tags": [1, 3, 4]
}
```

**Success Response (200):**
```json
{
  "success": true
}
```

---

## Profile

Manage the authenticated user's profile.

### PATCH /api/profile

Update the user's profile.

**Ability:** `resources.manage`

**Request Body:**
```json
{
  "name": "John Smith",
  "email": "john.smith@example.com",
  "bio": "Event organizer and music enthusiast"
}
```

**Success Response (200):**
```json
{
  "id": 1,
  "name": "John Smith",
  "email": "john.smith@example.com",
  "bio": "Event organizer and music enthusiast"
}
```

### DELETE /api/profile

Delete the authenticated user's account.

**Ability:** `resources.manage`

**Request Body:**
```json
{
  "password": "user-password"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "Account deleted successfully"
}
```

---

## OpenAPI Specification

### Complete OpenAPI/Swagger YAML

```yaml
openapi: 3.0.3
info:
  title: Planify API
  version: 2.0.0
  description: >-
    Complete REST API for Planify event management system.
    Includes schedules, roles, events, ticketing, talent, venues, check-ins, and media management.

servers:
  - url: https://your-domain.com/api
    description: Production server
  - url: http://localhost/api
    description: Local development

components:
  securitySchemes:
    ApiKeyAuth:
      type: apiKey
      in: header
      name: X-API-Key
      description: API key from Settings → Integrations & API

  schemas:
    Error:
      type: object
      properties:
        error:
          type: string
          example: "Invalid API key"
        message:
          type: string
          example: "Detailed error description"

    Talent:
      type: object
      properties:
        id:
          type: integer
          example: 1
        name:
          type: string
          example: "The Jazz Quartet"
        email:
          type: string
          example: "booking@jazzquartet.com"
        phone:
          type: string
          example: "+1234567890"
        website:
          type: string
          example: "https://jazzquartet.com"
        description:
          type: string
        address1:
          type: string
        city:
          type: string
        state:
          type: string
        postal_code:
          type: string
        country_code:
          type: string
        timezone:
          type: string
          example: "America/New_York"
        subdomain:
          type: string
          example: "jazz-quartet"
        created_at:
          type: string
          format: date-time
        updated_at:
          type: string
          format: date-time

    Venue:
      type: object
      properties:
        id:
          type: integer
        name:
          type: string
        email:
          type: string
        phone:
          type: string
        website:
          type: string
        description:
          type: string
        address1:
          type: string
        address2:
          type: string
        city:
          type: string
        state:
          type: string
        postal_code:
          type: string
        country_code:
          type: string
        formatted_address:
          type: string
        geo_lat:
          type: number
          format: float
          minimum: -90
          maximum: 90
        geo_lon:
          type: number
          format: float
          minimum: -180
          maximum: 180
        timezone:
          type: string
        subdomain:
          type: string
        created_at:
          type: string
          format: date-time
        updated_at:
          type: string
          format: date-time

    CheckIn:
      type: object
      properties:
        id:
          type: integer
        event_id:
          type: integer
        attendee_name:
          type: string
        attendee_email:
          type: string
        checked_in_at:
          type: string
          format: date-time
        notes:
          type: string

    TicketSale:
      type: object
      properties:
        id:
          type: integer
        status:
          type: string
          enum: [pending, paid, cancelled, refunded, expired]
        name:
          type: string
        email:
          type: string
        event_id:
          type: integer
        tickets:
          type: array
          items:
            type: object
            properties:
              id:
                type: integer
              ticket_id:
                type: integer
              quantity:
                type: integer
              usage_status:
                type: string

security:
  - ApiKeyAuth: []

paths:
  /schedules:
    get:
      summary: List schedules
      tags: [Schedules]
      parameters:
        - name: type
          in: query
          schema:
            type: string
          description: Filter by type (venue,curator,talent)
        - name: name
          in: query
          schema:
            type: string
          description: Filter by name substring
      responses:
        '200':
          description: Success
        '401':
          description: Unauthorized

  /talent:
    get:
      summary: List all talent
      tags: [Talent]
      responses:
        '200':
          description: Success
          content:
            application/json:
              schema:
                type: object
                properties:
                  data:
                    type: array
                    items:
                      $ref: '#/components/schemas/Talent'
    post:
      summary: Create talent
      tags: [Talent]
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required: [name]
              properties:
                name:
                  type: string
                email:
                  type: string
                phone:
                  type: string
                website:
                  type: string
                description:
                  type: string
      responses:
        '201':
          description: Created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Talent'

  /talent/{id}:
    get:
      summary: Get single talent
      tags: [Talent]
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Success
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Talent'
    put:
      summary: Update talent
      tags: [Talent]
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: integer
      requestBody:
        content:
          application/json:
            schema:
              type: object
      responses:
        '200':
          description: Updated
    delete:
      summary: Delete talent
      tags: [Talent]
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Deleted

  /venues:
    get:
      summary: List all venues
      tags: [Venues]
      responses:
        '200':
          description: Success
          content:
            application/json:
              schema:
                type: object
                properties:
                  data:
                    type: array
                    items:
                      $ref: '#/components/schemas/Venue'
    post:
      summary: Create venue
      tags: [Venues]
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required: [name]
      responses:
        '201':
          description: Created

  /venues/{id}:
    get:
      summary: Get single venue
      tags: [Venues]
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Success
    put:
      summary: Update venue
      tags: [Venues]
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Updated
    delete:
      summary: Delete venue
      tags: [Venues]
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Deleted

  /checkins:
    get:
      summary: List check-ins for an event
      tags: [Check-ins]
      parameters:
        - name: event_id
          in: query
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Success
          content:
            application/json:
              schema:
                type: object
                properties:
                  data:
                    type: array
                    items:
                      $ref: '#/components/schemas/CheckIn'
    post:
      summary: Record a check-in
      tags: [Check-ins]
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required: [event_id, attendee_name]
              properties:
                event_id:
                  type: integer
                attendee_name:
                  type: string
                attendee_email:
                  type: string
                notes:
                  type: string
      responses:
        '201':
          description: Created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/CheckIn'

  /tickets/{sale_id}/reassign:
    post:
      summary: Reassign ticket to new holder
      tags: [Tickets]
      parameters:
        - name: sale_id
          in: path
          required: true
          schema:
            type: integer
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required: [new_holder_name, new_holder_email]
              properties:
                new_holder_name:
                  type: string
                new_holder_email:
                  type: string
      responses:
        '200':
          description: Success

  /tickets/{sale_id}/notes:
    post:
      summary: Add internal note to ticket
      tags: [Tickets]
      parameters:
        - name: sale_id
          in: path
          required: true
          schema:
            type: integer
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required: [note]
              properties:
                note:
                  type: string
                  maxLength: 1000
      responses:
        '201':
          description: Created
```

---

## Quick Start Examples

### Authentication Example

```bash
# Set your API key
export API_KEY="your-api-key-here"

# Make authenticated request
curl -H "X-API-Key: $API_KEY" \
     -H "Accept: application/json" \
     "https://your-domain.com/api/schedules"
```

### Create Complete Event

```bash
curl -X POST "https://your-domain.com/api/events/my-venue" \
  -H "X-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Summer Concert",
    "starts_at": "2024-07-01 20:00:00",
    "timezone": "America/New_York",
    "duration": 180,
    "description": "An evening of great music",
    "venue_id": "dmVudWUtMTIz",
    "members": [{"name": "The Band"}],
    "tickets_enabled": true,
    "ticket_currency_code": "USD",
    "tickets": [
      {"type": "General", "price": 2500, "quantity": 200}
    ]
  }'
```

### Track Check-ins

```bash
# Record check-in
curl -X POST "https://your-domain.com/api/checkins" \
  -H "X-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "event_id": 123,
    "attendee_name": "John Doe",
    "attendee_email": "john@example.com"
  }'

# List check-ins
curl -H "X-API-Key: $API_KEY" \
  "https://your-domain.com/api/checkins?event_id=123"
```

---

## Support & Resources

- **Documentation:** This file and related docs in `/docs`
- **Route Definitions:** `routes/api.php`
- **Controllers:** `app/Http/Controllers/Api/`
- **Models:** `app/Models/`
- **Middleware:** `app/Http/Middleware/ApiAuthentication.php`

For additional help, refer to the Laravel documentation or contact support.

---

**Last Updated:** December 15, 2025  
**Version:** 2.0.0



<a id="file-docs-postman-scanapi-postman-collection-json"></a>

<a id="file-docs-api-swagger-yaml"></a>
## OpenAPI Spec (YAML)

```yaml
openapi: 3.0.3
info:
  title: Planify API
  version: 2.0.0
  description: >-
    Complete REST API for Planify event management system.
    Includes schedules, roles, events, ticketing, talent, venues, check-ins, and media management.

servers:
  - url: https://your-domain.com/api
    description: Production server
  - url: http://localhost/api
    description: Local development

components:
  securitySchemes:
    ApiKeyAuth:
      type: apiKey
      in: header
      name: X-API-Key
      description: API key from Settings → Integrations & API
  schemas:
    Error:
      type: object
      properties:
        error:
          type: string
    UserProfile:
      type: object
      properties:
        id:
          type: integer
        name:
          type: string
        email:
          type: string
        avatar_url:
          type: string
        bio:
          type: string
    Role:
      type: object
      properties:
        id:
          type: integer
        name:
          type: string
        type:
          type: string
    RoleMember:
      type: object
      properties:
        id:
          type: integer
        user_id:
          type: integer
        email:
          type: string
        role_label:
          type: string
        status:
          type: string
    Event:
      type: object
      description: Canonical Event representation used for create/update/list responses.
      properties:
        id:
          type: string
          description: Encoded event id (use `UrlUtils::encodeId` on the backend). Clients should treat this as an opaque id.
        numeric_id:
          type: integer
          description: Internal numeric id (optional; present for debugging). Prefer using `id`.
        subdomain:
          type: string
        name:
          type: string
        description:
          type: string
        starts_at:
          type: string
          format: date-time
        ends_at:
          type: string
          format: date-time
        timezone:
          type: string
          description: IANA timezone for the event (required on create/update).
        role_id:
          type: string
          description: Encoded role id to attach (optional). Use encoded role ids consistent with other API endpoints.
        venue_id:
          type: string
          description: Encoded venue role id (if applicable).
        tickets_enabled:
          type: boolean
        ticket_currency_code:
          type: string
        ticket_notes:
          type: string
        total_tickets_mode:
          type: string
          enum: [individual, combined]
        payment_method:
          type: string
        payment_instructions:
          type: string
        expire_unpaid_tickets:
          type: boolean
        remind_unpaid_tickets_every:
          type: integer
        registration_url:
          type: string
        show_guest_list:
          type: boolean
        guest_list_visibility:
          type: string
        category_id:
          type: integer
        creator_role_id:
          type: string
        flyer_image_id:
          type: integer
        google_event_id:
          type: string
    Ticket:
      type: object
      properties:
        id:
          type: integer
        ticket_type:
          type: string
        seat_number:
          type: string
        status:
          type: string
    Sale:
      type: object
      properties:
        id:
          type: integer
        status:
          type: string
        name:
          type: string
        email:
          type: string
        total_cents:
          type: integer
        currency:
          type: string
        created_at:
          type: string
        tickets:
          type: array
          items:
            $ref: '#/components/schemas/Ticket'
    MediaAsset:
      type: object
      properties:
        responses:
          '200':
            description: OK
            content:
              application/json:
                schema:
                  type: array
                  items:
                    $ref: '#/components/schemas/MediaTag'
          type: string
        url:
          type: string
        mime_type:
          type: string
        size:
          type: integer
        variants:
          type: array
          items:
            type: object
            properties:
          '201':
            description: Created
            content:
              application/json:
                schema:
                  $ref: '#/components/schemas/MediaTag'
              url:
                type: string
    MediaTag:
      type: object
      properties:
        id:
          type: integer
        name:
          type: string
    SuccessResponse:
      type: object
      properties:
        success:
          type: boolean
    RoleCreateRequest:
      type: object
      required: [name]
      properties:
        name:
          type: string
        type:
          type: string
    RoleUpdateRequest:
      type: object
      properties:
        name:
          type: string
        type:
          type: string
    RoleMemberCreateRequest:
      type: object
      required: [email]
      properties:
        user_id:
          type: integer
        email:
          type: string
        role_label:
          type: string
    UserProfileUpdate:
      type: object
      properties:
        name:
          type: string
        email:
          type: string
        bio:
          type: string
    EventCreateRequest:
      type: object
      description: Fields accepted when creating an event. `timezone` is required by the backend.
      required: [timezone]
      properties:
        role_id:
          type: string
          description: Encoded role id to attach the event to (optional). If omitted the server may infer role from the request context.
        name:
          type: string
        starts_at:
          type: string
          format: date-time
        description:
          type: string
        timezone:
          type: string
          description: IANA timezone (required).
        venue_id:
          type: string
          description: Encoded role id representing a venue (optional).
        tickets_enabled:
          type: boolean
        ticket_currency_code:
          type: string
        ticket_notes:
          type: string
        total_tickets_mode:
          type: string
          enum: [individual, combined]
        payment_method:
          type: string
        payment_instructions:
          type: string
        expire_unpaid_tickets:
          type: boolean
        remind_unpaid_tickets_every:
          type: integer
        registration_url:
          type: string
        show_guest_list:
          type: boolean
        guest_list_visibility:
          type: string
        category_id:
          type: integer
        creator_role_id:
          type: string
        flyer_image_id:
          type: integer
        google_event_id:
          type: string
    EventUpdateRequest:
      type: object
      description: Fields accepted when updating an event. `timezone` is required by the backend.
      required: [timezone]
      properties:
        role_id:
          type: string
          description: Encoded role id to attach the event to (optional).
        name:
          type: string
        starts_at:
          type: string
          format: date-time
        ends_at:
          type: string
          format: date-time
        description:
          type: string
        timezone:
          type: string
          description: IANA timezone (required).
        venue_id:
          type: string
        tickets_enabled:
          type: boolean
        ticket_currency_code:
          type: string
        ticket_notes:
          type: string
        total_tickets_mode:
          type: string
          enum: [individual, combined]
        payment_method:
          type: string
        payment_instructions:
          type: string
        expire_unpaid_tickets:
          type: boolean
        remind_unpaid_tickets_every:
          type: integer
        registration_url:
          type: string
        show_guest_list:
          type: boolean
        guest_list_visibility:
          type: string
        category_id:
          type: integer
        creator_role_id:
          type: string
        flyer_image_id:
          type: integer
        google_event_id:
          type: string
    CreateSaleRequest:
      type: object
      required: [name,email]
      properties:
        name:
          type: string
        email:
          type: string
        event_date:
          type: string
        tickets:
          type: array
          items:
            type: object
            properties:
              ticket_type:
                type: string
              quantity:
                type: integer
    CheckoutSessionResponse:
      type: object
      properties:
        data:
          type: object
          properties:
            url:
              type: string
            id:
              type: string
    TicketActionRequest:
      type: object
      properties:
        action:
          type: string
          enum: [mark_paid, mark_unpaid, refund, cancel, delete, mark_used, mark_unused]
          description: |
            Available actions:
            - mark_paid: Mark unpaid sale as paid
            - mark_unpaid: Mark paid/cancelled sale as unpaid
            - refund: Refund a paid sale
            - cancel: Cancel an unpaid/paid sale
            - delete: Soft delete the sale
            - mark_used: Mark all ticket entries as used
            - mark_unused: Mark all ticket entries as unused
        name:
          type: string
          description: Update ticket holder name
        email:
          type: string
          format: email
          description: Update ticket holder email
    ScanRecordRequest:
      type: object
      properties:
        sale_ticket_id:
          type: integer
        seat_number:
    Talent:
      type: object
      properties:
        id:
          type: integer
          example: 1
        name:
          type: string
      tags: [Schedules]
      parameters:
        - name: type
          in: query
          schema:
            type: string
          description: Filter by type (venue,curator,talent)
      tags: [Roles]
      parameters:
        - name: type
          in: query
          schema:
            type: string
          description: Filter by type (venue,curator,talent)
        - name: name
          in: query
          schema:
            type: string
      tags: [Roles]
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/RoleCreateRequest'
      responses:
        '201':
          description: Created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Role'
              examples:
                roleCreated:
                  summary: Example role
                  value:
                    id: 12
                    name: Volunteers
                    type: venuerized
          content:
            application/json:
              schema:
      tags: [Roles]
                $ref: '#/components/schemas/Error'
          example: "booking@jazzquartet.com"
        phone:
          type: string
          example: "+1234567890"
        website:
          type: string
          example: "https://jazzquartet.com"
        description:
          type: string
        address1:
          type: string
        address2:
          type: string
        city:
          type: string
        state:
          type: string
      tags: [Roles]
        postal_code:
          type: string
        country_code:
          type: string
        timezone:
          type: string
          example: "America/New_York"
        subdomain:
          type: string
          example: "jazz-quartet"
        created_at:
          type: string
          format: date-time
        updated_at:
          type: string
          format: date-time
    TalentCreateRequest:
      type: object
      required: [name]
      properties:
        name:
          type: string
        email:
          type: string
          format: email
        phone:
          type: string
      tags: [Events]
      parameters:
        - name: per_page
          in: query
          resources:
    get:
      summary: Get venues, curators, and talent for event form pickers
      tags: [Events]
      responses:
        '200':
          description: OK

  /events/{subdomain}:
    post:
      summary: Create event under subdomain
      tags: [Events]fault 100)
        website:
          type: string
          format: uri
        description:
          type: string
        address1:
          type: string
        address2:
          type: string
        city:
          type: string
        state:
          type: string
        postal_code:
          type: string
        country_code:
          type: string
        timezone:
          type: string
    Venue:
      type: object
      properties:
        id:
          type: integer
        name:
          type: string
        email:
          type: string
        phone:
          type: string
        website:
          type: string
        description:
          type: string
        address1:
          type: string
        address2:
          type: string
        city:
          type: string
        state:
          type: string
        postal_code:
          type: string
        country_code:
          type: string
        formatted_address:
          type: string
        geo_lat:
          type: number
          format: float
          minimum: -90
          maximum: 90
        geo_lon:
          type: number
          format: float
          minimum: -180
          maximum: 180
        timezone:
          type: string
        subdomain:
          type: string
        created_at:
          type: string
          format: date-time
        updated_at:
          type: string
          format: date-time
    VenueCreateRequest:
      type: object
      required: [name]
      properties:
        name:
          type: string
        email:
          type: string
          format: email
        phone:
          type: string
        website:
          type: string
          format: uri
        description:
          type: string
        address1:
          type: string
        address2:
          type: string
        city:
          type: string
        state:
          type: string
        postal_code:
          type: string
        country_code:
          type: string
        formatted_address:
          type: string
        geo_lat:
          type: number
          format: float
        geo_lon:
          type: number
          format: float
        timezone:
          type: string
    CheckIn:
      type: object
      properties:
        id:
          type: integer
        event_id:
          type: integer
        attendee_name:
          type: string
        attendee_email:
          type: string
        checked_in_at:
          type: string
          format: date-time
        notes:
          type: string
    CheckInRequest:
      type: object
      required: [event_id, attendee_name]
      properties:
        event_id:
          type: integer
        attendee_name:
          type: string
        attendee_email:
          type: string
          format: email
        notes:
          type: string
    TicketReassignRequest:
      type: object
      required: [new_holder_name, new_holder_email]
      properties:
        new_holder_name:
          type: string
        new_holder_email:
          type: string
          format: email
    TicketNoteRequest:
      type: object
      required: [note]
      properties:
        note:
          type: string
          maxLength: 1000
          type: string

security:
  - ApiKeyAuth: []

paths:
  /schedules:
    get:
      summary: List schedules
      responses:
        '200':
          description: OK

  /roles:
    get:
      summary: List roles
      responses:
        '200':
          description: OK
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/Role'
    post:
      summary: Create role
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/RoleCreateRequest'
      responses:
        '201':
          description: Created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Role'
              examples:
                roleCreated:
                  summary: Example role
                  value:
                    id: 12
                    name: Volunteers
                    type: team
  /roles/{role_id}:
    delete:
      summary: Delete a role
      parameters:
        - in: path
          name: role_id
          required: true
          schema:
            type: string
      responses:
        '200':
          description: Deleted
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/SuccessResponse'
          content:
            application/json:
      tags: [Events]
              schema:
                $ref: '#/components/schemas/SuccessResponse'
    patch:
      summary: Update a role
      parameters:
        - in: path
          name: role_id
          required: true
          schema:
            type: string
      requestBody:
        required: true
        content:
          application/json:
      tags: [Events]
            schema:
              type: object
              properties:
                name:
                  type: string
                type:
                  type: string
      responses:
        '200':
          description: Updated
      tags: [Events]
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Role'

  /events:
    get:
      summary: List events for authenticated user
      responses:
        '200':
          description: OK

  /events/{subdomain}:
    post:
      summary: Create event under subdomain
      parameters:
        - in: path
          name: subdomain
          required: true
          schema:
            type: string
      requestBody:
  /events/{subdomain}/checkout:
    post:
      summary: Create a sale (checkout) for an event
      tags: [Tickets]
          schema:
              $ref: '#/components/schemas/EventCreateRequest'
      responses:
        '201':
          description: Created

  /events/{event_id}:
    patch:
      summary: Update event
      parameters:
        - in: path
          name: event_id
          required: true
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/EventUpdateRequest'
      responses:
        '200':
          description: Updated
    delete:
      summary: Delete event
      parameters:
        - in: path
          name: event_id
          required: true
      responses:
        '200':
          description: Deleted

  /events/flyer/{event_id}:
    post:
      summary: Upload flyer or set flyer image id
      parameters:
        - in: path
          name: event_id
          required: true
      requestBody:
        content:
          multipart/form-data:
            schema:
              type: object
              properties:
                flyer_image:
                  type: string
                  format: binary
                flyer_image_id:
                  type: integer
      responses:
        '200':
          description: Flyer updated
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Event'

    /etags: [Profile]
      vents/{subdomain}/checkout:
      post:
        summary: Create a sale (checkout) for an event
        parameters:
          - in: path
            name: subdomain
            required: true
        requestBody:
          required: true
          content:
      tags: [Profile]
            application/json:
              schema:
                $ref: '#/components/schemas/CreateSaleRequest'
        responses:
          '201':
            description: Created
            content:
              application/json:
                schema:
                  $ref: '#/components/schemas/Sale'
                examples:
                  saleCreated:
                    summary: Sale created (pending payment)
                    value:
                      id: 9876
                      status: pending
                      name: Jane Doe
                      email: jane@example.com
                      total_cents: 4000
                      currency: USD
                      tickets:
                        - id: 1
                          ticket_type: general
                          status: reserved

  /profile:
    patch:
      summary: Update authenticated user's profile
      requestBody:
        required: true
      tags: [Tickets]
      parameters:
        - name: event_id
          in: query
          schema:
            type: integer
          description: Filter by event ID
      tags: [Tickets]
        - name: query
          in: query
          schema:
            type: string
          description: Search by name or email
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/UserProfileUpdate'
      responses:
        '200':
          description: Updated
    delete:
      summary: Delete authenticated account
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              properties:
                password:
                  type: string
      responses:reassign:
    post:
      summary: Reassign ticket to new holder
      tags: [Tickets]
      parameters:
        - in: path
          name: sale_id
          required: true
          schema:
            type: string
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/TicketReassignRequest'
      responses:
        '200':
          description: Ticket reassigned
          content:
            application/json:
              schema:
                type: object
                properties:
                  message:
      tags: [Tickets]
                    type: string
                  data:
                    type: object

  /tickets/{sale_id}/notes:
    post:
      summary: Add internal note to ticket
      tags: [Tickets]
      parameters:
        - in: path
          name: sale_id
          required: true
          schema:
            type: string
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/TicketNoteRequest'
      responses:
        '201':
          description: Note added
          content:
            application/json:
              schema:
                type: object
                properties:
                  message:
                    type: string
                  data:
   talent:
    get:
      summary: List all talent
      tags: [Talent]
      responses:
        '200':
          description: Success
          content:
            application/json:
              schema:
                type: object
                properties:
                  data:
                    type: array
                    items:
                      $ref: '#/components/schemas/Talent'
    post:
      summary: Create talent
      tags: [Talent]
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/TalentCreateRequest'
      responses:
        '201':
          description: Created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Talent'

  /talent/{id}:
    get:
      summary: Get single talent
      tags: [Talent]
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: integer
      responses:
      tags: [Media]
        '200':
          description: Success
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Talent'
    put:
      summary: Update talent
      tags: [Talent]
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: integer
      tags: [Media]
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/TalentCreateRequest'
      responses:
        '200':
          description: Updated
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Talent'
    delete:
      summary: Delete talent
      tags: [Talent]
      parameters:
        - name: id
      tags: [Media]
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Deleted
          content:
            application/json:
              schema:
                type: object
                properties:
                  message:
                    type: string

  /venues:
    get:
      summary: List all venues
      tags: [Venues]
      tags: [Media]
      responses:
        '200':
          description: Success
          content:
            application/json:
              schema:
                type: object
                properties:
                  data:
                    type: array
                    items:
                      $ref: '#/components/schemas/Venue'
    post:
      summary: Create venue
      tags: [Venues]
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/VenueCreateRequest'
      responses:
        '201':
          description: Created
          content:
      tags: [Media]
            application/json:
              schema:
                $ref: '#/components/schemas/Venue'

  /venues/{id}:
    get:
      summary: Get single venue
      tags: [Venues]
      parameters:
        - name: id
      tags: [Media]
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Success
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Venue'
    put:
      summary: Update venue
      tags: [Venues]
      parameters:
        - name: id
          in: path
      tags: [Roles]
          required: true
          schema:
            type: integer
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/VenueCreateRequest'
      responses:
        '200':
          description: Updated
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Venue'
    delete:
      summary: Delete venue
      tags: [Venues]
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: Deleted
          content:
            application/json:
              schema:
                type: object
                properties:
      tags: [Roles]
                  message:
                    type: string

  /checkins:
    get:
      summary: List check-ins for an event
      tags: [Check-ins]
      parameters:
        - name: event_id
          in: query
          required: true
          schema:
            type: integer
          description: Event ID to get check-ins for
      responses:
        '200':
          description: Success
          content:
            application/json:
              schema:
                type: object
                properties:
                  data:
                    type: array
                    items:
                      $ref: '#/components/schemas/CheckIn'
    post:
      summary: Record a check-in
      tags: [Check-ins]
      requestBody:
      tags: [Roles]
      parameters:
        - in: path
          name: role_id
          required: true
          schema:
            type: string
        - in: path
          name: member_id
          required: true
          schema:
            type: string
      responses:
        '200':
          description: Member removed
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/SuccessResponse'

  /roles/{role_id}/contacts/{index}:
    delete:
      summary: Remove a contact from a role
      tags: [Roles]
      parameters:
        - in: path
          name: role_id
          required: true
          schema:
            type: string
        - in: path
          name: index
          required: true
          schema:
            type: integer
          description: Zero-based index of the contact to remove
      responses:
        '200':
          description: Contact removedets
      tags: [Media]
      responses:
        '200':
          description: OK
    post:
      summary: Upload media asset
      tags: [Media]
    get:
      summary: List ticket sales
      responses:
        '200':
          description: OK

  /tickets/{sale_id}:
    patch:
      summary: Update a sale (actions: mark_paid, mark_unpaid, refund, cancel, delete, mark_used, mark_unused)
      parameters:
        - in: path
          name: sale_id
          required: true
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/TicketActionRequest'
      responses:
        '200':
          description: Updated
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/SuccessResponse'
              examples:
                ticketAction:
                  summary: Action applied
                  value:
                    success: true
                    action: mark_paid

  /tickets/{sale_id}/checkout:
    post:
      summary: Create Stripe Checkout session for a sale
      parameters:
        - in: path
          name: sale_id
          required: true
      responses:
        '201':
          description: Created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/CheckoutSessionResponse'
              examples:
                checkoutSession:
                  summary: Stripe checkout session
                  value:
                    data:
                      url: "https://checkout.stripe.com/pay/cs_test_ABC123"
                      id: "cs_test_ABC123"

  /tickets/{sale_id}/scan:
    post:
      summary: Record a ticket scan
      parameters:
        - in: path
          name: sale_id
          required: true
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/ScanRecordRequest'
      responses:
        '201':
          description: Created
          content:
            application/json:
              schema:
                type: object
                properties:
                  sale_ticket_id:
                    type: integer
                  seat_number:
                    type: string
                  scanned_at:
                    type: string
              examples:
                scanCreated:
                  summary: Scan recorded
                  value:
                    sale_ticket_id: 987
                    seat_number: "A12"
                    scanned_at: "2026-01-15T20:12:34Z"

  /media:
    get:
      summary: List media assets
      responses:
        '200':
          description: OK
    post:
      summary: Upload media asset
      requestBody:
        content:
          multipart/form-data:
            schema:
              type: object
              properties:
                file:
                  type: string
                  format: binary
                tags:
                  type: array
                  items:
                    type: integer
      responses:
        '201':
          description: Created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/MediaAsset'
              examples:
                mediaUploaded:
                  summary: Uploaded media asset
                  value:
                    id: 555
                    filename: "image.jpg"
                    url: "https://cdn.example.com/media/image.jpg"
                    mime_type: "image/jpeg"
                    size: 123456
                    variants:
                      - label: thumb
                        url: "https://cdn.example.com/media/image_thumb.jpg"

  /media/{asset}:
    delete:
      summary: Delete media asset
      parameters:
        - in: path
          name: asset
          required: true
      responses:
        '200':
          description: Deleted
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/SuccessResponse'

  /media/{asset}/variant:
    post:
      summary: Upload a media variant
      requestBody:
        content:
          multipart/form-data:
            schema:
              type: object
              properties:
                file:
                  type: string
                  format: binary
                label:
                  type: string
      responses:
        '201':
          description: Created

  /media/tags:
    get:
      summary: List media tags
      responses:
        '200':
          description: OK
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/MediaTag'
              examples:
                tagsList:
                  summary: Media tags list
                  value:
                    - id: 1
                      name: photos
                    - id: 2
                      name: logos
    post:
      summary: Create media tag
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              properties:
                name:
                  type: string
      responses:
        '201':
          description: Created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/MediaTag'
              examples:
                tagCreated:
                  summary: Example tag
                  value:
                    id: 3
                    name: banners

  /media/tags/{tag}:
    delete:
      summary: Delete media tag
      parameters:
        - in: path
          name: tag
          required: true
      responses:
        '200':
          description: Deleted

  /media/{asset}/sync-tags:
    post:
      summary: Sync tags for an asset
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              properties:
                tags:
                  type: array
                  items:
                    type: integer
      responses:
        '200':
          description: Synced

  /roles/{role_id}/members:
    post:
      summary: Add a member to a role
      parameters:
        - in: path
          name: role_id
          required: true
          schema:
            type: string
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/RoleMemberCreateRequest'
      responses:
        '201':
          description: Member added
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/RoleMember'
              examples:
                memberAdded:
                  summary: Role member created
                  value:
                    id: 345
                    user_id: 123
                    email: new@user.com
                    role_label: volunteer
                    status: invited

  /roles/{role_id}/members/{member_id}:
    patch:
      summary: Update a role member
      parameters:
        - in: path
          name: role_id
          required: true
          schema:
            type: string
        - in: path
          name: member_id
          required: true
          schema:
            type: string
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              properties:
                role_label:
                  type: string
                status:
                  type: string
      responses:
        '200':
          description: Member updated
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/RoleMember'
    delete:
      summary: Remove a member from a role
      parameters:
        - in: path
          name: role_id
          required: true
          schema:
            type: string
        - in: path
          name: member_id
          required: true
          schema:
            type: string
      responses:
        '200':
          description: Member removed
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/SuccessResponse'

```


<a id="file-docs-eventformview-swift"></a>

<a id="file-docs-postman-scanapi-postman-collection-json"></a>
## Postman Collection (Scan API)

```json
{
  "info": {
    "name": "Scan API",
    "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
  },
  "variable": [
    { "key": "baseUrl", "value": "http://127.0.0.1:8000" }
  ],
  "item": [
    {
      "name": "Scan - Entry Secret",
      "request": {
        "method": "POST",
        "header": [{ "key": "Content-Type", "value": "application/json" }],
        "body": { "mode": "raw", "raw": "{\"code\": \"entry-secret-123\", \"location\": \"door-1\"}" },
        "url": { "raw": "{{baseUrl}}/api/tickets/scan", "host": ["{{baseUrl}}"], "path": ["api","tickets","scan"] }
      }
    },
    {
      "name": "Scan - Sale Secret",
      "request": {
        "method": "POST",
        "header": [{ "key": "Content-Type", "value": "application/json" }],
        "body": { "mode": "raw", "raw": "{\"code\": \"sale-secret-ABC\", \"location\": \"door-1\"}" },
        "url": { "raw": "{{baseUrl}}/api/tickets/scan", "host": ["{{baseUrl}}"], "path": ["api","tickets","scan"] }
      }
    },
    {
      "name": "Scan - Invalid Secret",
      "request": {
        "method": "POST",
        "header": [{ "key": "Content-Type", "value": "application/json" }],
        "body": { "mode": "raw", "raw": "{\"code\": \"invalid-secret\", \"location\": \"door-1\"}" },
        "url": { "raw": "{{baseUrl}}/api/tickets/scan", "host": ["{{baseUrl}}"], "path": ["api","tickets","scan"] }
      }
    }
  ]
}

```


<a id="file-docs-ticket-scanning-documentation-index-md"></a>

<a id="file-docs-ticket-scanning-api-guide-md"></a>
## Ticket Scanning API Guide

# Ticket Scanning API - Complete Integration Guide for iOS Team

## Overview
The ticket scanning API allows iOS apps to scan QR codes and mark tickets as used. The API works exactly like the web-based ticket scanning:
- Ticket MUST be for today's date
- Ticket MUST be paid (not unpaid, cancelled, or refunded)
- User must be authorized to manage the event

When these requirements are met, the ticket is marked as used and the full sale details are returned.

---

## Authentication

**Required Header:** `X-API-Key`

All API requests must include an `X-API-Key` header with a valid API key.

```
X-API-Key: your-api-key-here
```

**How to get API Key:**
- API keys are generated per user in the system
- Contact the backend team or admin to generate/retrieve your API key
- Store it securely in your app (e.g., Keychain on iOS)

**Rate Limiting:**
- 60 requests per minute per IP address
- 10 failed authentication attempts trigger 15-minute block
- Add 250ms delay between failed attempts

---

## Primary Endpoint: Scan by Ticket Code

### Endpoint: `POST /api/tickets/scan`

This is the main endpoint for iOS scanning. It accepts the ticket code from a QR code and performs the scan.

### URL
```
POST https://your-domain.com/api/tickets/scan
```

### Validation Requirements

Before a ticket can be scanned, it must meet ALL of these requirements:

| Requirement | Status | Error Code | Error Message |
|-------------|--------|-----------|--------------|
| Ticket code must exist | Required | 404 | "Ticket not found" |
| Ticket must not be deleted | Required | 404 | "Ticket not found" |
| User must manage event | Required | 403 | "You are not authorized to scan this ticket" |
| **Ticket must be TODAY's date** | **Required** | **400** | **"This ticket is not valid for today"** |
| **Ticket status must be "paid"** | **Required** | **400** | **"This ticket is not paid"** / "This ticket is cancelled" / "This ticket is refunded" |

**Important:** The date and payment status checks are critical for event security. Tickets can only be scanned on the day of the event and only if payment has been completed.

### Headers
```
X-API-Key: your-api-key-here
Content-Type: application/json
```

### Request Body

**Required:**
```json
{
  "ticket_code": "wk8wfyzjrbrdv5rxvjxjzpx9ggum6uxl"
}
```

**Optional:**
```json
{
  "ticket_code": "wk8wfyzjrbrdv5rxvjxjzpx9ggum6uxl",
  "sale_ticket_id": 789,
  "seat_number": "A12"
}
```

**Parameters:**
- `ticket_code` (required, string): The code extracted from the QR code. This is the unique identifier for the ticket sale.
- `sale_ticket_id` (optional, integer): Specific ticket to scan within the sale. If omitted, the first ticket is scanned.
- `seat_number` (optional, string, max 255): Seat or location information for the ticket entry.

### Success Response (201 Created)

```json
{
  "data": {
    "sale_id": 123,
    "entry_id": 1001,
    "scanned_at": "2025-12-17T14:30:00.000000Z",
    "sale": {
      "id": 123,
      "status": "paid",
      "name": "John Doe",
      "email": "john@example.com",
      "event_id": 456,
      "event": {
        "id": 456,
        "name": "Concert 2025",
        "starts_at": "2025-12-20T19:00:00Z",
        "ends_at": "2025-12-20T22:00:00Z"
      },
      "tickets": [
        {
          "id": 789,
          "ticket_id": 101,
          "quantity": 2,
          "usage_status": "used"
        }
      ]
    }
  }
}
```

**Response Fields:**
- `sale_id`: The ID of the ticket sale
- `entry_id`: The ID of the scanned entry (useful for tracking individual scans)
- `scanned_at`: ISO 8601 timestamp of when the scan occurred
- `sale.status`: Payment status - can be `paid`, `unpaid`, `cancelled`, `refunded`, `expired`, `deleted`
- `sale.tickets`: Array of tickets in this sale with `usage_status` of `used` or `unused`

---

## Error Responses

### 400 Bad Request
Invalid request format, missing required fields, or validation failure.

**Missing field:**
```json
{
  "error": "The ticket code field is required."
}
```

**Ticket not for today:**
```json
{
  "error": "This ticket is not valid for today"
}
```

**Ticket not paid:**
```json
{
  "error": "This ticket is not paid"
}
```

**Ticket cancelled:**
```json
{
  "error": "This ticket is cancelled"
}
```

**Ticket refunded:**
```json
{
  "error": "This ticket is refunded"
}
```

### 401 Unauthorized
Missing or invalid API key.
```json
{
  "error": "API key is required"
}
```
or
```json
{
  "error": "Invalid API key"
}
```

### 403 Forbidden
The authenticated user does not manage the event for this ticket.
```json
{
  "error": "Unauthorized"
}
```

### 404 Not Found
The ticket code was not found or has been deleted.
```json
{
  "error": "Ticket not found"
}
```

Special cases:
```json
{
  "error": "Sale ticket not found"
}
```
```json
{
  "error": "No tickets found in this sale"
}
```

### 423 Locked
API key has been temporarily blocked due to too many failed attempts.
```json
{
  "error": "API key temporarily blocked"
}
```

### 429 Too Many Requests
Rate limit exceeded (60 requests per minute).
```json
{
  "error": "Rate limit exceeded"
}
```

---

## Common Issues & Troubleshooting

### Issue: "Ticket not found" (404)

**Causes:**
1. **Ticket code doesn't exist**: The code extracted from the QR was wrong
2. **Ticket was deleted**: The sale has been soft-deleted
3. **Wrong environment**: QR code is from production but you're hitting staging API (or vice versa)
4. **Code formatting**: The QR code value includes extra whitespace or special characters

**Solutions:**
- Verify the extracted code matches exactly (case-sensitive)
- Check that you're using the correct API base URL
- Trim whitespace: `code = code.trimmingCharacters(in: .whitespacesAndNewlines)`
- Test with a known valid ticket code in your test environment

### Issue: "This ticket is not valid for today" (400)

**Cause:**
The ticket is for a different date than today.

**Why:**
For security and audit purposes, tickets can only be scanned on the day of the event. This prevents accidental scanning of tickets for other dates.

**Solutions:**
- Verify the device date/time is correct
- Only scan tickets on their event date
- Check the sale's `event_date` field to see when the event is scheduled

### Issue: "This ticket is not paid" (400)

**Cause:**
The ticket sale is in unpaid status.

**Why:**
Only paid tickets should be scanned at events. Unpaid tickets haven't completed payment and shouldn't grant entry.

**Solutions:**
- Collect payment before scanning
- Use the dashboard to mark the sale as paid if payment was received offline
- Check the sale status in the admin panel

### Issue: "This ticket is cancelled" or "This ticket is refunded" (400)

**Cause:**
The ticket has been cancelled or refunded.

**Why:**
Cancelled or refunded tickets are no longer valid and should not be scanned.

**Solutions:**
- Verify the correct ticket code was scanned
- Check with the attendee about the ticket status
- Review the ticket in the admin dashboard

### Issue: "You are not authorized to scan this ticket" (403)

**Cause:**
The authenticated user (via API key) doesn't have permission to scan tickets for this event.

**Why:**
Only event organizers and team members with scanning permissions can check in tickets.

**Solutions:**
- Verify the API key belongs to the correct event organizer/team member
- Ensure the user hasn't been removed from the event
- Check user permissions in the admin panel

### Issue: "Invalid API key" (401)

**Causes:**
1. API key is missing from the request
2. API key is incorrect
3. API key doesn't exist in the system

**Solutions:**
- Ensure `X-API-Key` header is included in every request
- Double-check the API key value (copy-paste carefully, watch for leading/trailing spaces)
- Request a new API key from the system admin if the current one is lost

### Issue: "Rate limit exceeded" (429)

**Causes:**
1. More than 60 requests per minute from your IP address

**Solutions:**
- Implement exponential backoff retry logic
- Cache results when possible to reduce API calls
- Spread requests over time instead of rapid-fire

---

## Example Implementation (Swift/iOS)

```swift
import Foundation

class TicketScanService {
    let baseURL = "https://your-domain.com/api"
    let apiKey = "your-api-key-here"
    
    func scanTicket(code: String, saleTicketId: Int? = nil, seatNumber: String? = nil, completion: @escaping (Result<TicketScanResponse, Error>) -> Void) {
        var urlComponent = URLComponents(string: "\(baseURL)/tickets/scan")!
        let url = urlComponent.url!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = ["ticket_code": code]
        if let saleTicketId = saleTicketId {
            body["sale_ticket_id"] = saleTicketId
        }
        if let seatNumber = seatNumber {
            body["seat_number"] = seatNumber
        }
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "TicketScan", code: -1, userInfo: nil)))
                return
            }
            
            do {
                let response = try JSONDecoder().decode(TicketScanResponse.self, from: data)
                completion(.success(response))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}

struct TicketScanResponse: Codable {
    struct Data: Codable {
        let sale_id: Int
        let entry_id: Int
        let scanned_at: String
        let sale: SaleData
    }
    
    struct SaleData: Codable {
        let id: Int
        let status: String
        let name: String
        let email: String
        let event_id: Int
        let event: EventData
        let tickets: [TicketData]
    }
    
    struct EventData: Codable {
        let id: Int
        let name: String
        let starts_at: String
        let ends_at: String?
    }
    
    struct TicketData: Codable {
        let id: Int
        let ticket_id: Int
        let quantity: Int
        let usage_status: String  // "used" or "unused"
    }
    
    let data: Data
}
```

**Usage:**
```swift
let service = TicketScanService()
service.scanTicket(code: "wk8wfyzjrbrdv5rxvjxjzpx9ggum6uxl") { result in
    switch result {
    case .success(let response):
        print("Ticket scanned successfully!")
        print("Buyer: \(response.data.sale.name)")
        print("Tickets: \(response.data.sale.tickets)")
    case .failure(let error):
        print("Scan failed: \(error)")
    }
}
```

---

## QR Code Format

The QR codes embedded in tickets contain the ticket secret code in plain text.

**Example QR code value:**
```
wk8wfyzjrbrdv5rxvjxjzpx9ggum6uxl
```

**When scanning:**
1. Extract the raw string from the QR code
2. Trim any whitespace: `code.trimmingCharacters(in: .whitespacesAndNewlines)`
3. Pass directly to `ticket_code` parameter in the API

---

## Alternative Endpoint: Scan by Sale ID

If you have the sale ID available, you can use this endpoint:

### Endpoint: `POST /api/tickets/{sale_id}/scan`

**URL:**
```
POST https://your-domain.com/api/tickets/123/scan
```

**Headers:**
```
X-API-Key: your-api-key-here
Content-Type: application/json
```

**Request Body:**
```json
{
  "sale_ticket_id": 789,
  "seat_number": "A12"
}
```

**Response (201 Created):**
```json
{
  "data": {
    "entry_id": 1001,
    "scanned_at": "2025-12-17T14:30:00.000000Z"
  }
}
```

**Note:** This endpoint requires the sale ID in the URL, which you may not have directly from a QR code. Use the primary endpoint (`POST /api/tickets/scan`) instead.

---

## Best Practices

1. **Understand ticket validation requirements**
   - Ticket must be for TODAY's date (your device date/time must be correct)
   - Ticket must be PAID status
   - Your API key must belong to the event organizer/team member
   - A single ticket can only be scanned once per day

2. **Always validate ticket_code before sending**
   - Trim whitespace: `code.trimmingCharacters(in: .whitespacesAndNewlines)`
   - Check for minimum length (usually 32+ characters)
   - Handle QR decode errors gracefully

3. **Implement retry logic with exponential backoff**
   - Network errors can happen; retry with delays
   - Don't retry on 400/401/403 (validation/auth errors)
   - Do retry on 429, 5xx, and network errors

4. **Cache user/event data locally**
   - Reduce API calls by storing event info locally
   - Sync when you have good connectivity
   - Allow offline mode when reasonable

5. **Log scanning activity**
   - Track successful scans with timestamps
   - Log errors for debugging
   - Report to backend for audit trail

6. **Provide user feedback**
   - Show success confirmation immediately
   - Display buyer name and ticket count
   - Show error details (unpaid, wrong date, already scanned, etc.)
   - Provide helpful error messages for non-technical staff

7. **Handle error responses properly**
   ```swift
   if let httpResponse = response as? HTTPURLResponse {
       switch httpResponse.statusCode {
       case 201:
           // Success - process response
           break
       case 401, 403:
           // Auth error - check API key
           break
       case 404:
           // Ticket not found - maybe it's invalid or deleted
           break
       case 429:
           // Rate limited - back off and retry
           break
       default:
           // Other error
           break
       }
   }
   ```

---

## Support & Questions

If you encounter any issues:

1. **Check the error message carefully** - it usually indicates the problem
2. **Verify API key and authentication**
3. **Confirm ticket codes are being extracted correctly**
4. **Test with a known good ticket code**
5. **Contact the backend team** with:
   - The exact error message and HTTP status code
   - The ticket code you're trying to scan
   - Timestamp of the attempt
   - Your API key (if safe to share in secure channel)

---

## API Response Field Reference

| Field | Type | Example | Description |
|-------|------|---------|-------------|
| sale_id | integer | 123 | Unique ID of the ticket sale |
| entry_id | integer | 1001 | Unique ID of the scanned entry (for audit) |
| scanned_at | string (ISO 8601) | 2025-12-17T14:30:00Z | Timestamp when ticket was scanned |
| status | string | "paid" | Payment status: paid, unpaid, cancelled, refunded, expired, deleted |
| name | string | "John Doe" | Buyer name |
| email | string | "john@example.com" | Buyer email |
| event_id | integer | 456 | Event ID |
| event.id | integer | 456 | Event ID (repeated) |
| event.name | string | "Concert 2025" | Event name |
| event.starts_at | string (ISO 8601) | 2025-12-20T19:00:00Z | Event start time |
| event.ends_at | string (ISO 8601) | 2025-12-20T22:00:00Z | Event end time (nullable) |
| tickets[].id | integer | 789 | Sale ticket ID |
| tickets[].ticket_id | integer | 101 | Ticket type ID |
| tickets[].quantity | integer | 2 | Number of tickets in this sale |
| tickets[].usage_status | string | "used" | "used" or "unused" |

---

## Version History

- **v2.0** (2025-12-17): Updated to match web-based scanning with date validation and payment status checks
- **v1.0** (2025-12-17): Initial release with ticket scanning by code and ID endpoints



<a id="file-docs-authorization-md"></a>

<a id="file-docs-ticket-scanning-quick-reference-md"></a>
## Ticket Scanning Quick Reference

# Quick Reference: Ticket Scanning API for iOS Team

## Endpoint
```
POST https://your-domain.com/api/tickets/scan
```

## Authentication
```
Header: X-API-Key: your-api-key-here
```

## Request
```json
{
  "ticket_code": "extract-from-qr-code-string",
  "seat_number": "optional-A12-format"
}
```

## Success Response (201 Created)
```json
{
  "data": {
    "sale_id": 123,
    "entry_id": 1001,
    "scanned_at": "2025-12-17T14:30:00Z",
    "sale": {
      "id": 123,
      "status": "paid",
      "name": "John Doe",
      "email": "john@example.com",
      "event": {
        "id": 456,
        "name": "Event Name",
        "starts_at": "2025-12-20T19:00:00Z"
      },
      "tickets": [
        {
          "id": 789,
          "ticket_id": 101,
          "quantity": 2,
          "usage_status": "used"
        }
      ]
    }
  }
}
```

## Validation Requirements (MUST ALL PASS)

✅ **Ticket code must exist** → (404 if not)
✅ **User must manage event** → (403 if not)
✅ **Ticket must be TODAY** → (400 if not)
✅ **Ticket must be PAID** → (400 if not)

## Common Error Responses

| Status | Error | Cause |
|--------|-------|-------|
| 400 | "This ticket is not valid for today" | Event date ≠ today |
| 400 | "This ticket is not paid" | Status is unpaid |
| 400 | "This ticket is cancelled" | Status is cancelled |
| 400 | "This ticket is refunded" | Status is refunded |
| 403 | "You are not authorized to scan this ticket" | User doesn't manage event |
| 404 | "Ticket not found" | Invalid code or deleted |

## Swift Implementation

```swift
import Foundation

class TicketScanner {
    let baseURL = "https://your-domain.com/api"
    let apiKey = "your-api-key"
    
    func scan(_ qrCode: String, completion: @escaping (Result<ScanResponse, Error>) -> Void) {
        var request = URLRequest(url: URL(string: "\(baseURL)/tickets/scan")!)
        request.httpMethod = "POST"
        request.addValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["ticket_code": qrCode.trimmingCharacters(in: .whitespacesAndNewlines)]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                completion(.failure(error ?? NSError(domain: "", code: -1)))
                return
            }
            
            do {
                let response = try JSONDecoder().decode(ScanResponse.self, from: data)
                completion(.success(response))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}

struct ScanResponse: Codable {
    struct Data: Codable {
        let sale_id: Int
        let entry_id: Int
        let scanned_at: String
        let sale: SaleData
    }
    
    struct SaleData: Codable {
        let name: String
        let status: String
        let event: EventData
        let tickets: [TicketData]
    }
    
    struct EventData: Codable {
        let name: String
        let starts_at: String
    }
    
    struct TicketData: Codable {
        let quantity: Int
        let usage_status: String
    }
    
    let data: Data
}
```

## Error Handling Pattern

```swift
scanner.scan(qrCode) { result in
    switch result {
    case .success(let response):
        // Show success: "John Doe - 2 tickets marked used"
        print("Buyer: \(response.data.sale.name)")
        print("Tickets: \(response.data.sale.tickets.count)")
        
    case .failure(let error):
        if let decodingError = error as? DecodingError {
            // Parse JSON error response to get message
            if let data = try? JSONDecoder().decode(ErrorResponse.self, from: originalData) {
                print("Scan failed: \(data.error)")
            }
        } else {
            print("Network error: \(error.localizedDescription)")
        }
    }
}

struct ErrorResponse: Codable {
    let error: String
}
```

## Important Reminders

1. **Always trim QR code** before sending:
   ```swift
   let code = qrCode.trimmingCharacters(in: .whitespacesAndNewlines)
   ```

2. **Check device date/time** - Tickets can only scan on their event date

3. **Check API key** in every request header - it's required

4. **Don't retry 400/401/403** errors - they're validation failures, not temporary issues

5. **Implement exponential backoff** for 429/5xx errors

## Testing

Test with these scenarios:
- ✅ Valid ticket for today → Should scan
- ❌ Ticket for tomorrow → "This ticket is not valid for today"
- ❌ Unpaid ticket → "This ticket is not paid"
- ❌ Invalid code → "Ticket not found"

## Documentation

- Full guide: `docs/TICKET_SCANNING_API_GUIDE.md`
- Parity summary: `docs/API_SCANNING_PARITY_SUMMARY.md`

## Contact

Issues with scanning? Provide:
1. The exact error message returned by the API
2. The ticket code (if safe to share)
3. Timestamp of attempt
4. Event details (date, payment status visible in dashboard)



<a id="file-docs-ticket-actions-test-guide-md"></a>

<a id="file-docs-ticket-actions-quick-ref-md"></a>
## Ticket Actions Quick Reference

# Ticket Status Actions - Quick Reference

## Endpoint
```
PATCH /api/tickets/{sale_id}
```

## All 7 Actions

### 1. Mark Paid
```json
{
  "action": "mark_paid"
}
```
**Valid when:** status = `unpaid`  
**Result:** status = `paid`

---

### 2. Mark Unpaid
```json
{
  "action": "mark_unpaid"
}
```
**Valid when:** status = `paid` OR `cancelled`  
**Result:** status = `unpaid`

---

### 3. Refund
```json
{
  "action": "refund"
}
```
**Valid when:** status = `paid`  
**Result:** status = `refunded`

---

### 4. Cancel
```json
{
  "action": "cancel"
}
```
**Valid when:** status = `unpaid` OR `paid`  
**Result:** status = `cancelled`

---

### 5. Delete (Soft Delete)
```json
{
  "action": "delete"
}
```
**Valid when:** any status  
**Result:** `is_deleted` flag set to true

---

### 6. Mark Used
```json
{
  "action": "mark_used"
}
```
**Valid when:** entries have `scanned_at = NULL`  
**Result:** All null `scanned_at` values set to current timestamp

---

### 7. Mark Unused
```json
{
  "action": "mark_unused"
}
```
**Valid when:** entries have `scanned_at != NULL`  
**Result:** All `scanned_at` values cleared (set to NULL)

---

## Optional Parameters

You can also update holder info:

```json
{
  "action": "mark_paid",
  "name": "Updated Name",
  "email": "newemail@example.com"
}
```

---

## State Machine Quick View

```
unpaid → mark_paid → paid
  ↓                    ↓
cancel → cancelled    refund → refunded
           ↓            ↓
           mark_unpaid
                ↑
           (any status)
           
(any status) → delete → is_deleted = true

(any status) → mark_used/mark_unused → (entries only, status unchanged)
```

---

## Response Format

### Success (200 OK)
```json
{
  "data": {
    "id": 123,
    "status": "paid"
  }
}
```

### Invalid State Transition (200 OK, no change)
```json
{
  "data": {
    "id": 123,
    "status": "paid"  // unchanged because action wasn't valid for this status
  }
}
```

### Validation Error (422)
```json
{
  "message": "The given data was invalid.",
  "errors": {
    "action": ["The selected action is invalid."]
  }
}
```

### Not Authorized (403)
```json
{
  "error": "Unauthorized"
}
```

---

## Example Requests

### Mark a paid ticket as cancelled
```bash
curl -X PATCH https://api.planify.app/api/tickets/42 \
  -H "X-API-Key: abc123def456" \
  -H "Content-Type: application/json" \
  -d '{
    "action": "cancel"
  }'
```

### Refund a paid ticket and update holder email
```bash
curl -X PATCH https://api.planify.app/api/tickets/42 \
  -H "X-API-Key: abc123def456" \
  -H "Content-Type: application/json" \
  -d '{
    "action": "refund",
    "email": "refund@customer.com"
  }'
```

### Mark all ticket entries as used (checked in)
```bash
curl -X PATCH https://api.planify.app/api/tickets/42 \
  -H "X-API-Key: abc123def456" \
  -H "Content-Type: application/json" \
  -d '{
    "action": "mark_used"
  }'
```

---

## Status Values

- `pending` - Awaiting payment
- `unpaid` - Not yet paid (manual entry)
- `paid` - Payment received
- `refunded` - Payment refunded
- `cancelled` - Cancelled by user
- `expired` - Past event date without payment

---

## Common Workflows

### Workflow 1: Approve Pending Payment
1. Create sale with status `pending`
2. Customer pays via Stripe (auto-sets to `paid`)
3. If manual approval needed: `mark_paid` action

### Workflow 2: Process Refund
1. Sale has status `paid`
2. Call `refund` action
3. Status becomes `refunded`
4. (You handle actual payment refund separately)

### Workflow 3: Cancel Order
1. Sale has status `unpaid` or `paid`
2. Call `cancel` action
3. Status becomes `cancelled`
4. If paid, follow with `refund` action if needed

### Workflow 4: Check In at Event
1. Sale has tickets with entries
2. Call `mark_used` action for entire sale
3. OR call scan endpoint for individual entries

---

## Debugging

**Status not changing?**
- Verify current status is valid for action
- Check API response - does it show correct status?
- Check database directly: `SELECT status FROM sales WHERE id = ?`
- Ensure you have `resources.manage` ability

**Getting validation error?**
- Check action name spelling (case-sensitive)
- Verify JSON format
- Check Content-Type header is `application/json`

**Getting 403 error?**
- Verify API key is valid
- Verify you own this ticket
- Verify user has `resources.manage` ability

---

## Migration from Old API

If you were using a different ticket status endpoint before, these are the action names:

| Old | New |
|-----|-----|
| `pay` | `mark_paid` |
| N/A | `mark_unpaid` |
| `refund` | `refund` |
| `void` | `cancel` |
| `delete` | `delete` |
| `scan` | `mark_used` |
| N/A | `mark_unused` |

---

**Updated:** December 16, 2025  
**API Version:** 2.0.0




<a id="file-docs-mobile-events-update-notes-md"></a>

<a id="file-docs-mobile-events-api-guide-md"></a>
## Mobile Events API Guide

# Mobile app guide: interacting with Events Schedule via API

This guide explains how a mobile client can integrate with the Planify REST API to list schedules, fetch events, create events, and manage flyers. It summarizes authentication, rate limiting, request/response shapes, and edge cases surfaced by the API controllers.

## 1) Authentication and headers

- Generate an API key from **Settings → Integrations & API**; enabling the API creates a 32-character key and disabling it clears the key. 【F:app/Http/Controllers/Api/ApiSettingsController.php†L11-L36】
- Send the key on every request using the `X-API-Key` header. All endpoints also expect JSON unless you are uploading multipart form data.

```http
X-API-Key: <your-api-key>
Accept: application/json
Content-Type: application/json
```

### Rate limits and abuse controls
- 60 requests per minute per client IP; exceeding this returns HTTP 429 with `{"error":"Rate limit exceeded"}`. 【F:app/Http/Middleware/ApiAuthentication.php†L23-L59】
- Ten consecutive invalid key attempts block the key for 15 minutes (HTTP 423 with `API key temporarily blocked`). 【F:app/Http/Middleware/ApiAuthentication.php†L32-L59】
- Missing or invalid keys return HTTP 401 with an `error` message. 【F:app/Http/Middleware/ApiAuthentication.php†L15-L52】

## 2) Available endpoints

All API routes are namespaced under `/api` and require authentication via the middleware above. 【F:routes/api.php†L9-L17】

### Roles: venues, curators, and talent

#### GET `/api/roles`
Lists the authenticated user's roles filtered to `venue`, `curator`, and `talent` types.

Query parameters:
- `per_page` — max 1000, default 100. 【F:app/Http/Controllers/Api/ApiRoleController.php†L13-L24】
- `type` — optional filter; accepts a comma-separated list or array of `venue`, `curator`, `talent`. 【F:app/Http/Controllers/Api/ApiRoleController.php†L22-L34】
- `name` — optional substring match on the role name. 【F:app/Http/Controllers/Api/ApiRoleController.php†L36-L38】

Response payload mirrors other paginated resources and returns each role's encoded ID, contact info, address (for venues), background colors, and group metadata via `toApiData()`. 【F:app/Http/Controllers/Api/ApiRoleController.php†L40-L53】【F:app/Models/Role.php†L667-L714】

#### POST `/api/roles`
Creates a new role for use as a venue, curator, or talent. The authenticated user is made the owner of the role and the record is added to their resource scope. 【F:app/Http/Controllers/Api/ApiRoleController.php†L71-L131】

Required fields:
- `type` — one of `venue`, `curator`, or `talent`.
- `name` — up to 255 characters.
- `email` — valid email up to 255 characters. 【F:app/Http/Controllers/Api/ApiRoleController.php†L72-L95】
- `address1` — required only when `type` is `venue`. 【F:app/Http/Controllers/Api/ApiRoleController.php†L88-L95】

Optional fields and behaviors:
- `contacts` — array of contact objects (`name`, `email`, `phone`), stored verbatim if provided. 【F:app/Http/Controllers/Api/ApiRoleController.php†L82-L112】
- `groups` — array of group names; the API creates slugged groups under the role. 【F:app/Http/Controllers/Api/ApiRoleController.php†L96-L114】
- `website`, `timezone`, `language_code`, `country_code`, `address2`, `city`, `state`, `postal_code` — stored on the role when present. 【F:app/Http/Controllers/Api/ApiRoleController.php†L72-L95】
- Styling defaults are applied when no colors are supplied: a random gradient background, random rotation, and white font color. 【F:app/Http/Controllers/Api/ApiRoleController.php†L119-L124】
- Hosted deployments set a one-year `plan_expires` and pro plan defaults; self-hosted instances mark the email as verified immediately. 【F:app/Http/Controllers/Api/ApiRoleController.php†L102-L118】

Successful creation returns **201** with the new role plus any created groups in `data` and a `meta.message` success string. 【F:app/Http/Controllers/Api/ApiRoleController.php†L126-L131】

#### DELETE `/api/roles/{role_id}`
Removes a venue, curator, or talent the user owns. The backend rejects unsupported role types, and deleting a talent cascades removal of any events where that talent is the only member. Ownership is enforced; otherwise the response is 403. 【F:routes/api.php†L15-L18】【F:app/Http/Controllers/Api/ApiRoleController.php†L136-L165】

#### DELETE `/api/roles/{role_id}/contacts/{contact}`
Removes a single contact by its zero-based index and returns the updated role payload. 404 is returned when the index is missing, and ownership is required. 【F:routes/api.php†L15-L18】【F:app/Http/Controllers/Api/ApiRoleController.php†L167-L192】

### GET `/api/schedules`
Returns paginated schedules (venues, talents, curators, etc.) owned by the authenticated user.

Query parameters:
- `per_page` — max 1000, default 100. 【F:app/Http/Controllers/Api/ApiScheduleController.php†L10-L24】
- `name` — optional substring match on schedule name. 【F:app/Http/Controllers/Api/ApiScheduleController.php†L18-L23】
- `type` — optional filter by schedule type (e.g., `venue`, `talent`). 【F:app/Http/Controllers/Api/ApiScheduleController.php†L18-L23】

Response payload includes `data` (array of schedules) and `meta` pagination details. Schedule objects expose IDs, URLs, time zone, contact info, and group metadata. 【F:app/Http/Controllers/Api/ApiScheduleController.php†L10-L37】【F:app/Models/Role.php†L667-L714】

### GET `/api/events`
Returns all events owned by the authenticated user with pagination.

Query parameters:
- `per_page` — max 1000, default 100. 【F:app/Http/Controllers/Api/ApiEventController.php†L19-L67】

Each event object contains:
- Identity and timing: encoded `id`, `slug`, `name`, `description` (Markdown and HTML), `starts_at`, `duration`, and event `timezone` (from the primary schedule). 【F:app/Models/Event.php†L808-L834】
- Location and schedules: `venue_id`, embedded `venue` object, and `schedules` showing all linked roles plus pivot data for group assignment and acceptance. 【F:app/Models/Event.php†L824-L873】
- Participants: `members` keyed by encoded talent IDs with names/emails/YouTube URLs. 【F:app/Models/Event.php†L843-L849】
- Tickets: `tickets_enabled`, currency/mode, ticket notes (plain and HTML), and ticket objects including price, quantity, and sold breakdowns. 【F:app/Models/Event.php†L826-L860】
- Links and media: guest `url`, `registration_url`, `event_url`, `payment_method`, `payment_instructions` (plain and HTML), `flyer_image_url`, and `category` summary. 【F:app/Models/Event.php†L815-L839】【F:app/Models/Event.php†L832-L836】
- Curator metadata: `curator_role` populated when the creator is a curator. 【F:app/Models/Event.php†L875-L876】

### GET `/api/events/resources`
Returns the user's venues, curators, and talent pre-grouped for building event creation screens. Each item is serialized through `toApiData()`, matching the `/api/roles` responses. 【F:app/Http/Controllers/Api/ApiEventController.php†L26-L45】

Payload format:
- `data.venues` — array of venue roles.
- `data.curators` — array of curator roles.
- `data.talent` — array of talent roles.
- `meta.total_roles` — count of roles returned; `meta.path` echoes the requested URL. 【F:app/Http/Controllers/Api/ApiEventController.php†L26-L45】

### POST `/api/events/{subdomain}`
Creates a new event attached to the schedule identified by `{subdomain}`. The subdomain can be a venue, talent, or curator; the API automatically populates related fields based on the schedule type. **Do not** POST to `/api/events` without a subdomain, as that route is read-only and will return HTTP 405. 【F:app/Http/Controllers/Api/ApiEventController.php†L70-L213】【F:routes/api.php†L14-L20】

Required inputs:
- `name` (string, ≤255) and `starts_at` (`Y-m-d H:i:s`). Backend parsing treats this as the creator's local wall time, not an ISO8601 instant, so mobile clients should format the field in the current timezone rather than forcing UTC. 【F:app/Http/Controllers/Api/ApiEventController.php†L85-L95】【F:app/Repos/EventRepo.php†L237-L243】
- One of `venue_id`, `venue_address1`, or `event_url`. 【F:app/Http/Controllers/Api/ApiEventController.php†L85-L95】

Key behaviors and optional fields:
- If the subdomain is a venue, `venue_id` is auto-assigned. If it is a talent, that talent is auto-added to `members`; if it is a curator, the curator is added to `curators`. 【F:app/Http/Controllers/Api/ApiEventController.php†L72-L213】
- `members` array accepts talents; known talents belonging to the user are resolved to encoded IDs, while unknown entries are kept as-provided. 【F:app/Http/Controllers/Api/ApiEventController.php†L158-L207】
- Provide `schedule` to target a specific group slug within the schedule; the API resolves it to `current_role_group_id` or returns 422 if not found. 【F:app/Http/Controllers/Api/ApiEventController.php†L97-L107】
- Categories can be passed as `category_id` or human-friendly `category_name`; the latter is slug-matched against configured event types and fallbacks, otherwise returns 422. 【F:app/Http/Controllers/Api/ApiEventController.php†L108-L156】
- Venues can be linked by address/name if the user owns a matching venue; the API encodes the venue ID automatically. 【F:app/Http/Controllers/Api/ApiEventController.php†L162-L176】

Responses:
- **201** with `data` containing the full event payload plus `meta.message` when creation succeeds. 【F:app/Http/Controllers/Api/ApiEventController.php†L215-L220】
- **403** if the authenticated user is not a member of the targeted subdomain. 【F:app/Http/Controllers/Api/ApiEventController.php†L81-L83】
- **422** for validation errors (missing venue info, invalid schedule/group, unknown category, etc.). 【F:app/Http/Controllers/Api/ApiEventController.php†L97-L155】
- **405** if you POST to `/api/events` without a subdomain. Ensure your client resolves the correct schedule subdomain (e.g., the currently selected venue or curator) before issuing the request.

How to choose `{subdomain}` and build the request:
- Call `GET /api/schedules` and read the `subdomain` field from the schedule you want to own the event (e.g., `sample-venue`). 【F:app/Http/Controllers/Api/ApiScheduleController.php†L10-L37】
- Append that value to the path when posting (e.g., `/api/events/sample-venue`). The backend uses it to infer defaults (venue assignment, curator membership, or talent membership). 【F:routes/api.php†L14-L20】【F:app/Http/Controllers/Api/ApiEventController.php†L72-L213】
- Provide the schedule's encoded `id` in `venue_id` if you want to be explicit about the venue, even when posting to a venue subdomain.

Minimal example request:

```bash
curl -X POST https://planify.test/api/events/sample-venue \
  -H "X-API-Key: <your-api-key>" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Mobile-created show",
    "starts_at": "2024-04-15 19:30:00",
    "venue_id": "Uk9MRS0z",
    "category_name": "Concert",
    "members": [{"name": "Guest Performer"}]
  }'
```

### PATCH `/api/events/{event_id}`
Updates an event the authenticated user owns. The route uses the same validation rules as creation but treats most fields as optional so clients can send partial payloads. Existing venue/members/curators are preserved when those arrays are omitted, and when you do send `members` or `curators` the backend merges them with the current set so you can add or edit talent/curators without resending the entire list. Providing a different `venue_id` or venue address will move the event to the new venue or update the existing unclaimed venue record. 【F:routes/api.php†L16-L22】【F:app/Http/Controllers/Api/ApiEventController.php†L231-L316】

Key points:
- Ownership is required; otherwise the endpoint returns 403. 【F:app/Http/Controllers/Api/ApiEventController.php†L231-L242】
- `name` and `starts_at` become required only when provided; date format stays `Y-m-d H:i:s`. Venue/address/url fields still share the required-without-all rule when any are supplied. 【F:app/Http/Controllers/Api/ApiEventController.php†L244-L254】
- Sending `schedule` slugs maps them to `current_role_group_id`; invalid slugs return 422. Categories can be updated via `category_id` or `category_name` with the same slug-matching behavior as creation. 【F:app/Http/Controllers/Api/ApiEventController.php†L256-L299】
- When `members`, `venue_id`, or `curators` are omitted, the backend seeds the request with existing associations before saving to avoid unintended detachments. When supplied, the arrays are merged with the current lists so you can append or adjust participants and curators alongside venue edits. 【F:app/Http/Controllers/Api/ApiEventController.php†L281-L316】

Example minimal patch:

```bash
curl -X PATCH https://planify.test/api/events/RVZFTlQtMg== \
  -H "X-API-Key: <your-api-key>" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Updated title",
    "starts_at": "2024-05-01 20:00:00"
  }'
```

### DELETE `/api/events/{event_id}`
Deletes an event owned by the authenticated user. Returns a 200 response with a success message when the deletion succeeds, 403 when the requester does not own the event, and 404 for unknown IDs. 【F:routes/api.php†L20-L25】【F:app/Http/Controllers/Api/ApiEventController.php†L401-L415】

### POST `/api/events/flyer/{event_id}`
Uploads, replaces, or removes an event flyer. Requires ownership of the event. 【F:app/Http/Controllers/Api/ApiEventController.php†L223-L289】

Options:
- Provide `flyer_image_id` (JSON) to reuse/remove an existing upload. Validation ensures the ID exists. 【F:app/Http/Controllers/Api/ApiEventController.php†L231-L250】
- Upload `flyer_image` (multipart/form-data) to store a new flyer; the API deletes any previous file when replacing. 【F:app/Http/Controllers/Api/ApiEventController.php†L253-L282】

Responses:
- **200** with updated event payload and a success message on upload or removal. 【F:app/Http/Controllers/Api/ApiEventController.php†L284-L289】
- **403** if the event is not owned by the requester. 【F:app/Http/Controllers/Api/ApiEventController.php†L225-L229】
- **404** if the event ID is unknown; **422** for invalid flyer IDs.

## 3) Error handling summary

The API returns structured errors with meaningful HTTP status codes:

| Status | Reason | Example payload |
| ------ | ------ | ---------------- |
| 401 | Missing or invalid `X-API-Key` | `{ "error": "API key is required" }` or `{ "error": "Invalid API key" }` |
| 403 | Unauthorized for the requested resource | `{ "error": "Unauthorized" }` |
| 404 | Resource not found | `{ "message": "Not Found" }` |
| 422 | Validation failure | Laravel validation error bag (e.g., unknown schedule/category) |
| 423 | API key temporarily blocked after repeated failures | `{ "error": "API key temporarily blocked" }` |
| 429 | Rate limit exceeded | `{ "error": "Rate limit exceeded" }` |

## 4) Mobile integration tips

- Cache the `per_page` limit and pagination metadata so the app can page through schedules/events efficiently. The events endpoint defaults to 100 items but supports up to 1000. 【F:app/Http/Controllers/Api/ApiEventController.php†L19-L67】
- When creating events, prefer sending `category_name` and `schedule` slugs for readability; the backend resolves them to IDs and surfaces clear 422 errors if unmatched. 【F:app/Http/Controllers/Api/ApiEventController.php†L97-L156】
- Use the embedded `schedules`, `members`, and `venue` objects from GET `/api/events` responses to hydrate list and detail screens without extra calls. 【F:app/Models/Event.php†L824-L873】【F:app/Models/Event.php†L843-L860】
- For flyer uploads, detect whether you can reuse an `flyer_image_id` to avoid re-uploading large assets; otherwise send multipart form data. 【F:app/Http/Controllers/Api/ApiEventController.php†L231-L282】
- Handle 401/423/429 responses with UI prompts (refresh API key, wait before retrying) to stay within the built-in abuse protections. 【F:app/Http/Middleware/ApiAuthentication.php†L15-L59】




<a id="file-docs-mobile-event-requirements-md"></a>

<a id="file-docs-ios-team-setup-md"></a>
## iOS Team Setup

# iOS Team - Ticket Scanning API Complete Setup

## Status: ✅ Complete
The API now works **exactly** like the web-based ticket scanning with full validation parity.

---

## What Changed

The `POST /api/tickets/scan` endpoint now requires:
1. ✅ Ticket code exists
2. ✅ User manages the event  
3. ✅ **Ticket is for TODAY** (new requirement)
4. ✅ **Ticket status is PAID** (new requirement)

Previously, requirements #3 and #4 were missing, causing scan failures because the API was accepting unpaid/future-dated tickets that the web app would have rejected.

---

## Files Updated

### Backend
- **`app/Http/Controllers/Api/ApiTicketController.php`**
  - Added `Carbon` import for date comparison
  - Updated `scanByCode()` method with validation checks
  - Now matches web scanning behavior exactly

### Documentation (New Files)
- **`docs/TICKET_SCANNING_API_GUIDE.md`** (v2.0)
  - Complete guide with all error scenarios
  - Best practices and troubleshooting
  - Swift example code

- **`docs/API_SCANNING_PARITY_SUMMARY.md`** (New)
  - Technical summary of changes
  - Validation parity matrix
  - Testing checklist

- **`docs/TICKET_SCANNING_QUICK_REFERENCE.md`** (New)
  - One-page quick reference
  - Error codes and causes
  - Copy-paste Swift code

---

## For iOS Team: What to Do Now

### 1. Test the New Validation

Test these scenarios:
```
✅ Today's date + Paid status → Scan succeeds
❌ Tomorrow's date + Paid status → Error: "This ticket is not valid for today"
❌ Today's date + Unpaid status → Error: "This ticket is not paid"
❌ Invalid code → Error: "Ticket not found"
```

### 2. Ensure Device Date is Correct
The API checks if ticket's event_date matches today:
```
if (Carbon::parse($sale->event_date)->format('Y-m-d') !== now()->format('Y-m-d')) {
    return error: 'This ticket is not valid for today'
}
```

**Critical:** Test device's date/time is synced correctly.

### 3. Update Error Handling

You'll now receive:
- **400** for validation failures (date, payment status)
- **403** for authorization failures
- **404** for not found
- **401** for auth issues

Example error response:
```json
{
  "error": "This ticket is not valid for today"
}
```

### 4. Use the Updated Documentation

Share with your team:
1. **Quick Ref:** `docs/TICKET_SCANNING_QUICK_REFERENCE.md` (1 page)
2. **Full Guide:** `docs/TICKET_SCANNING_API_GUIDE.md` (complete reference)
3. **Summary:** `docs/API_SCANNING_PARITY_SUMMARY.md` (technical details)

---

## API Endpoint Reference

**Endpoint:** `POST /api/tickets/scan`

**Request:**
```json
{
  "ticket_code": "wk8wfyzjrbrdv5rxvjxjzpx9ggum6uxl"
}
```

**Success (201):**
```json
{
  "data": {
    "sale_id": 123,
    "entry_id": 1001,
    "scanned_at": "2025-12-17T14:30:00Z",
    "sale": {
      "name": "John Doe",
      "status": "paid",
      "tickets": [{"quantity": 2, "usage_status": "used"}]
    }
  }
}
```

**Errors:**
- 400: Validation failure (date/payment)
- 401: Invalid API key
- 403: Not authorized for event
- 404: Ticket not found

---

## Validation Flow Diagram

```
QR Code Scanned
     ↓
Extract Code → Trim Whitespace
     ↓
POST /api/tickets/scan + Code + API-Key
     ↓
[API Validation]
├─ Code exists? → NO → 404 "Ticket not found"
├─ User manages event? → NO → 403 "Not authorized"
├─ Event is today? → NO → 400 "Not valid for today"
└─ Status is paid? → NO → 400 "Not paid" / "Cancelled" / "Refunded"
     ↓
SUCCESS (201)
├─ Create scan entry
├─ Return sale details
└─ Update UI: "Scanned: John Doe - 2 tickets"
```

---

## Common Issues & Fixes

| Problem | Cause | Fix |
|---------|-------|-----|
| "This ticket is not valid for today" | Device date is wrong | Check device date/time settings |
| "This ticket is not paid" | Ticket unpaid | Collect payment first |
| "You are not authorized" | Wrong API key | Verify API key for correct account |
| "Ticket not found" | Bad QR code extract | Verify code trimming |

---

## Testing Checklist

Before going to production:

- [ ] Device date/time is correct
- [ ] API key is set correctly in app
- [ ] Trim whitespace from QR code: `code.trimmingCharacters(in: .whitespacesAndNewlines)`
- [ ] Test with paid ticket for today → succeeds
- [ ] Test with unpaid ticket for today → gets 400 error
- [ ] Test with paid ticket for tomorrow → gets 400 error
- [ ] Error messages display clearly to users
- [ ] Retry logic handles rate limits (429)
- [ ] No retry on 400/401/403 (validation errors)

---

## Deployment Notes

- Backend changes are in `ApiTicketController`
- Route is already defined: `Route::post('/tickets/scan', [ApiTicketController::class, 'scanByCode'])`
- No database migrations needed
- No configuration changes needed
- Compatible with existing API authentication

---

## Next Steps

1. **Pull the latest code** from the repository
2. **Run tests** with the validation checklist above
3. **Review the documentation** files provided
4. **Contact backend team** with any questions

---

## Support

If you encounter any issues:

1. Check the Quick Reference guide first
2. Verify ticket details in dashboard (date, payment)
3. Test with a known-good ticket code
4. Check device date/time is correct
5. Contact backend team with exact error message

---

**API Version:** 2.0  
**Last Updated:** 2025-12-17  
**Status:** ✅ Ready for iOS Integration
