#!/bin/bash

echo "==========================================
Fixing nginx duplicate default_server issue
=========================================="

# Find nginx config directory
NGINX_DIR=""
if [ -d "nginx" ]; then
    NGINX_DIR="nginx"
elif [ -d "conf.d" ]; then
    NGINX_DIR="conf.d"
elif [ -d "nginx/conf.d" ]; then
    NGINX_DIR="nginx/conf.d"
fi

if [ -z "$NGINX_DIR" ]; then
    echo "Could not find nginx configuration directory."
    echo "Please run: find . -name '*.conf' -type f"
    exit 1
fi

echo "Found nginx config directory: $NGINX_DIR"
echo ""

# Find all .conf files with default_server
echo "Searching for default_server directives..."
grep -r "default_server" "$NGINX_DIR"/*.conf 2>/dev/null

echo ""
echo "Files with default_server:"
grep -l "default_server" "$NGINX_DIR"/*.conf 2>/dev/null

echo ""
echo "To fix this, you have two options:"
echo ""
echo "Option 1: Keep only ONE file with 'default_server' (recommended)"
echo "  - Edit the config files and remove 'default_server' from all but one"
echo ""
echo "Option 2: Remove the 00-default.conf file if it's not needed"
echo "  - This file is often a template/example file"
echo ""

# Check if 00-default.conf exists
if [ -f "$NGINX_DIR/00-default.conf" ]; then
    echo "Found 00-default.conf. Contents:"
    echo "---"
    cat "$NGINX_DIR/00-default.conf"
    echo "---"
    echo ""
    read -p "Do you want to remove 00-default.conf? (y/n): " response
    if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
        mv "$NGINX_DIR/00-default.conf" "$NGINX_DIR/00-default.conf.backup"
        echo "✓ Backed up and removed 00-default.conf"
        echo ""
        echo "Restarting nginx..."
        docker compose restart nginx
        echo ""
        echo "Check nginx logs:"
        docker compose logs nginx
    fi
fi
