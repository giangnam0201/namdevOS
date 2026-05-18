# namdevOS Makefile
# Build targets for the namdevOS distribution

.DEFAULT_GOAL := help

.PHONY: build clean validate docker-build help

## build: Build the ISO image (requires root)
build:
	@echo "Building namdevOS ISO..."
	sudo bash build.sh

## clean: Clean build artifacts (requires root)
clean:
	@echo "Cleaning build artifacts..."
	sudo bash build.sh --clean

## validate: Run project validation checks
validate:
	@echo "Running validation..."
	bash scripts/validate.sh

## docker-build: Build ISO inside Docker container
docker-build:
	@echo "Building Docker environment..."
	docker build -f Dockerfile.build -t namdevos-builder .
	@echo "Building ISO in container..."
	docker run --rm --privileged -v "$$(pwd)/output:/output" namdevos-builder

## help: Show this help message
help:
	@echo "namdevOS Build System"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/## /  /'
