.PHONY: help build up down restart logs shell test clean install migrate fresh

# Color output
BLUE := \033[0;34m
GREEN := \033[0;32m
RED := \033[0;31m
RESET := \033[0m

help: ## Show this help message
	@echo '$(BLUE)Available commands:$(RESET)'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(RESET) %s\n", $$1, $$2}'

build: ## Build all Docker containers
	docker-compose build

up: ## Start all services in detached mode
	docker-compose up -d

down: ## Stop and remove all containers
	docker-compose down

restart: ## Restart all services
	docker-compose restart

stop: ## Stop all services without removing containers
	docker-compose stop

logs: ## View logs for all services
	docker-compose logs -f

logs-app: ## View logs for app service
	docker-compose logs -f app

logs-horizon: ## View logs for Horizon
	docker-compose logs -f horizon

logs-queue: ## View logs for queue worker
	docker-compose logs -f queue-worker

logs-vite: ## View logs for Vite
	docker-compose logs -f vite

logs-nginx: ## View logs for Nginx
	docker-compose logs -f nginx

shell: ## Access bash shell in app container
	docker-compose exec app sh

shell-mysql: ## Access MySQL CLI
	docker-compose exec mysql mysql -u laravel -ppassword laravel

shell-redis: ## Access Redis CLI
	docker-compose exec redis redis-cli

ps: ## Show status of all containers
	docker-compose ps

install: up ## Install dependencies and setup application
	@echo "$(BLUE)Installing Composer dependencies...$(RESET)"
	docker-compose exec app composer install
	@echo "$(BLUE)Installing npm dependencies...$(RESET)"
	docker-compose exec vite npm install
	@echo "$(BLUE)Generating application key...$(RESET)"
	docker-compose exec app php artisan key:generate
	@echo "$(BLUE)Running migrations...$(RESET)"
	docker-compose exec app php artisan migrate
	@echo "$(GREEN)Installation complete!$(RESET)"

migrate: ## Run database migrations
	docker-compose exec app php artisan migrate

migrate-fresh: ## Drop all tables and re-run migrations
	docker-compose exec app php artisan migrate:fresh

migrate-seed: ## Run migrations with seeders
	docker-compose exec app php artisan migrate --seed

fresh: ## Fresh install with seed data
	docker-compose exec app php artisan migrate:fresh --seed

seed: ## Run database seeders
	docker-compose exec app php artisan db:seed

test: ## Run tests
	docker-compose exec app php artisan test

tinker: ## Open Laravel Tinker
	docker-compose exec app php artisan tinker

cache-clear: ## Clear all caches
	docker-compose exec app php artisan cache:clear
	docker-compose exec app php artisan config:clear
	docker-compose exec app php artisan route:clear
	docker-compose exec app php artisan view:clear

optimize: ## Optimize the application
	docker-compose exec app php artisan config:cache
	docker-compose exec app php artisan route:cache
	docker-compose exec app php artisan view:cache

queue-restart: ## Restart queue workers
	docker-compose restart queue-worker horizon

sqs-list: ## List SQS queues in LocalStack
	docker-compose exec localstack awslocal sqs list-queues

sqs-send: ## Send test message to SQS queue
	docker-compose exec localstack awslocal sqs send-message \
		--queue-url http://localhost:4566/000000000000/laravel-requests-queue \
		--message-body '{"test": "message", "timestamp": "'$$(date +%s)'"}'

sqs-receive: ## Receive messages from SQS queue
	docker-compose exec localstack awslocal sqs receive-message \
		--queue-url http://localhost:4566/000000000000/laravel-requests-queue

clean: ## Stop containers and remove all data
	docker-compose down -v

clean-all: ## Remove containers, volumes, and images
	docker-compose down -v --rmi all

rebuild: clean build up ## Full rebuild from scratch
	@echo "$(GREEN)Rebuild complete!$(RESET)"

npm-install: ## Install npm dependencies
	docker-compose exec vite npm install

npm-build: ## Build frontend assets
	docker-compose exec vite npm run build

npm-dev: ## Run Vite dev server
	docker-compose exec vite npm run dev

composer-install: ## Install Composer dependencies
	docker-compose exec app composer install

composer-update: ## Update Composer dependencies
	docker-compose exec app composer update

permissions: ## Fix storage and cache permissions
	docker-compose exec app chown -R www-data:www-data /var/www/html/storage
	docker-compose exec app chown -R www-data:www-data /var/www/html/bootstrap/cache
	docker-compose exec app chmod -R 775 /var/www/html/storage
	docker-compose exec app chmod -R 775 /var/www/html/bootstrap/cache

status: ## Show comprehensive status
	@echo "$(BLUE)=== Container Status ===$(RESET)"
	@docker-compose ps
	@echo ""
	@echo "$(BLUE)=== Service Health ===$(RESET)"
	@docker-compose exec mysql mysqladmin ping -h localhost -u root -ppassword 2>/dev/null && echo "$(GREEN)MySQL: ✓$(RESET)" || echo "$(RED)MySQL: ✗$(RESET)"
	@docker-compose exec redis redis-cli ping 2>/dev/null | grep -q PONG && echo "$(GREEN)Redis: ✓$(RESET)" || echo "$(RED)Redis: ✗$(RESET)"
	@curl -s http://localhost:4566/_localstack/health > /dev/null && echo "$(GREEN)LocalStack: ✓$(RESET)" || echo "$(RED)LocalStack: ✗$(RESET)"

init: ## Initial setup (run this first time)
	@echo "$(BLUE)Starting Docker setup...$(RESET)"
	@if [ ! -f .env ]; then \
		echo "$(BLUE)Copying .env.docker to .env...$(RESET)"; \
		cp .env.docker .env; \
	else \
		echo "$(GREEN).env file already exists$(RESET)"; \
	fi
	@$(MAKE) build
	@$(MAKE) up
	@echo "$(BLUE)Waiting for services to be ready...$(RESET)"
	@sleep 10
	@$(MAKE) install
	@echo "$(GREEN)✓ Setup complete!$(RESET)"
	@echo ""
	@echo "$(BLUE)Access your application:$(RESET)"
	@echo "  Web:     $(GREEN)http://localhost$(RESET)"
	@echo "  Horizon: $(GREEN)http://localhost/horizon$(RESET)"
	@echo "  Vite:    $(GREEN)http://localhost:5173$(RESET)"