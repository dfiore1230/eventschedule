# Mobile app authentication notes

The Event Schedule API does **not** accept username/password logins at `/api/session`. Mobile clients should authenticate every API call with an account API key instead.

## How onboarding works
- The app fetches instance metadata from `/.well-known/eventschedule.json`; the response advertises `apiBase` such as `https://events.fior.es/api`.
- Branding details are available at `/branding.json`.

## How to authenticate
- Generate an API key in the web UI under **Settings → Integrations & API**.
- Send that key on every request:
  ```http
  X-API-Key: <api-key>
  Accept: application/json
  Content-Type: application/json
  ```
- Do **not** POST to `/api/session`; that route only supports `GET` for session checks and will return HTTP 405 for POST requests.

## Error handling the client should expect
- `401 Unauthorized` for missing or invalid `X-API-Key`.
- `423 Locked` if the API key is temporarily blocked after repeated failures.
- `429 Too Many Requests` when IP-level rate limits are exceeded.

## Example flow to share with the mobile developer
1. Discover capabilities at `https://events.fior.es/.well-known/eventschedule.json`.
2. (Optional) Pull branding from `https://events.fior.es/branding.json`.
3. Call API endpoints (for example, `GET https://events.fior.es/api/schedules`) with the `X-API-Key` header instead of performing a login request.

For the complete REST API reference, including endpoints and sample responses, see [`docs/API_REFERENCE.md`](./API_REFERENCE.md).
