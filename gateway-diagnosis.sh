#!/bin/bash

echo "=========================================="
echo "Diagnosing kws_gateway and nginx setup"
echo "=========================================="

echo ""
echo "1. Checking if kws_gateway container is running..."
if docker ps | grep -q kws_gateway; then
    echo "✓ kws_gateway is running"
else
    echo "✗ kws_gateway is NOT running"
    exit 1
fi

echo ""
echo "2. Checking kws_gateway logs for port/listen information..."
docker compose logs kws_gateway | grep -i "listen\|port\|start\|serving\|http" | tail -20

echo ""
echo "3. Checking if port 8080 is listening on host..."
if command -v netstat &> /dev/null; then
    sudo netstat -tlnp | grep :8080 || echo "Port 8080 is NOT listening"
elif command -v ss &> /dev/null; then
    sudo ss -tlnp | grep :8080 || echo "Port 8080 is NOT listening"
else
    echo "⚠ netstat/ss not available, checking with lsof..."
    if command -v lsof &> /dev/null; then
        sudo lsof -i :8080 || echo "Port 8080 is NOT listening"
    else
        echo "⚠ Cannot check port status (install net-tools or lsof)"
    fi
fi

echo ""
echo "4. Trying to access kws_gateway from host..."
if curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8080 > /tmp/gateway_status.txt 2>&1; then
    STATUS=$(cat /tmp/gateway_status.txt)
    if [ "$STATUS" = "000" ]; then
        echo "✗ Cannot connect to port 8080 (connection refused)"
    else
        echo "✓ Got HTTP response: $STATUS"
        echo ""
        echo "Response preview:"
        curl -s http://127.0.0.1:8080 | head -20
    fi
else
    echo "✗ Cannot connect to kws_gateway on port 8080"
fi

echo ""
echo "5. Checking nginx configuration..."
echo "Nginx proxy_pass configuration:"
grep -r "proxy_pass" nginx/conf.d/*.conf

echo ""
echo "6. Testing nginx access..."
NGINX_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1 2>&1)
echo "Nginx HTTP status: $NGINX_STATUS"

if [ "$NGINX_STATUS" = "502" ]; then
    echo "✗ Nginx returns 502 Bad Gateway - kws_gateway is not responding"
elif [ "$NGINX_STATUS" = "000" ]; then
    echo "✗ Cannot connect to nginx"
else
    echo "✓ Nginx is responding"
fi

echo ""
echo "7. Checking what kws_gateway process is running..."
docker compose exec -T kws_gateway ps aux | grep -v "PID\|ps aux\|grep" | head -10

echo ""
echo "=========================================="
echo "Summary & Recommendations"
echo "=========================================="

# Check if the Go app is actually starting a web server
if docker compose logs kws_gateway | grep -qi "listening\|serving\|started.*8080"; then
    echo "✓ kws_gateway appears to be starting a web server"
else
    echo "⚠ kws_gateway may not be starting a web server on port 8080"
    echo "  Check the Go application code to ensure it's listening on :8080"
    echo ""
    echo "  The application might need to bind to 0.0.0.0:8080 or :8080"
fi

rm -f /tmp/gateway_status.txt
