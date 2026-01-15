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
