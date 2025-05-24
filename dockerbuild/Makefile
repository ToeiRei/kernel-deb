# Docker compose configuration
DOCKER_COMPOSE = COMPOSE_BAKE=true docker compose
SERVICE = kernel-builder
SHELL_SERVICE = shell
CROSS_SERVICE = kernel-builder-cross
CROSS_SHELL_SERVICE = cross-shell
ARGS ?=
IMAGE_NAME = dockerbuild-kernel-builder
LOCAL_KBUILD = kbuild2.sh
IMAGE_KBUILD = /usr/local/bin/kbuild2
BUILDTIME := ./buildtime

# Phony targets
.PHONY: help all default vanilla vm build run shell publish clean mrproper stop logs menuconfig check-image

.DEFAULT_GOAL := default

##@ General

help:  ## Display this help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

default: vanilla vm  ## Default target: runs both vanilla and VM builds

all: run  ## Alias for 'run' target

##@ Build Targets

vanilla: check-image  ## Build vanilla kernel
	@$(BUILDTIME) start kbuild2 vanilla
	@$(DOCKER_COMPOSE) run --rm $(SERVICE) $(ARGS); \
	status=$$?; \
	if [ $$status -eq 0 ]; then \
	    $(BUILDTIME) stop; \
	else \
	    $(BUILDTIME) failed; \
	    exit $$status; \
	fi

vm: check-image  ## Build VM kernel
	@$(BUILDTIME) start kbuild2 vm
	@$(DOCKER_COMPOSE) run --rm $(SERVICE) $(ARGS) --vm; \
	status=$$?; \
	if [ $$status -eq 0 ]; then \
	    $(BUILDTIME) stop; \
	else \
	    $(BUILDTIME) failed; \
	    exit $$status; \
	fi


build:  ## Build Docker image with local mirror support
	@$(BUILDTIME) start kbuild2 kbuild-container
	@$(DOCKER_COMPOSE) build --build-arg USE_LOCAL_MIRROR=true && \
	  $(BUILDTIME) stop || ( $(BUILDTIME) failed && exit 1 )


run: check-image  ## Run kernel build with optional args
	$(DOCKER_COMPOSE) run --rm $(SERVICE) $(ARGS)

menuconfig: check-image  ## Launch kernel menuconfig
	$(DOCKER_COMPOSE) run --rm $(SERVICE) --menuconfig $(ARGS)

##@ Development / Debugging

shell: check-image  ## Start interactive shell in container
	$(DOCKER_COMPOSE) run --rm --entrypoint /bin/bash $(SHELL_SERVICE)

logs:  ## View container logs
	$(DOCKER_COMPOSE) logs -f

##@ Release

publish: check-image  ## Publish release to GitHub
	$(DOCKER_COMPOSE) run --rm $(SERVICE) --publish

##@ Cleanup

clean:  ## Remove build artifacts
	sudo rm -rf build/*
	sudo rm -rf release/*

mrproper: clean stop  ## Full cleanup including Docker and ccache
	docker system prune -f
	sudo ccache -C

stop:  ## Stop and remove containers
	$(DOCKER_COMPOSE) down

##@ Internals

check-image:  ## Ensure Docker image is up-to-date with kbuild2.sh
	@echo "🔍 Verifying Docker image '${IMAGE_NAME}' is current..."
	@if ! docker image inspect ${IMAGE_NAME} >/dev/null 2>&1; then \
		echo "⚠️  Image '${IMAGE_NAME}' not found. Triggering build..."; \
		$(MAKE) build; \
	else \
		LOCAL_SUM=$$(sha256sum ${LOCAL_KBUILD} | awk '{print $$1}'); \
		IMAGE_SUM=$$(docker run --rm --entrypoint sha256sum ${IMAGE_NAME} ${IMAGE_KBUILD} | awk '{print $$1}'); \
		if [ "$$LOCAL_SUM" != "$$IMAGE_SUM" ]; then \
			echo "⚠️  kbuild2.sh mismatch. Rebuilding image..."; \
			$(MAKE) build; \
		else \
			echo "✅ Docker image is up-to-date."; \
		fi \
	fi

##@ Cross Compile

cross: check-image  ## Build kernel for cross target (e.g. arm64)
    @$(BUILDTIME) start kbuild2 cross
    @$(DOCKER_COMPOSE) run --rm $(CROSS_SERVICE) $(ARGS); \
    status=$$?; \
    if [ $$status -eq 0 ]; then \
        $(BUILDTIME) stop; \
    else \
        $(BUILDTIME) failed; \
        exit $$status; \
    fi

cross-shell: check-image  ## Start interactive shell in cross container
    $(DOCKER_COMPOSE) run --rm --entrypoint /bin/bash $(CROSS_SHELL_SERVICE)

cross-menuconfig: check-image  ## Launch menuconfig for cross target
    $(DOCKER_COMPOSE) run --rm $(CROSS_SERVICE) --menuconfig $(ARGS)

cross-publish: check-image  ## Publish cross build release to GitHub
    $(DOCKER_COMPOSE) run --rm $(CROSS_SERVICE) --publish

