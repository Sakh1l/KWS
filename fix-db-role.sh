#!/bin/bash

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
else
    echo "Error: .env file not found"
    exit 1
fi

echo "==========================================
Fixing PostgreSQL service_admin role
=========================================="

echo "Current configuration:"
echo "  User: ${PG_SERVICE_USERNAME}"
echo "  Database: ${PG_SERVICE_DB}"
echo "  Host: ${PG_SERVICE_HOST}"
echo ""

# The issue is that postgres_service should create the user automatically
# but it seems the data volume already exists with wrong configuration
# We need to recreate it

echo "Stopping all services..."
docker compose down

echo "Removing old postgres_service volume to start fresh..."
docker volume rm kws_postgres_db_service_data 2>/dev/null || true

echo "Starting postgres_service with fresh database..."
docker compose up -d postgres_service

echo "Waiting for PostgreSQL to initialize (this may take 20-30 seconds)..."
sleep 15

# Check if it's ready
for i in {1..20}; do
    if docker compose exec -T postgres_service pg_isready -U ${PG_SERVICE_USERNAME} -d ${PG_SERVICE_DB} > /dev/null 2>&1; then
        echo "✓ PostgreSQL is ready!"
        break
    fi
    echo "Waiting for initialization... (attempt $i/20)"
    sleep 3
done

# Verify the user and database exist
echo ""
echo "Verifying configuration..."
if docker compose exec -T postgres_service psql -U ${PG_SERVICE_USERNAME} -d ${PG_SERVICE_DB} -c "SELECT version();" > /dev/null 2>&1; then
    echo "✓ Successfully connected to database as ${PG_SERVICE_USERNAME}"
    echo "✓ Database ${PG_SERVICE_DB} exists"
    
    # Show the user info
    echo ""
    echo "User details:"
    docker compose exec -T postgres_service psql -U ${PG_SERVICE_USERNAME} -d ${PG_SERVICE_DB} -c "\du ${PG_SERVICE_USERNAME}"
else
    echo "✗ Failed to connect to database"
    echo ""
    echo "Checking logs..."
    docker compose logs --tail=50 postgres_service
    docker compose down
    exit 1
fi

# Stop services
echo ""
echo "Stopping services..."
docker compose down

# Start all services
echo "Starting all services..."
docker compose up -d

echo "
==========================================
Done! Checking status...
=========================================="

sleep 5
docker compose ps

echo "
To view logs, run: docker compose logs -f kws_gateway"
