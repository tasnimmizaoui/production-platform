# Makefile

.PHONY: help build up down logs test clean api-logs worker-logs

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

build: ## Build all services
	docker-compose build

up: ## Start all services
	docker-compose up -d
	@echo "✅ Services started"
	@echo "API: http://localhost:8080"
	@echo "Worker: http://localhost:8081"
	@echo "Prometheus: http://localhost:9090"
	@echo "Redis: localhost:6379"

down: ## Stop all services
	docker-compose down

logs: ## Show logs from all services
	docker-compose logs -f

api-logs: ## Show API service logs
	docker-compose logs -f api

worker-logs: ## Show worker service logs
	docker-compose logs -f worker

test: ## Run integration tests
	@echo "Testing API health..."
	@curl -f http://localhost:8080/health || exit 1
	@echo "\n✅ API is healthy"
	@echo "Testing Worker health..."
	@curl -f http://localhost:8081/health || exit 1
	@echo "\n✅ Worker is healthy"
	@echo "Creating test task..."
	@curl -X POST http://localhost:8080/tasks \
		-H "Content-Type: application/json" \
		-d '{"payload":"test-task-data"}' | jq .
	@echo "\n✅ All tests passed"

clean: ## Remove all containers, volumes, and images
	docker-compose down -v
	docker system prune -f

ps: ## Show running containers
	docker-compose ps

restart: down up ## Restart all services

dev-api: ## Run API locally (requires Redis running)
	cd app/api-service && go run cmd/api/main.go

dev-worker: ## Run worker locally (requires Redis running)
	cd app/worker-service && go run cmd/worker/main.go