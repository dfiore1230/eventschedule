.PHONY: up down build test dusk cypress artisan

up:
	docker compose -f .devcontainer/docker-compose.yml up -d --build

down:
	docker compose -f .devcontainer/docker-compose.yml down --volumes

build:
	docker compose -f .devcontainer/docker-compose.yml build workspace

test:
	docker compose -f .devcontainer/docker-compose.yml exec workspace bash -lc "php artisan test"

dusk:
	docker compose -f .devcontainer/docker-compose.yml exec workspace bash -lc "php artisan serve --port 8000 > /dev/null 2>&1 & sleep 3; php artisan dusk"

cypress:
	docker compose -f .devcontainer/docker-compose.yml exec workspace bash -lc "php artisan serve --port 8000 > /dev/null 2>&1 & sleep 3; npm run cypress:run"

artisan:
	docker compose -f .devcontainer/docker-compose.yml exec workspace bash -lc "php artisan $(filter-out $@,$(MAKECMDGOALS))"
