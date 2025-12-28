#!/bin/bash

echo "=========================================="
echo "Fixing network access for 192.168.1.90"
echo "=========================================="

STATIC_IP="192.168.1.90"
NGINX_CONF="./nginx/conf.d/main-dev.conf"

echo ""
echo "1. Checking current nginx configuration..."
cat "$NGINX_CONF"

echo ""
echo "2. Backing up current configuration..."
cp "$NGINX_CONF" "$NGINX_CONF.backup.$(date +%Y%m%d_%H%M%S)"
echo "✓ Backup created"

echo ""
echo "3. Updating server_name to include $STATIC_IP..."

# Update the server_name line to include the static IP
sed -i "s/server_name localhost 127.0.0.1/server_name localhost 127.0.0.1 $STATIC_IP/" "$NGINX_CONF"

echo "✓ Configuration updated"

echo ""
echo "4. New configuration:"
cat "$NGINX_CONF"

echo ""
echo "5. Testing nginx configuration..."
docker compose exec nginx nginx -t

if [ $? -eq 0 ]; then
    echo "✓ Nginx configuration is valid"
    
    echo ""
    echo "6. Reloading nginx..."
    docker compose exec nginx nginx -s reload
    
    echo "✓ Nginx reloaded"
    
    echo ""
    echo "=========================================="
    echo "Testing access..."
    echo "=========================================="
    
    echo ""
    echo "Testing localhost:"
    curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://localhost
    
    echo ""
    echo "Testing $STATIC_IP:"
    curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://$STATIC_IP
    
    echo ""
    echo "=========================================="
    echo "Done!"
    echo "=========================================="
    echo ""
    echo "Try accessing from your browser:"
    echo "  http://$STATIC_IP"
    
else
    echo "✗ Nginx configuration test failed"
    echo "Restoring backup..."
    mv "$NGINX_CONF.backup.$(date +%Y%m%d_%H%M%S)" "$NGINX_CONF"
    exit 1
fi
