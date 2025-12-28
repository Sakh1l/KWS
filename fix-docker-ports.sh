#!/bin/bash

echo "==========================================
Checking and fixing port configurations
=========================================="

echo "Current port mappings:"
docker compose ps --format "table {{.Name}}\t{{.Ports}}"

echo ""
echo "Checking compose.yaml nginx configuration..."
grep -A 15 "nginx:" compose.yaml | head -20

echo ""
echo "Issue identified:"
echo "- nginx needs port 80 exposed to host (0.0.0.0:80:80)"
echo "- nginx should proxy to kws_gateway:8080 (using Docker network name)"
echo ""

# Check if compose.yaml has nginx ports
if grep -A 10 "nginx:" compose.yaml | grep -q "ports:"; then
    echo "✓ nginx has ports section in compose.yaml"
    if grep -A 10 "nginx:" compose.yaml | grep -q "80:80"; then
        echo "✓ Port 80 is mapped"
    else
        echo "✗ Port 80 is NOT mapped to host"
        echo ""
        echo "You need to add to compose.yaml under nginx service:"
        echo "  ports:"
        echo "    - \"80:80\""
    fi
else
    echo "✗ nginx has NO ports section"
    echo ""
    echo "You need to add to compose.yaml under nginx service:"
    echo "  ports:"
    echo "    - \"80:80\""
fi

echo ""
echo "Checking if kws_gateway exposes port 8080..."
if docker compose exec -T kws_gateway netstat -tlnp 2>/dev/null | grep -q ":8080"; then
    echo "✓ kws_gateway is listening on port 8080"
else
    echo "⚠ Cannot verify if kws_gateway is listening on 8080"
    echo "  (This might be normal if netstat is not installed)"
fi

echo ""
echo "Checking nginx configuration for proxy_pass..."
if grep -r "proxy_pass.*127.0.0.1:8080" nginx/conf.d/*.conf; then
    echo ""
    echo "✗ Found proxy_pass using 127.0.0.1:8080"
    echo "  This should be changed to: http://kws_gateway:8080"
    echo "  (Use Docker service name instead of localhost)"
fi

echo ""
echo "==========================================
Recommended fixes:
==========================================
1. Update compose.yaml to expose nginx port 80
2. Update nginx config to use Docker service name
3. Restart services
"
