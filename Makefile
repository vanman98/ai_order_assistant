.PHONY: help dev codegen format analyze test check db-up db-down backend-install backend-migrate backend-dev backend-check

help:
	@echo "make dev      Run the development app"
	@echo "make codegen  Generate Riverpod/Freezed/JSON code"
	@echo "make db-up    Start PostgreSQL"
	@echo "make backend-dev  Run NestJS in watch mode"
	@echo "make check    Verify Flutter and backend"

dev:
	flutter run \
		--dart-define=APP_ENV=dev \
		--dart-define=API_BASE_URL=http://192.168.1.197:3000/api \
		--dart-define=ENABLE_LOGGING=true

codegen:
	dart run build_runner build --delete-conflicting-outputs

format:
	dart format lib test

analyze:
	flutter analyze

test:
	flutter test

db-up:
	cd backend && docker compose up -d

db-down:
	cd backend && docker compose down

backend-install:
	cd backend && npm install

backend-migrate:
	cd backend && npx prisma migrate deploy

backend-dev:
	cd backend && npm run start:dev

backend-check:
	cd backend && npm run build && npm test

check: format analyze test backend-check
