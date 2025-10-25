# REST API Reference

Event Schedule exposes a JSON API that mirrors the web application's scheduling, booking, and media features. All endpoints are now available to every account tier – no Pro subscription required – while still enforcing authentication and per-user authorization.

## Authentication

Provide the API key that is generated from **Settings → Integrations & API** with every request.

```
X-API-Key: <your-api-key>
Accept: application/json
Content-Type: application/json
```

### Rate limits & throttling

* **Per IP:** 60 requests per minute (HTTP 429 when exceeded).
* **Brute-force protection:** After 10 failed API key attempts the key is blocked for 15 minutes (HTTP 423).
* **Missing or invalid key:** HTTP 401 with an `error` message.

Example error payloads:

```json
{
  "error": "API key is required"
}
```

```json
{
  "error": "Invalid API key"
}
```

## Schedules

### `GET /api/schedules`
Returns the authenticated user's venues, talents, curators, and other schedules.

#### Successful response (200)
```json
{
  "data": [
    {
      "id": "YmFzZTY0LWVuY29kZWQ=",
      "url": "https://eventschedule.test/sample-venue",
      "type": "venue",
      "subdomain": "sample-venue",
      "name": "Sample Venue",
      "timezone": "UTC",
      "groups": [
        {"id": "R1JPVVAtMQ==", "name": "Main Stage", "slug": "main-stage"}
      ],
      "contacts": [
        {"name": "Support", "email": "support@example.com", "phone": "+1234567890"}
      ]
    }
  ],
  "meta": {
    "current_page": 1,
    "per_page": 100,
    "total": 1,
    "path": "https://eventschedule.test/api/schedules"
  }
}
```

#### Failure scenarios
* **401** – Missing or invalid API key.
* **423** – API key temporarily blocked after repeated failures.
* **429** – IP-level rate limit exceeded.

## Events

### `GET /api/events`
Lists all events owned by the authenticated user, including ticketing, scheduling, and media metadata.

#### Successful response (200)
```json
{
  "data": [
    {
      "id": "RVZFTlQtMQ==",
      "name": "API Showcase",
      "slug": "api-showcase",
      "description": "Showcase description",
      "description_html": "<p>Showcase description</p>",
      "starts_at": "2024-01-01 20:00:00",
      "duration": 120,
      "timezone": "UTC",
      "tickets_enabled": true,
      "ticket_currency_code": "USD",
      "tickets": [
        {"id": "VElDS0VULTE=", "type": "General Admission", "price": 2500, "quantity": 100}
      ],
      "members": {
        "Uk9MRS0y": {"name": "Performer", "email": null, "youtube_url": null}
      },
      "schedules": [
        {"id": "Uk9MRS0y", "name": "Performer", "type": "talent"},
        {"id": "Uk9MRS0z", "name": "The Club", "type": "venue"}
      ],
      "venue": {
        "id": "Uk9MRS0z",
        "type": "venue",
        "name": "The Club",
        "address1": null,
        "city": null
      },
      "flyer_image_url": "https://eventschedule.test/storage/flyers/api-showcase.png",
      "registration_url": "https://events.example.com/register",
      "event_url": "https://events.example.com/stream",
      "payment_method": null,
      "payment_instructions": "Pay at the door",
      "ticket_notes": "Bring your ticket"
    }
  ],
  "meta": {
    "current_page": 1,
    "per_page": 100,
    "total": 1
  }
}
```

#### Failure scenarios
* **401 / 423 / 429** – Same authentication and throttling responses as `/api/schedules`.

### `POST /api/events/{subdomain}`
Creates a new event attached to the provided schedule (talent, venue, or curator subdomain).

#### Required fields
* `name` – string
* `starts_at` – `Y-m-d H:i:s`
* At least one of `venue_id`, `venue_address1`, or `event_url`

Optional fields include `members`, `schedule` (sub-schedule slug), `category`, ticketing fields, payment instructions, etc. Category names are resolved automatically when `category_name` is supplied.

#### Successful response (201)
```json
{
  "data": {
    "id": "RVZFTlQtMg==",
    "name": "API Created Event",
    "starts_at": "2024-03-15 19:00:00",
    "tickets_enabled": false,
    "members": {
      "Uk9MRS0y": {"name": "Performer", "email": null, "youtube_url": null}
    }
  },
  "meta": {
    "message": "Event created successfully"
  }
}
```

#### Failure scenarios
* **401** – Missing API key.
* **403** – Authenticated user does not belong to the targeted subdomain.
* **404** – Schedule subdomain not found.
* **422** – Validation errors (invalid dates, missing venue details, unknown categories, etc.).

### `POST /api/events/flyer/{event_id}`
Uploads or swaps the flyer for an event you own. Supply either a multipart `flyer_image` file or a JSON payload containing `flyer_image_id` to reuse an existing upload.

#### Successful response (200)
```json
{
  "data": {
    "id": "RVZFTlQtMQ==",
    "flyer_image_url": "https://eventschedule.test/storage/flyers/api-showcase.png"
  },
  "meta": {
    "message": "Flyer uploaded successfully"
  }
}
```

#### Failure scenarios
* **401** – Missing API key.
* **403** – Event does not belong to the authenticated user.
* **404** – Event ID not found.
* **422** – Validation error (e.g., invalid `flyer_image_id`).

## Error handling summary

| Status | Reason | Payload |
| ------ | ------ | ------- |
| 401 | Missing or invalid `X-API-Key` | `{ "error": "API key is required" }` or `{ "error": "Invalid API key" }` |
| 403 | User is not authorized for the requested resource | `{ "error": "Unauthorized" }` |
| 404 | Resource not found | `{ "message": "Not Found" }` |
| 422 | Validation failure | Standard Laravel validation error bag |
| 423 | API key temporarily blocked | `{ "error": "API key temporarily blocked" }` |
| 429 | Rate limit exceeded | `{ "error": "Rate limit exceeded" }` |

With these responses and the expanded payloads, every feature that is exposed in the Event Schedule UI—schedules, talent assignments, venue details, ticketing, payments, and media—can now be queried or created via the public REST API across all plan levels.
