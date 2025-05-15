DOCKER_COMPOSE = docker compose
SERVICE = kernel-builder
SHELL_SERVICE = shell
ARGS ?=

.PHONY: help all clean mrproper stop build run shell publish logs
default: vanilla vm

all: run

help:
	@echo "make                    # Default: Full build pipeline (vanilla + VM + publish)"
	@echo "make all                # Same as default target"
	@echo "make build              # Build Docker image"
	@echo "make run ARGS=...       # Run a build with optional args"
	@echo "make shell              # Drop into container shell"
	@echo "make publish            # Publish release to GitHub"
	@echo "make clean              # Clean build artifacts"
	@echo "make mrproper           # Full nuclear cleanup"
	@echo "make stop               # Stop the container"
	@echo "make logs               # View container logs"

vanilla:
	$(DOCKER_COMPOSE) run --rm $(SERVICE) $(ARGS)

vm:
	$(DOCKER_COMPOSE) run --rm $(SERVICE) $(ARGS) --vm

build:
	COMPOSE_BAKE=true $(DOCKER_COMPOSE) build

run:
	$(DOCKER_COMPOSE) run --rm $(SERVICE) $(ARGS)

shell:
	$(DOCKER_COMPOSE) run --rm --entrypoint /bin/bash $(SHELL_SERVICE)

publish:
	$(DOCKER_COMPOSE) run --rm $(SERVICE) --publish

clean:
	rm -rf build/*

mrproper: clean stop
	docker system prune -f
	ccache -C

stop:
	$(DOCKER_COMPOSE) down

logs:
	$(DOCKER_COMPOSE) logs -f
