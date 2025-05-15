# Docker compose configuration
DOCKER_COMPOSE = docker compose
SERVICE = kernel-builder
SHELL_SERVICE = shell
ARGS ?=

# Phony targets
.PHONY: help all default vanilla vm build run shell publish clean mrproper stop logs menuconfig

.DEFAULT_GOAL := default

##@ General

help:  ## Display this help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

default: vanilla vm  ## Default target: runs both vanilla and VM builds

all: run  ## Alias for 'run' target

##@ Build Targets

vanilla:  ## Build vanilla kernel
	$(DOCKER_COMPOSE) run --rm $(SERVICE) $(ARGS)

vm:  ## Build VM kernel
	$(DOCKER_COMPOSE) run --rm $(SERVICE) $(ARGS) --vm

build:  ## Build Docker image with local mirror support
	$(DOCKER_COMPOSE) build --build-arg USE_LOCAL_MIRROR=true

run:  ## Run kernel build with optional args
	$(DOCKER_COMPOSE) run --rm $(SERVICE) $(ARGS)

menuconfig:  ## Launch kernel menuconfig
	$(DOCKER_COMPOSE) run --rm $(SERVICE) --menuconfig

##@ Development / Debugging

shell:  ## Start interactive shell in container
	$(DOCKER_COMPOSE) run --rm --entrypoint /bin/bash $(SHELL_SERVICE)

logs:  ## View container logs
	$(DOCKER_COMPOSE) logs -f

##@ Release

publish:  ## Publish release to GitHub
	$(DOCKER_COMPOSE) run --rm $(SERVICE) --publish

##@ Cleanup

clean:  ## Remove build artifacts
	sudo rm -rf build/*

mrproper: clean stop  ## Full cleanup including Docker and ccache
	docker system prune -f
	sudo ccache -C

stop:  ## Stop and remove containers
	$(DOCKER_COMPOSE) down
