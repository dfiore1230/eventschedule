# Planify Docker Environment

This repository provides a single-container Docker runtime for the Planify Laravel application. It packages PHP-FPM, Nginx, MariaDB, and a scheduler worker so that the app can be bootstrapped quickly for local development, testing, or small-scale deployments. Multi-service Compose definitions have been removed; the all-in-one image is the only supported topology.

## Features

- **Single-container stack**: PHP-FPM application, Nginx web server, MariaDB database, and scheduler in one container.
- **Automated bootstrap**: Composer dependencies, npm assets, database migrations, and the application key are provisioned automatically on startup.
- **Persistent data**: Bind mounts retain database data and uploaded files between restarts.
- **Local source build**: Builds from the current Planify repository checkout.

## Prerequisites

- Docker Engine 24.0 or newer
- Docker Compose v2 plugin
- Internet access on the build machine to fetch Composer, npm, and git dependencies

## Getting Started

1. Copy the Docker environment template and adjust credentials:
   ```bash
   cp .env.docker.example .env.docker
   # Update DB_PASSWORD and any additional overrides
   ```
2. Prepare the bind-mount directories (they can live anywhere on your host):
   ```bash
   mkdir -p bind/storage bind/mysql
   ```
3. Start the stack:
   ```bash
   docker compose up --build -d
   ```
4. Visit [http://localhost:8080](http://localhost:8080) to access the application.

The first startup can take several minutes while dependencies are installed and assets are compiled.

## Using the Prebuilt Docker Hub Image

If you would prefer to start from a published image rather than building the
Dockerfile in this repository, pull your Planify image from Docker Hub. You can
create a thin wrapper Dockerfile that layers
environment defaults, assets, or other customizations on top of the prebuilt
runtime:

```Dockerfile
FROM your-dockerhub-user/planify:latest

# Example override: copy a production-ready .env into the container
# COPY .env.production /var/www/html/.env
```

See [`examples/Dockerfile.from-prebuilt`](examples/Dockerfile.from-prebuilt) for a
fully annotated template that demonstrates common customization points while
reusing the prebuilt container. To launch the single-container runtime without
rebuilding images, use the companion Compose file at
[`examples/docker-compose.single-prebuilt.yml`](examples/docker-compose.single-prebuilt.yml):

```bash
cp .env.docker.example .env.docker
mkdir -p bind/storage bind/mysql
docker compose -f examples/docker-compose.single-prebuilt.yml up -d
```

This version layers the published image with bind mounts for Laravel storage and MariaDB data so you can mirror the single-container
topology without rebuilding images.

## Environment Configuration

Key settings are defined in `.env.docker` and forwarded into the containers. At a minimum you should set `DB_PASSWORD`. Additional variables supported by Laravel (e.g., `APP_URL`, `MAIL_` settings) can be added to tailor the runtime.

The Dockerfile builds from the local Planify repository checkout. Rebuild the image after pulling new changes.

## Operational Tips

- **Logs**: View container logs with `docker compose logs -f app`.
- **Migrations**: The entrypoint runs `php artisan migrate --force` on startup. Run additional artisan commands via `docker compose exec app php artisan ...`.
- **Database access**: MariaDB runs inside the container; the data lives in `bind/mysql` on the host.
- **Updating dependencies**: Rebuild the image (`docker compose build`) after modifying Composer or npm dependencies.

## Troubleshooting

- **`docker: command not found`**: Install the Docker Engine and Docker Compose
  plugin for your platform and ensure that the `docker` CLI is available on your
  shell `PATH`. On Linux, this typically means installing the latest Docker
  packages from the official repositories and reloading your shell session after
  installation. On macOS and Windows, installing [Docker Desktop](https://www.docker.com/products/docker-desktop/)
  provides both the engine and the Compose plugin.

## Publishing Images with GitHub Actions

This repository ships with a GitHub Actions workflow named **Build and Publish
Docker image**. The workflow builds the `single` stage of the Dockerfile on
every pull request, push to `main`, and manual run from the **Actions** tab. On
pull requests it performs a build-only dry run, while pushes to `main` publish
the resulting image to Docker Hub when credentials are available.

To enable publishing, create the following secrets in your GitHub repository:

| Secret                 | Description                                           |
|------------------------|-------------------------------------------------------|
| `DOCKERHUB_USERNAME`   | Docker Hub username that owns the target repository. |
| `DOCKERHUB_TOKEN`      | Access token or password for that account.           |
| `DOCKERHUB_REPOSITORY` | Fully-qualified repository name (e.g. `user/image`). |

You can set these secrets through the GitHub web UI or with the
[GitHub CLI](https://cli.github.com/) by running:

```bash
gh secret set DOCKERHUB_USERNAME --body "your-username"
gh secret set DOCKERHUB_TOKEN --body "<access token>"
gh secret set DOCKERHUB_REPOSITORY --body "your-username/eventsschedule"
```

Once configured, pushing to `main` will build, tag, and publish images using the
branch, tag, and `latest` conventions emitted by the workflow. Manual runs from
the Actions tab behave the same way. If the secrets are missing (for example,
when the workflow is triggered from a fork), the workflow still builds the
image to ensure the Dockerfile remains healthy but skips publishing.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a history of notable updates.

## License

Planify originates from the Event Schedule project and retains the required attribution. Review the upstream project licensing details and ensure compliance when deploying.
