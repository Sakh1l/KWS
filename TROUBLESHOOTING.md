# KWS Troubleshooting Guide

## Critical Issue Found: Missing .env File

### Root Cause
The `.env` file was **never created**. You only have `.env.example` which is a template.

Docker Compose requires the actual `.env` file to:
1. Load environment variables into containers
2. Substitute `${VARIABLE}` placeholders in `compose.yaml`

Without `.env`, all services fail because they can't connect to each other.

---

## Complete Fix (Step-by-Step)

### Step 1: Create .env File

```bash
# Copy the example file
cp .env.example .env

# Edit with your actual values
nano .env
```

### Step 2: Configure Required Values

**Minimum required changes in `.env`:**

```bash
# Generate WireGuard key
wg genkey
# Copy the output and paste it in .env as WG_PRIVATE_KEY

# For Gmail (optional for now, needed for user verification)
# Get app password from: https://myaccount.google.com/apppasswords
GMAIL_APP_PASSWORD=your_actual_app_password
GMAIL_ADDRESS=your_email@gmail.com
```

**All other values can stay as-is for development.**

### Step 3: Verify Configuration

Run the diagnostic script:

```bash
chmod +x test-env.sh
./test-env.sh
```

This will check:
- ✓ .env file exists
- ✓ All required variables are set
- ✓ No placeholder values remain
- ✓ Docker Compose config is valid
- ✓ Containers are running and healthy

### Step 4: Start Services

```bash
# Stop any existing containers
docker compose down

# Remove old volumes (optional, only if you want a clean start)
# make dv

# Start all services
make up
```

### Step 5: Verify Services Are Running

```bash
# Check container status
docker ps

# You should see all containers running:
# - postgres_db_kws (healthy)
# - redis_db_kws (healthy)
# - mq_q_kws (healthy)
# - postgres.kws.services (healthy)
# - kws_gateway (running)
# - nginx_proxy (running)
```

### Step 6: Run Database Migrations

```bash
# In a new terminal (while services are running)
make migrate_up
```

---

## What Was Fixed in compose.yaml

### Issue: Port Mapping Mismatch

**Problem**: Services were mapping ports incorrectly.

**Before** (WRONG):
```yaml
ports:
  - "127.0.0.1:${MQ_SERVER_PORT}:${MQ_SERVER_PORT}"  # Maps 5672:5672 inside container
```

**After** (CORRECT):
```yaml
ports:
  - "127.0.0.1:${MQ_SERVER_PORT}:5672"  # Maps host port to container's default port
```

**Why this matters**:
- RabbitMQ always listens on port **5672** inside the container
- PostgreSQL always listens on port **5432** inside the container  
- Redis always listens on port **6379** inside the container
- The left side (`${MQ_SERVER_PORT}`) is the **host** port
- The right side (e.g., `5672`) is the **container** port

### Fixed Services:
1. ✅ `postgres`: `${DB_PORT}:5432`
2. ✅ `rabbitmq`: `${MQ_SERVER_PORT}:5672` and `${MQ_UI_PORT}:15672`
3. ✅ `redis`: `${REDIS_PORT}:6379`

---

## Understanding the Architecture

### Network Mode: Host

`kws_gateway` uses `network_mode: "host"` which means:
- It shares the host's network stack
- It connects to services via `localhost:PORT`
- Other services must expose ports to `127.0.0.1` (localhost)

### Why Services Failed

1. **No .env file** → Docker Compose couldn't load variables
2. **Port mapping wrong** → Even with .env, ports wouldn't match
3. **kws_gateway started too early** → Before RabbitMQ was ready (fixed with health checks)

---

## Testing Environment Variables

### Test 1: Check .env File

```bash
# Verify file exists
ls -la .env

# Check contents (without showing passwords)
grep -E "^[A-Z]" .env | grep -v PASSWORD
```

### Test 2: Test Docker Compose Variable Substitution

```bash
# See what Docker Compose will use
docker compose config | grep -A5 "environment:"
```

### Test 3: Check Variables Inside Container

```bash
# Start services
docker compose up -d

# Check environment variables in kws_gateway
docker exec kws_gateway env | grep -E "MQ_|DB_|REDIS_"
```

### Test 4: Test RabbitMQ Connection

```bash
# Check RabbitMQ is running
docker exec mq_q_kws rabbitmqctl status

# Test connection from host
nc -zv localhost 5672

# Or use telnet
telnet localhost 5672
```

---

## Common Errors and Solutions

### Error: "Cannot load .env variables into the OS"

**Cause**: `.env` file doesn't exist

**Solution**:
```bash
cp .env.example .env
nano .env  # Configure values
docker compose down && make up
```

---

### Error: "Failed to connect to rabbitmq"

**Cause 1**: RabbitMQ not started yet

**Solution**:
```bash
# Wait for RabbitMQ to be healthy
docker ps | grep mq_q_kws

# Check logs
docker logs mq_q_kws | tail -20

# Look for: "Server startup complete"

# Restart kws_gateway
docker restart kws_gateway
```

**Cause 2**: Port mapping incorrect

**Solution**: Use the fixed `compose.yaml` (already done)

**Cause 3**: Wrong MQ_HOST value

**Solution**: Ensure `.env` has:
```bash
MQ_HOST=localhost  # NOT 127.0.0.1, NOT mq_q_kws
```

---

### Error: "dial tcp: lookup mq_q_kws: no such host"

**Cause**: `MQ_HOST` is set to container name instead of `localhost`

**Solution**: In `.env`, change:
```bash
MQ_HOST=localhost  # NOT mq_q_kws
```

This is because `kws_gateway` uses `network_mode: "host"` and connects via localhost.

---

### Error: nginx SSL certificate not found

**Cause**: Running in development without SSL

**Solution**: Use development configs (already created):
```bash
cd nginx/conf.d/
mv 00-default.conf 00-default.conf.prod
mv main.conf main.conf.prod
mv 00-default-dev.conf 00-default.conf
mv main-dev.conf main.conf
cd ../..
docker compose restart nginx_proxy
```

---

## Verification Checklist

Before reporting issues, verify:

- [ ] `.env` file exists in root directory
- [ ] All placeholder values in `.env` are replaced
- [ ] `./test-env.sh` passes all checks
- [ ] `docker compose config` runs without errors
- [ ] All containers show "healthy" status
- [ ] RabbitMQ logs show "Server startup complete"
- [ ] Can access RabbitMQ UI at http://localhost:15672
- [ ] `kws_gateway` logs don't show connection errors

---

## Quick Start (Clean Installation)

```bash
# 1. Create .env
cp .env.example .env
nano .env  # Configure all values

# 2. Generate WireGuard key
wg genkey  # Copy output to .env

# 3. Configure nginx for development
cd nginx/conf.d/
mv 00-default.conf 00-default.conf.prod
mv main.conf main.conf.prod
mv 00-default-dev.conf 00-default.conf
mv main-dev.conf main.conf
cd ../..

# 4. Test configuration
./test-env.sh

# 5. Start services
docker compose down
make up

# 6. Run migrations (in new terminal)
make migrate_up

# 7. Access the application
# Open browser: http://localhost:8080/kws_register
```

---

## Getting Help

If you're still having issues:

1. Run `./test-env.sh` and share the output
2. Run `docker compose logs kws_gateway` and share the last 50 lines
3. Run `docker ps` and share the output
4. Share your `.env` file (remove passwords first!)

---

## Files Created/Modified

1. ✅ `.env` - Created from `.env.example`
2. ✅ `compose.yaml` - Fixed port mappings and health checks
3. ✅ `test-env.sh` - Diagnostic script
4. ✅ `nginx/conf.d/*-dev.conf` - Development configs without SSL
5. ✅ `src/internal/env.go` - Made .env loading non-fatal
6. ✅ `Makefile` - Added retry logic for bridge attachment
7. ✅ `SETUP.md` - Updated with troubleshooting
8. ✅ `TROUBLESHOOTING.md` - This file

---

**Next Step**: Run `./test-env.sh` to verify your setup!
