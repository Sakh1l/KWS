#!/bin/bash

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
else
    echo "Error: .env file not found"
    exit 1
fi

echo "==========================================
Fixing nginx configuration for environment
=========================================="

echo "Current environment: ${ENV}"
echo ""

NGINX_CONF_DIR="./nginx/conf.d"

if [ "$ENV" = "dev" ] || [ "$ENV" = "development" ]; then
    echo "Setting up for DEVELOPMENT environment..."
    echo ""
    
    # Backup and remove production configs
    if [ -f "$NGINX_CONF_DIR/00-default.conf" ]; then
        mv "$NGINX_CONF_DIR/00-default.conf" "$NGINX_CONF_DIR/00-default.conf.backup"
        echo "✓ Backed up 00-default.conf (production)"
    fi
    
    if [ -f "$NGINX_CONF_DIR/main.conf" ]; then
        mv "$NGINX_CONF_DIR/main.conf" "$NGINX_CONF_DIR/main.conf.backup"
        echo "✓ Backed up main.conf (production)"
    fi
    
    echo "✓ Using development configs: 00-default-dev.conf and main-dev.conf"
    
elif [ "$ENV" = "prod" ] || [ "$ENV" = "production" ]; then
    echo "Setting up for PRODUCTION environment..."
    echo ""
    
    # Backup and remove development configs
    if [ -f "$NGINX_CONF_DIR/00-default-dev.conf" ]; then
        mv "$NGINX_CONF_DIR/00-default-dev.conf" "$NGINX_CONF_DIR/00-default-dev.conf.backup"
        echo "✓ Backed up 00-default-dev.conf (development)"
    fi
    
    if [ -f "$NGINX_CONF_DIR/main-dev.conf" ]; then
        mv "$NGINX_CONF_DIR/main-dev.conf" "$NGINX_CONF_DIR/main-dev.conf.backup"
        echo "✓ Backed up main-dev.conf (development)"
    fi
    
    echo "✓ Using production configs: 00-default.conf and main.conf"
    
else
    echo "⚠ Unknown environment: ${ENV}"
    echo "Please set ENV to either 'dev' or 'prod' in your .env file"
    exit 1
fi

echo ""
echo "Remaining active config files:"
ls -la "$NGINX_CONF_DIR"/*.conf 2>/dev/null || echo "No .conf files found"

echo ""
echo "Restarting nginx..."
docker compose restart nginx

echo ""
echo "Waiting for nginx to start..."
sleep 3

echo ""
echo "Checking nginx status..."
docker compose ps nginx

echo ""
echo "Recent nginx logs:"
docker compose logs --tail=20 nginx

echo ""
echo "==========================================
Done!
=========================================="
