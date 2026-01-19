# Planify

Planify is an open-source event platform for building public calendars, selling tickets, and managing check-ins. It pairs a full web UI with a REST API, supports ticket scanning workflows, and ships with a single-container Docker runtime for quick deployments.

## Overview

Planify focuses on end-to-end event operations: publishing schedules, taking payments, issuing tickets, and managing attendee access. Admins can configure roles, permissions, branding, and integrations while keeping a streamlined workflow for teams running venues, talent, or curator schedules. The project is designed to be self-hosted and simple to operate, with bootstrap automation that handles app keys, migrations, and storage setup on startup.

## Features

- Event calendars with public schedules and role-based admin views
- Ticket sales, QR code check-ins, and scanning APIs
- Integrations for Google Calendar and mobile wallet passes
- Role-based access control across UI and API
- Media library and branding tools for event graphics
- REST API with comprehensive reference documentation

## Quick Start (Docker)

```bash
cp .env.docker.example .env.docker
mkdir -p bind/storage bind/mysql
docker compose up --build -d
```

Visit `http://localhost:8080`.

## Documentation

All repository documentation is consolidated in `docs/README.md`.

## Changelog

See the versioned changelog in `docs/README.md`.
