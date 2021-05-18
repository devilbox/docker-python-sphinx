ifneq (,)
.error This Makefile requires GNU Make.
endif

.PHONY: lint build rebuild lint test tag pull-base-image login push enter

# --------------------------------------------------------------------------------------------------
# Variables
# --------------------------------------------------------------------------------------------------
DIR = .
FILE = Dockerfile
IMAGE = devilbox/python-sphinx
TAG = latest
VERSION = 3.8
NO_CACHE =


# --------------------------------------------------------------------------------------------------
# Default Target
# --------------------------------------------------------------------------------------------------
help:
	@echo "lint                      Lint project files and repository"
	@echo "build   [VERSION=...]     Build sphinx docker image"
	@echo "rebuild [VERSION=...]     Build sphinx docker image without cache"
	@echo "test    [VERSION=...]     Test built sphinx docker image"
	@echo "tag TAG=...               Retag Docker image"
	@echo "login USER=... PASS=...   Login to Docker hub"
	@echo "push [TAG=...]            Push Docker image to Docker hub"


# --------------------------------------------------------------------------------------------------
# Lint Targets
# --------------------------------------------------------------------------------------------------
lint: lint-workflow
lint: lint-files

.PHONY: lint-workflow
lint-workflow:
	@echo "################################################################################"
	@echo "# Lint Workflow"
	@echo "################################################################################"
	@\
	GIT_CURR_MAJOR="$$( git tag | sort -V | tail -1 | sed 's|\.[0-9]*$$||g' )"; \
	GIT_CURR_MINOR="$$( git tag | sort -V | tail -1 | sed 's|^[0-9]*\.||g' )"; \
	GIT_NEXT_TAG="$${GIT_CURR_MAJOR}.$$(( GIT_CURR_MINOR + 1 ))"; \
		if ! grep 'refs:' -A 100 .github/workflows/nightly.yml \
		| grep  "          - '$${GIT_NEXT_TAG}'" >/dev/null; then \
		echo "[ERR] New Tag required in .github/workflows/nightly.yml: $${GIT_NEXT_TAG}"; \
			exit 1; \
		else \
		echo "[OK] Git Tag present in .github/workflows/nightly.yml: $${GIT_NEXT_TAG}"; \
	fi
	@echo

.PHONY: lint-files
lint-files:
	@echo "################################################################################"
	@echo "# Lint Files"
	@echo "################################################################################"
	@docker run --rm -v $(PWD):/data cytopia/file-lint file-cr --text --ignore '.git/,.github/,tests/,test-project/' --path .
	@docker run --rm -v $(PWD):/data cytopia/file-lint file-crlf --text --ignore '.git/,.github/,tests/,test-project/' --path .
	@docker run --rm -v $(PWD):/data cytopia/file-lint file-trailing-single-newline --text --ignore '.git/,.github/,tests/,test-project/' --path .
	@docker run --rm -v $(PWD):/data cytopia/file-lint file-trailing-space --text --ignore '.git/,.github/,tests/,test-project/' --path .
	@docker run --rm -v $(PWD):/data cytopia/file-lint file-utf8 --text --ignore '.git/,.github/,tests/,test-project/' --path .
	@docker run --rm -v $(PWD):/data cytopia/file-lint file-utf8-bom --text --ignore '.git/,.github/,tests/,test-project/' --path .
	@echo


# --------------------------------------------------------------------------------------------------
# Build Targets
# --------------------------------------------------------------------------------------------------
build:
	docker build $(NO_CACHE) \
		--label "org.opencontainers.image.created"="$$(date --rfc-3339=s)" \
		--label "org.opencontainers.image.revision"="$$(git rev-parse HEAD)" \
		--label "org.opencontainers.image.version"="$(VERSION)-dev" \
		--build-arg PYTHON=$(VERSION) \
		--build-arg ALPINE= \
		-t $(IMAGE) \
		-f $(DIR)/$(FILE) $(DIR)
	@$(MAKE) --no-print-directory tag TAG=$(VERSION)-dev

rebuild: NO_CACHE=--no-cache
rebuild: pull-base-image
rebuild: build



# --------------------------------------------------------------------------------------------------
# Test Targets
# --------------------------------------------------------------------------------------------------
test:
	docker run --rm $(IMAGE) python --version 2>&1 | grep -E 'Python $(VERSION)[.0-9]+'
	.tests/test-project.sh "$(IMAGE)" "$(VERSION)"



# -------------------------------------------------------------------------------------------------
#  Deploy Targets
# -------------------------------------------------------------------------------------------------
tag:
	@if [ "$(TAG)" = "" ]; then \
		>&2 echo "Error, you must specify TAG=..."; \
		exit 1; \
	fi
	docker tag $(IMAGE) $(IMAGE):$(TAG)

login:
	yes | docker login --username $(USER) --password $(PASS)

push:
	docker push $(IMAGE):$(TAG)


# --------------------------------------------------------------------------------------------------
# Helper Targets
# --------------------------------------------------------------------------------------------------
pull-base-image:
	@grep -E '^\s*FROM' Dockerfile \
		| sed -e 's/^FROM//g' -e 's/[[:space:]]*as[[:space:]]*.*$$//g' \
		| xargs -n1 docker pull

enter:
	docker run --rm --name $(subst /,-,$(IMAGE)) -it --entrypoint=/bin/sh $(ARG) $(IMAGE):$(VERSION)
