## Defensive settings for make:
#     https://tech.davis-hansson.com/p/make/
SHELL:=bash
.ONESHELL:
.SHELLFLAGS:=-xeu -o pipefail -O inherit_errexit -c
.SILENT:
.DELETE_ON_ERROR:
MAKEFLAGS+=--warn-undefined-variables
MAKEFLAGS+=--no-builtin-rules

# We like colors
# From: https://coderwall.com/p/izxssa/colored-makefile-for-golang-projects
RED=`tput setaf 1`
GREEN=`tput setaf 2`
RESET=`tput sgr0`
YELLOW=`tput setaf 3`

# The release to work on: version.txt, the latest one, unless VERSION says
# otherwise. Every image goes through the same targets, for example
# `make build-image VERSION=3.0.1`.
IMAGE_NAME=plone/nick
VERSION?=$(shell cat version.txt)
SERIES=$(basename $(firstword $(subst -, ,$(VERSION))))
RELEASE_DIR=$(SERIES)/$(VERSION)
NODE_VERSION=$(shell sed -n 's/^ARG NODE_VERSION=//p' $(SERIES)/Dockerfile)
IMAGE_TAG=${VERSION}
IMAGE_SUFFIX=
# What to install as @plone/nick, by default the release itself, from its
# lockfile. Set it to another pnpm spec to build an unreleased Nick, for example
# `make build-image NICK_SPEC=https://codeload.github.com/plone/nick/tar.gz/main`.
# The image has no git, so `github:` specs do not work.
NICK_SPEC=${VERSION}
# Add-ons from npm to build in, space separated
ADDONS=

# Code Quality
# All tooling runs via docker: no local installs required. What there is to
# lint is the Dockerfile, the entrypoint and the workflow YAML.
DOCKER ?= docker
CURRENT_FOLDER=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
DOCKERFILES=$(wildcard */Dockerfile)
SHELL_SCRIPTS=$(wildcard */_shared/*.sh scripts/*.sh)
YAML_FILES=.github/workflows/*.yml .github/dependabot.yml

.PHONY: all
all: help

# Add the following 'help' target to your Makefile
# And add help text after each target name starting with '\#\#'
.PHONY: help
help: # This help message
	@grep -E '^[a-zA-Z_-]+:.*?# .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?# "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: lint
lint: ## Lint the Dockerfiles (hadolint), the shared scripts (shellcheck) and workflows (yaml well-formedness)
	@echo "$(GREEN)==> hadolint$(RESET)"
	set -e; for f in $(DOCKERFILES); do \
		echo "hadolint $$f"; \
		$(DOCKER) run --rm -v "$(CURRENT_FOLDER):/mnt:ro" -w /mnt \
			hadolint/hadolint hadolint "$$f"; \
	done
	@echo "$(GREEN)==> shellcheck$(RESET)"
	$(DOCKER) run --rm -v "$(CURRENT_FOLDER):/mnt:ro" -w /mnt \
		koalaman/shellcheck:stable $(SHELL_SCRIPTS)
	@echo "$(GREEN)==> yaml$(RESET)"
	set -e; for f in $(YAML_FILES); do \
		echo "yaml check $$f"; \
		$(DOCKER) run --rm -v "$(CURRENT_FOLDER):/data:ro" \
			mikefarah/yq:4 -e 'true' "/data/$$f" >/dev/null; \
	done
	@echo "$(GREEN)==> lint OK$(RESET)"

# Build image
.PHONY: show-image
show-image: ## Print Version
	@echo "$(IMAGE_NAME):$(IMAGE_TAG)$(IMAGE_SUFFIX)"

.PHONY: check-release
check-release: # Fail unless the release folder exists
	@test -f $(RELEASE_DIR)/package.json || { echo "No $(RELEASE_DIR)/package.json"; exit 1; }

.PHONY: new-release
new-release: ## Create the folder and lockfile of a new release, with VERSION=3.0.1 or VERSION=3.0.1-alpha.1
	@sh scripts/new-release.sh $(VERSION)
	@$(MAKE) lock VERSION=$(VERSION)

.PHONY: lock
lock: check-release ## Resolve the pnpm-lock.yaml of a release
	@$(DOCKER) run --rm -v "$(CURRENT_FOLDER):/repo" node:$(NODE_VERSION)-bookworm-slim \
		sh /repo/scripts/update-lock.sh $(VERSION)

.PHONY: build-image
build-image: check-release ## Build the image of a release
	@echo "Building $(IMAGE_NAME):$(IMAGE_TAG)$(IMAGE_SUFFIX)"
	@docker buildx build . -f $(SERIES)/Dockerfile --build-arg NICK_VERSION=$(VERSION) --build-arg NICK_SPEC="$(NICK_SPEC)" --build-arg ADDONS="$(ADDONS)" -t $(IMAGE_NAME):$(IMAGE_TAG)$(IMAGE_SUFFIX) --load
