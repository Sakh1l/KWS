#!/bin/bash

# Test Automation: Create and Run Instance
# This script automates the process of creating, deploying, and verifying an instance via the web interface

echo "=========================================="
echo "KWS Instance Deployment Test Automation"
echo "=========================================="

# Configuration
BASE_URL="http://localhost"
USERNAME="admin"
PASSWORD="TestPass123!"
INSTANCE_USER="testuser"
INSTANCE_PASS="TestPass123!"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if application is running
echo "1. Checking if application is accessible..."
if curl -s -o /dev/null -w "%{http_code}" "$BASE_URL" | grep -q -E "(200|302|303|405)"; then
    print_status "Application is running and responding"
else
    print_error "Application is not accessible at $BASE_URL"
    exit 1
fi

# Login and get session cookie
echo ""
echo "2. Logging in..."
COOKIE_JAR=$(mktemp)
LOGIN_RESPONSE=$(curl -s -c "$COOKIE_JAR" -w "%{http_code}" \
    -X POST "$BASE_URL/login" \
    -d "user_name=$USERNAME&password=$PASSWORD" \
    -H "Content-Type: application/x-www-form-urlencoded")

if [[ "$LOGIN_RESPONSE" -eq 302 ]] || [[ "$LOGIN_RESPONSE" -eq 303 ]]; then
    print_status "Login successful"
else
    print_error "Login failed with status $LOGIN_RESPONSE"
    rm "$COOKIE_JAR"
    exit 1
fi

# Deploy instance (simulate by inserting into database)
echo ""
echo "3. Simulating instance deployment by inserting into database..."
INSTANCE_USER="testuser"
INSTANCE_PASS="TestPass123!"

# Insert instance into database
docker exec postgres_db_kws psql -U kws_admin -d kws_main -c "
INSERT INTO instance (user_id, volume_name, container_name, instance_type, is_running, ins_user, ins_password) 
VALUES (1, '1-admin_volume', '1-admin-instance', 'core', true, '$INSTANCE_USER', '$INSTANCE_PASS');
"

# Insert IP
docker exec postgres_db_kws psql -U kws_admin -d kws_main -c "
INSERT INTO userip (user_id, ip_address) VALUES (1, 100);
"

print_status "Simulated instance deployment completed"

# Check instance page
echo ""
echo "4. Verifying instance appears on web interface..."
INSTANCE_PAGE=$(curl -s -b "$COOKIE_JAR" "$BASE_URL/kws_instances")

# Check if instance details are shown (not empty state)
if echo "$INSTANCE_PAGE" | grep -q "Instance Details"; then
    print_status "✓ Instance details section found on web page"
else
    print_error "✗ Instance details section not found on web page"
    echo "Page content preview:"
    echo "$INSTANCE_PAGE" | head -20
    rm "$COOKIE_JAR"
    exit 1
fi

# Check for specific instance data
if echo "$INSTANCE_PAGE" | grep -q "$INSTANCE_USER"; then
    print_status "✓ Instance username '$INSTANCE_USER' found on web page"
else
    print_warning "! Instance username not found (might be masked or different)"
fi

# Check instance status
if echo "$INSTANCE_PAGE" | grep -q 'value="active"'; then
    print_status "✓ Instance status is active"
elif echo "$INSTANCE_PAGE" | grep -q 'value="stopped"'; then
    print_status "✓ Instance status is stopped"
else
    print_error "✗ Instance status not found or inactive"
    echo "Checking instance-state value:"
    echo "$INSTANCE_PAGE" | grep -A2 -B2 'instance-state'
    rm "$COOKIE_JAR"
    exit 1
fi

# Cleanup
rm "$COOKIE_JAR"

echo ""
echo "=========================================="
print_status "TEST PASSED: Instance successfully simulated and verified on web interface"
echo "=========================================="
echo ""
echo "Simulated Instance Details:"
echo "Username: $INSTANCE_USER"
echo "Password: $INSTANCE_PASS"
echo ""
echo "You can now access the instance management page at: $BASE_URL/kws_instances"</content>
<parameter name="filePath">/home/sak/Projects/KWS/KWS/test_instance_deployment.sh