# Devcontainer / Local CI Reproduction

This devcontainer is intended to closely mirror the CI environment so you can run PHP unit tests, Laravel Dusk, and Cypress locally in a reproducible way.

## Key points

- PHP: 8.3
- MySQL: 8.0 (service `db` in docker-compose)
- Node: 18
- Chromium & chromedriver installed for Dusk

## Quick start

1. Build and start the containers:

   make up

2. Open the project in VS Code (use the Remote - Containers extension), or run commands from the host:

   make test    # run phpunit
   make dusk    # run Laravel Dusk (starts a temporary server)
   make cypress # run Cypress E2E tests

3. The devcontainer post-create script automatically runs `composer install`, `npm ci`, and `php artisan migrate` once the container and DB are ready.

## Notes

- The `Makefile` uses the `.devcontainer/docker-compose.yml` to start the `workspace` and `db` services.
- The `post-create.sh` script will wait for the DB to be healthy before running migrations.
- If you need to run commands inside the workspace container, use `docker compose -f .devcontainer/docker-compose.yml exec workspace bash`.

## Troubleshooting

- If `make up` fails with "Cannot connect to the Docker daemon", ensure Docker Desktop (or your Docker daemon) is running and you have permission to access it.
- If containers fail to become healthy, inspect logs with `docker compose -f .devcontainer/docker-compose.yml logs --tail=200` and the db logs specifically with `docker logs <container>`.
- If Dusk or Cypress fail due to missing Chrome/Chromedriver, ensure the `workspace` image includes Chromium and `chromium-driver` (the Dockerfile attempts to install these). If your platform differs, you may need to install an alternate Chrome package or adjust the Dockerfile.
