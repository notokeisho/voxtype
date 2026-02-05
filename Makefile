# ===========================================
# VoxType - Local Development
# ===========================================

.PHONY: help db whisper backend up down clean migrate logs dmg client-build

# Load environment variables
include .env
export

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' Makefile | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

# ===========================================
# Database
# ===========================================

db: ## Start PostgreSQL database
	@if docker ps -a --format '{{.Names}}' | grep -q '^voice-postgres$$'; then \
		echo "Starting existing voice-postgres container..."; \
		docker start voice-postgres; \
	else \
		echo "Creating new voice-postgres container..."; \
		docker run -d \
			--name voice-postgres \
			-e POSTGRES_USER=$(POSTGRES_USER) \
			-e POSTGRES_PASSWORD=$(POSTGRES_PASSWORD) \
			-e POSTGRES_DB=$(POSTGRES_DB) \
			-p 5434:5432 \
			postgres:15; \
	fi
	@echo "Waiting for PostgreSQL to be ready..."
	@sleep 3
	@echo "PostgreSQL is running on port 5434"

db-stop: ## Stop PostgreSQL database
	docker stop voice-postgres || true

# ===========================================
# Whisper Server
# ===========================================

whisper-build: ## Build whisper.cpp Docker image
	docker build -t whisper-server ./whisper

whisper: whisper-build ## Start whisper.cpp server
	@if docker ps -a --format '{{.Names}}' | grep -q '^whisper-server$$'; then \
		echo "Starting existing whisper-server container..."; \
		docker start whisper-server; \
	else \
		echo "Creating new whisper-server container..."; \
		docker run -d \
			--name whisper-server \
			-p 8080:8080 \
			-v $(PWD)/whisper/models:/app/models:ro \
			-e VOICE_LANGUAGE=$(or $(VOICE_LANGUAGE),ja) \
			-e WHISPER_MODEL=/app/models/ggml-small.bin \
			-e ENABLE_VAD=false \
			whisper-server; \
	fi
	@echo "Waiting for Whisper server to be ready..."
	@sleep 5
	@echo "Whisper server is running on port 8080"

whisper-stop: ## Stop whisper.cpp server
	docker stop whisper-server || true

# ===========================================
# Backend Server
# ===========================================

migrate: ## Run database migrations
	cd server && uv run alembic upgrade head

backend: ## Start backend server (requires db and whisper)
	cd server && uv run uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

# ===========================================
# Admin Web
# ===========================================

admin: ## Start admin web UI (port 5173)
	cd admin-web && npm run dev

admin-build: ## Build admin web for production
	cd admin-web && npm run build

# ===========================================
# All Services
# ===========================================

up: db whisper migrate ## Start all services (db, whisper, migrate)
	@echo ""
	@echo "==================================="
	@echo "All services are ready!"
	@echo "==================================="
	@echo "PostgreSQL: localhost:5434"
	@echo "Whisper:    localhost:8080"
	@echo ""
	@echo "Now run: make backend"
	@echo "==================================="

down: ## Stop all services
	docker stop voice-postgres whisper-server || true
	@echo "All services stopped"

clean: down ## Stop and remove all containers
	docker rm voice-postgres whisper-server || true
	@echo "All containers removed"

# ===========================================
# Utilities
# ===========================================

logs-db: ## Show PostgreSQL logs
	docker logs -f voice-postgres

logs-whisper: ## Show Whisper server logs
	docker logs -f whisper-server

status: ## Show status of all services
	@echo "=== Docker Containers ==="
	@docker ps --filter "name=voice-postgres" --filter "name=whisper-server" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
	@echo ""
	@echo "=== Health Checks ==="
	@curl -s http://localhost:8080/health > /dev/null 2>&1 && echo "Whisper: OK" || echo "Whisper: Not running"
	@curl -s http://localhost:8000/api/status > /dev/null 2>&1 && echo "Backend: OK" || echo "Backend: Not running"

test: ## Run tests
	cd server && uv run pytest

lint: ## Run linter
	cd server && uv run ruff check .

format: ## Format code
	cd server && uv run ruff format .

# ===========================================
# macOS Client
# ===========================================

# Client paths
CLIENT_DIR = client/VoxType
CLIENT_BUILD_DIR = $(CLIENT_DIR)/build/Build/Products/Release
CLIENT_APP = $(CLIENT_BUILD_DIR)/VoxType.app
CLIENT_DMG_RESOURCES = $(CLIENT_DIR)/dmg-resources
CLIENT_DIST = $(CLIENT_DIR)/dist

# Version from Info.plist (or override with VERSION=x.x.x)
VERSION ?= $(shell /usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" $(CLIENT_DIR)/VoxType/Info.plist 2>/dev/null || echo "1.0.0")

client-build: ## Build macOS client app
	@echo "Building VoxType.app (Release)..."
	cd $(CLIENT_DIR) && xcodebuild -project VoxType.xcodeproj -scheme VoxType -configuration Release -derivedDataPath ./build clean build
	@echo ""
	@echo "Build completed: $(CLIENT_APP)"

dmg: client-build ## Build macOS client and create DMG (VERSION=x.x.x to override)
	@echo ""
	@echo "Creating DMG for VoxType v$(VERSION)..."
	@mkdir -p $(CLIENT_DMG_RESOURCES) $(CLIENT_DIST)
	@# Create diagonal gradient background (top-left cream to bottom-right deep orange)
	@echo "Creating diagonal gradient background..."
	@magick -size 540x380 xc: -sparse-color Bilinear '0,0 #FFF8DC 540,380 #E65100' $(CLIENT_DMG_RESOURCES)/dmg-background.png
	@# Remove old DMG if exists
	@rm -f $(CLIENT_DIST)/VoxType-$(VERSION).dmg
	@# Create DMG
	create-dmg \
		--volname "VoxType" \
		--volicon "$(CLIENT_APP)/Contents/Resources/AppIcon.icns" \
		--background "$(CLIENT_DMG_RESOURCES)/dmg-background.png" \
		--window-pos 200 120 \
		--window-size 540 380 \
		--icon-size 80 \
		--icon "VoxType.app" 140 190 \
		--hide-extension "VoxType.app" \
		--app-drop-link 400 190 \
		"$(CLIENT_DIST)/VoxType-$(VERSION).dmg" \
		"$(CLIENT_APP)"
	@echo ""
	@echo "==================================="
	@echo "DMG created successfully!"
	@echo "Location: $(CLIENT_DIST)/VoxType-$(VERSION).dmg"
	@echo "==================================="
