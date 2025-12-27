#!/bin/bash

# KWS Environment Variables Test Script
# This script verifies that all required environment variables are properly configured

set -e

echo "=========================================="
echo "KWS Environment Variables Test"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0

# Check if .env file exists
echo "1. Checking .env file..."
if [ ! -f .env ]; then
    echo -e "${RED}✗ FAIL: .env file not found in root directory${NC}"
    echo "  Solution: cp .env.example .env && nano .env"
    ERRORS=$((ERRORS + 1))
else
    echo -e "${GREEN}✓ PASS: .env file exists${NC}"
fi
echo ""

# Load .env file
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Test required variables
echo "2. Checking required environment variables..."

check_var() {
    local var_name=$1
    local var_value="${!var_name}"
    
    if [ -z "$var_value" ]; then
        echo -e "${RED}✗ FAIL: $var_name is not set${NC}"
        ERRORS=$((ERRORS + 1))
        return 1
    elif [[ "$var_value" == *"your_"* ]] || [[ "$var_value" == *"example"* ]]; then
        echo -e "${YELLOW}⚠ WARN: $var_name still has placeholder value: $var_value${NC}"
        ERRORS=$((ERRORS + 1))
        return 1
    else
        echo -e "${GREEN}✓ PASS: $var_name is set${NC}"
        return 0
    fi
}

# Main Database
echo ""
echo "Main Database (PostgreSQL):"
check_var "DB_USERNAME"
check_var "DB_PASSWORD"
check_var "DB_DBNAME"
check_var "DB_HOST"
check_var "DB_PORT"

# Redis
echo ""
echo "Redis:"
check_var "REDIS_HOST"
check_var "REDIS_PORT"
check_var "REDIS_PASSWORD"

# RabbitMQ
echo ""
echo "RabbitMQ:"
check_var "MQ_USER"
check_var "MQ_PASSWORD"
check_var "MQ_SERVER_PORT"
check_var "MQ_UI_PORT"
check_var "MQ_HOST"

# WireGuard
echo ""
echo "WireGuard:"
check_var "WG_PRIVATE_KEY"

# Gmail
echo ""
echo "Gmail:"
check_var "GMAIL_APP_PASSWORD"
check_var "GMAIL_ADDRESS"

# Service Database
echo ""
echo "Service Database (PostgreSQL):"
check_var "PG_SERVICE_USERNAME"
check_var "PG_SERVICE_PASSWORD"
check_var "PG_SERVICE_HOST"
check_var "PG_SERVICE_PORT"
check_var "PG_SERVICE_DB"

# Environment
echo ""
echo "Environment:"
check_var "ENV"

echo ""
echo "=========================================="
echo "3. Testing Docker Compose configuration..."
echo "=========================================="
echo ""

# Test if docker compose can parse the file
if docker compose config > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS: docker compose config is valid${NC}"
else
    echo -e "${RED}✗ FAIL: docker compose config has errors${NC}"
    docker compose config
    ERRORS=$((ERRORS + 1))
fi

echo ""
echo "=========================================="
echo "4. Checking running containers..."
echo "=========================================="
echo ""

CONTAINERS=("postgres_db_kws" "redis_db_kws" "mq_q_kws" "postgres.kws.services" "kws_gateway")

for container in "${CONTAINERS[@]}"; do
    if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        STATUS=$(docker inspect --format='{{.State.Status}}' "$container")
        HEALTH=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "none")
        
        if [ "$STATUS" = "running" ]; then
            if [ "$HEALTH" = "healthy" ] || [ "$HEALTH" = "none" ]; then
                echo -e "${GREEN}✓ $container: running ($HEALTH)${NC}"
            else
                echo -e "${YELLOW}⚠ $container: running but $HEALTH${NC}"
            fi
        else
            echo -e "${RED}✗ $container: $STATUS${NC}"
            ERRORS=$((ERRORS + 1))
        fi
    else
        echo -e "${RED}✗ $container: not found${NC}"
        ERRORS=$((ERRORS + 1))
    fi
done

echo ""
echo "=========================================="
echo "5. Testing RabbitMQ connection..."
echo "=========================================="
echo ""

if docker ps --format '{{.Names}}' | grep -q "^mq_q_kws$"; then
    echo "Checking RabbitMQ status..."
    if docker exec mq_q_kws rabbitmqctl status > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS: RabbitMQ is responding${NC}"
        
        # Test connection from host
        echo ""
        echo "Testing connection to RabbitMQ from host..."
        if command -v nc &> /dev/null; then
            if nc -zv localhost ${MQ_SERVER_PORT:-5672} 2>&1 | grep -q succeeded; then
                echo -e "${GREEN}✓ PASS: Can connect to RabbitMQ port${NC}"
            else
                echo -e "${RED}✗ FAIL: Cannot connect to RabbitMQ port${NC}"
                ERRORS=$((ERRORS + 1))
            fi
        else
            echo -e "${YELLOW}⚠ SKIP: netcat not installed, cannot test port${NC}"
        fi
    else
        echo -e "${RED}✗ FAIL: RabbitMQ is not responding${NC}"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo -e "${RED}✗ FAIL: RabbitMQ container not running${NC}"
    ERRORS=$((ERRORS + 1))
fi

echo ""
echo "=========================================="
echo "Summary"
echo "=========================================="
echo ""

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed! Environment is properly configured.${NC}"
    exit 0
else
    echo -e "${RED}✗ Found $ERRORS error(s). Please fix the issues above.${NC}"
    echo ""
    echo "Common fixes:"
    echo "1. Create .env file: cp .env.example .env"
    echo "2. Edit .env with real values: nano .env"
    echo "3. Start services: docker compose down && make up"
    exit 1
fi
