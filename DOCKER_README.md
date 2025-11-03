# Docker Setup Guide for Laravel + Vue + SQS

This Docker Compose configuration provides a complete development environment for your Laravel + Vue application with Redis, Horizon, and SQS support.

## Services Overview

The Docker setup includes the following services:

| Service | Description | Port(s) |
|---------|-------------|---------|
| **app** | PHP 8.2-FPM with Laravel application | Internal (9000) |
| **nginx** | Nginx web server | 80 (configurable) |
| **mysql** | MySQL 8.0 database | 3306 |
| **redis** | Redis 7 for caching, sessions, and Horizon | 6379 |
| **localstack** | Local AWS SQS emulation | 4566 |
| **horizon** | Laravel Horizon dashboard for queue monitoring | Access via nginx at /horizon |
| **queue-worker** | Laravel queue worker for SQS job processing | N/A |
| **vite** | Vite dev server for Vue.js with HMR | 5173 |

## Prerequisites

- Docker Desktop or Docker Engine (20.10+)
- Docker Compose (v2.0+)
- At least 4GB of free RAM
- At least 10GB of free disk space

## Quick Start

### 1. Copy Environment File

```bash
cp .env.docker .env
```

Or if you prefer to keep your existing `.env`, add these Docker-specific variables:

```env
DB_CONNECTION=mysql
DB_HOST=mysql
DB_PORT=3306
DB_DATABASE=laravel
DB_USERNAME=laravel
DB_PASSWORD=password

REDIS_HOST=redis
CACHE_STORE=redis
SESSION_DRIVER=redis

QUEUE_CONNECTION=sqs
SQS_PREFIX=http://localstack:4566/000000000000
SQS_QUEUE=laravel-requests-queue

AWS_ACCESS_KEY_ID=test
AWS_SECRET_ACCESS_KEY=test
AWS_DEFAULT_REGION=us-east-1
AWS_ENDPOINT=http://localstack:4566
```

### 2. Generate Application Key

```bash
# Generate app key (if not already set)
docker-compose run --rm app php artisan key:generate
```

### 3. Build and Start Services

```bash
# Build all containers
docker-compose build

# Start all services in detached mode
docker-compose up -d
```

### 4. Install Dependencies and Setup Database

```bash
# Install Composer dependencies (if not already installed)
docker-compose exec app composer install

# Run database migrations
docker-compose exec app php artisan migrate

# (Optional) Seed the database
docker-compose exec app php artisan db:seed
```

### 5. Access Your Application

- **Laravel App**: http://localhost
- **Horizon Dashboard**: http://localhost/horizon
- **Vite Dev Server**: http://localhost:5173 (HMR enabled)
- **LocalStack SQS**: http://localhost:4566

## Common Commands

### Container Management

```bash
# Start all services
docker-compose up -d

# Stop all services
docker-compose down

# View logs for all services
docker-compose logs -f

# View logs for specific service
docker-compose logs -f app
docker-compose logs -f horizon
docker-compose logs -f queue-worker

# Restart a specific service
docker-compose restart app
docker-compose restart horizon

# Rebuild containers (after Dockerfile changes)
docker-compose build
docker-compose up -d --build
```

### Laravel Artisan Commands

```bash
# Run artisan commands
docker-compose exec app php artisan [command]

# Examples:
docker-compose exec app php artisan migrate
docker-compose exec app php artisan db:seed
docker-compose exec app php artisan cache:clear
docker-compose exec app php artisan config:clear
docker-compose exec app php artisan route:list
docker-compose exec app php artisan tinker
```

### Database Commands

```bash
# Access MySQL CLI
docker-compose exec mysql mysql -u laravel -ppassword laravel

# Backup database
docker-compose exec mysql mysqldump -u laravel -ppassword laravel > backup.sql

# Restore database
docker-compose exec -T mysql mysql -u laravel -ppassword laravel < backup.sql
```

### Redis Commands

```bash
# Access Redis CLI
docker-compose exec redis redis-cli

# Monitor Redis in real-time
docker-compose exec redis redis-cli MONITOR

# Flush all Redis data
docker-compose exec redis redis-cli FLUSHALL
```

### Queue and Horizon

```bash
# Restart Horizon
docker-compose restart horizon

# View Horizon logs
docker-compose logs -f horizon

# View queue worker logs
docker-compose logs -f queue-worker

# Manually process queue jobs
docker-compose exec app php artisan queue:work sqs --tries=3
```

### LocalStack SQS Commands

```bash
# Access LocalStack container
docker-compose exec localstack bash

# List SQS queues
docker-compose exec localstack awslocal sqs list-queues

# Get queue URL
docker-compose exec localstack awslocal sqs get-queue-url --queue-name laravel-requests-queue

# Send test message to queue
docker-compose exec localstack awslocal sqs send-message \
  --queue-url http://localhost:4566/000000000000/laravel-requests-queue \
  --message-body '{"test": "message"}'

# Receive messages from queue
docker-compose exec localstack awslocal sqs receive-message \
  --queue-url http://localhost:4566/000000000000/laravel-requests-queue
```

### Frontend Development

```bash
# Install npm dependencies (inside vite container)
docker-compose exec vite npm install

# Run Vite dev server (already running by default)
docker-compose exec vite npm run dev

# Build for production
docker-compose exec vite npm run build

# Build with SSR
docker-compose exec vite npm run build:ssr
```

## Testing the Setup

### 1. Test Laravel Application

```bash
# Check Laravel application is running
curl http://localhost

# Expected: Laravel welcome page or your app's home page
```

### 2. Test Database Connection

```bash
docker-compose exec app php artisan migrate:status
```

### 3. Test Redis Connection

```bash
docker-compose exec app php artisan tinker
# Then in Tinker:
# Redis::set('test', 'value')
# Redis::get('test')
# exit
```

### 4. Test SQS Queue

```bash
# Send a test request to the API endpoint
curl -X POST http://localhost/api/request \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": 123,
    "action": "test",
    "data": {
      "key": "value"
    }
  }'

# Check queue worker logs to see job processing
docker-compose logs -f queue-worker
```

### 5. Test Horizon Dashboard

Visit http://localhost/horizon in your browser. You should see the Horizon dashboard with queue metrics.

### 6. Test Vue/Vite Hot Module Replacement

1. Open your browser to http://localhost
2. Edit a Vue component in `resources/js/`
3. Save the file
4. The browser should automatically update without a full page refresh

## Troubleshooting

### Containers Won't Start

```bash
# Check container status
docker-compose ps

# Check specific container logs
docker-compose logs app
docker-compose logs mysql
docker-compose logs redis

# Common issues:
# - Port conflicts: Change ports in .env (APP_PORT, FORWARD_DB_PORT, etc.)
# - Permission issues: Run with sudo or fix Docker permissions
# - Resource limits: Increase Docker Desktop memory allocation
```

### Database Connection Issues

```bash
# Ensure MySQL is healthy
docker-compose ps mysql

# Check MySQL logs
docker-compose logs mysql

# Wait for MySQL to be fully ready (can take 30-60 seconds on first start)
docker-compose exec mysql mysqladmin ping -h localhost -u root -ppassword

# Reset database container if needed
docker-compose down -v
docker-compose up -d
```

### Permission Issues

```bash
# Fix storage and cache permissions
docker-compose exec app chown -R www-data:www-data /var/www/html/storage
docker-compose exec app chown -R www-data:www-data /var/www/html/bootstrap/cache
docker-compose exec app chmod -R 775 /var/www/html/storage
docker-compose exec app chmod -R 775 /var/www/html/bootstrap/cache
```

### Queue Jobs Not Processing

```bash
# Check queue worker is running
docker-compose ps queue-worker

# View queue worker logs
docker-compose logs -f queue-worker

# Check SQS queue exists in LocalStack
docker-compose exec localstack awslocal sqs list-queues

# Restart queue worker
docker-compose restart queue-worker

# Check Horizon status (if using Redis queues)
docker-compose restart horizon
```

### LocalStack SQS Issues

```bash
# Check LocalStack is healthy
docker-compose ps localstack
docker-compose logs localstack

# Verify SQS queue was created
docker-compose exec localstack awslocal sqs list-queues

# Recreate SQS queue manually
docker-compose exec localstack awslocal sqs create-queue --queue-name laravel-requests-queue

# Check init script ran successfully
docker-compose logs localstack | grep "SQS setup complete"
```

### Vite/HMR Not Working

```bash
# Check Vite container is running
docker-compose ps vite

# View Vite logs
docker-compose logs -f vite

# Restart Vite container
docker-compose restart vite

# Ensure package.json dependencies are installed
docker-compose exec vite npm install

# Check Vite is binding to 0.0.0.0 (not just localhost)
docker-compose logs vite | grep "Local:"
```

## Environment Variables

### Key Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `APP_PORT` | Port for Nginx web server | 80 |
| `FORWARD_DB_PORT` | Port for MySQL access from host | 3306 |
| `FORWARD_REDIS_PORT` | Port for Redis access from host | 6379 |
| `VITE_PORT` | Port for Vite dev server | 5173 |
| `DB_DATABASE` | MySQL database name | laravel |
| `DB_USERNAME` | MySQL username | laravel |
| `DB_PASSWORD` | MySQL password | password |
| `QUEUE_CONNECTION` | Queue driver (sqs, redis, database) | sqs |
| `SQS_QUEUE` | SQS queue name | laravel-requests-queue |

## Production Considerations

This Docker setup is optimized for **local development**. For production:

1. **Remove LocalStack**: Use real AWS SQS
2. **Update Environment**: Set `APP_ENV=production`, `APP_DEBUG=false`
3. **Secure Credentials**: Use strong passwords and AWS credentials
4. **Use HTTPS**: Add SSL certificates to Nginx
5. **Optimize PHP**: Use production PHP.ini settings
6. **Build Assets**: Run `npm run build` instead of dev server
7. **Use Docker Secrets**: For sensitive data
8. **Add Health Checks**: For all services
9. **Configure Logging**: Send logs to external service
10. **Scale Workers**: Adjust queue worker replicas based on load

## Development Workflow

### Typical Daily Workflow

```bash
# 1. Start containers
docker-compose up -d

# 2. Check everything is running
docker-compose ps

# 3. View logs if needed
docker-compose logs -f app

# 4. Make code changes (files are mounted, changes are immediate)

# 5. Run migrations/seeders when needed
docker-compose exec app php artisan migrate

# 6. Stop containers when done
docker-compose down
```

### Working with Branches

```bash
# When switching branches
docker-compose down
git checkout feature-branch
docker-compose up -d
docker-compose exec app composer install
docker-compose exec app php artisan migrate
docker-compose exec vite npm install
```

## Cleaning Up

### Remove All Containers and Volumes

```bash
# Stop and remove containers, networks, volumes
docker-compose down -v

# Remove all images
docker-compose down --rmi all -v

# Remove orphaned containers
docker-compose down --remove-orphans
```

### Rebuild from Scratch

```bash
# Complete teardown
docker-compose down -v --rmi all

# Rebuild everything
docker-compose build --no-cache
docker-compose up -d

# Reinstall dependencies
docker-compose exec app composer install
docker-compose exec app php artisan key:generate
docker-compose exec app php artisan migrate
```

## Performance Tips

1. **Use Docker Volume for node_modules**: Already configured in docker-compose.yml
2. **Allocate More RAM**: Increase Docker Desktop memory to 4GB+
3. **Enable File Sharing**: Ensure project directory is in Docker's file sharing settings
4. **Use SSD**: Docker works best on SSD storage
5. **Disable Antivirus Scanning**: For Docker directories (if safe to do so)

## Additional Resources

- [Laravel Documentation](https://laravel.com/docs)
- [Laravel Horizon Documentation](https://laravel.com/docs/horizon)
- [Vite Documentation](https://vitejs.dev)
- [LocalStack Documentation](https://docs.localstack.cloud)
- [Docker Compose Documentation](https://docs.docker.com/compose)

## Support

For issues specific to this Docker setup, check:
1. Container logs: `docker-compose logs [service-name]`
2. Container status: `docker-compose ps`
3. Resource usage: `docker stats`

For Laravel-specific issues, check:
- `storage/logs/laravel.log`
- Horizon dashboard: http://localhost/horizon