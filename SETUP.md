# KWS Setup Guide

Complete guide to set up and run KWS on your server after cloning the repository.

---

## Prerequisites

### System Requirements
- **OS**: Ubuntu 20.04+ or Debian-based Linux
- **RAM**: Minimum 4GB (8GB+ recommended)
- **Storage**: 20GB+ free space
- **Network**: Static IP or domain name (for production)
- **Privileges**: Root or sudo access

### Required Software

Install the following before proceeding:

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install Docker and Docker Compose
sudo apt install -y docker.io docker-compose-v2
sudo systemctl enable --now docker
sudo usermod -aG docker $USER

# Install LXD
sudo snap install lxd
sudo lxd init --auto
sudo usermod -aG lxd $USER

# Install WireGuard
sudo apt install -y wireguard wireguard-tools

# Install golang-migrate (for database migrations)
curl -L https://github.com/golang-migrate/migrate/releases/download/v4.17.0/migrate.linux-amd64.tar.gz | tar xvz
sudo mv migrate /usr/local/bin/

# Install uuid-runtime (required by the application)
sudo apt install -y uuid-runtime

# Log out and back in for group changes to take effect
```

---

## Installation Steps

### 1. Clone the Repository

```bash
git clone https://github.com/20vikash/KWS.git
cd KWS
```

### 2. Configure Environment Variables

Copy the example environment file and edit it:

```bash
cp .env.example .env
nano .env  # or use your preferred editor
```

⚠️ **Important**: The `.env` file must be in the **root directory** of the project (same level as `compose.yaml`), not inside the `src/` directory.

#### Required Configuration

**Main Database (PostgreSQL)**
```env
DB_USERNAME=kws_admin
DB_PASSWORD=your_secure_password_here
DB_DBNAME=kws_main
DB_HOST=localhost
DB_PORT=5432
```

**Redis Cache**
```env
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=your_redis_password_here
```

**RabbitMQ Message Queue**
```env
MQ_USER=kws_mq_user
MQ_PASSWORD=your_mq_password_here
MQ_SERVER_PORT=5672
MQ_UI_PORT=15672
MQ_HOST=localhost
```

**Gmail SMTP (for user verification emails)**
```env
GMAIL_APP_PASSWORD=your_gmail_app_password
GMAIL_ADDRESS=your_email@gmail.com
```

> **Note**: Generate a Gmail App Password at [Google Account Settings](https://myaccount.google.com/apppasswords)

**WireGuard VPN**
```bash
# Generate a WireGuard private key
wg genkey
```
Copy the output and add to `.env`:
```env
WG_PRIVATE_KEY=your_generated_private_key_here
```

**Service Database (PostgreSQL)**
```env
PG_SERVICE_USERNAME=pg_service_admin
PG_SERVICE_PASSWORD=your_pg_service_password
PG_SERVICE_HOST=localhost
PG_SERVICE_PORT=5433
PG_SERVICE_DB=kws_services
```

**Environment Mode**
```env
ENV=development  # Use 'production' for production deployment
```

### 3. Set Up the Utility Script

Make the bridge attachment script executable:

```bash
chmod +x util/attach_to_bridge
sudo cp util/attach_to_bridge /usr/local/bin/
```

### 4. Configure LXD

Initialize LXD with default settings if not already done:

```bash
sudo lxd init --auto
```

Verify LXD is running:

```bash
lxc list
```

### 5. Configure WireGuard

Create the WireGuard configuration directory:

```bash
sudo mkdir -p /etc/wireguard
```

The application will automatically configure the WireGuard interface on startup.

### 5.5. Configure Nginx for Development

For development (without SSL certificates), rename the SSL configs:

```bash
# Backup production configs
mv nginx/conf.d/00-default.conf nginx/conf.d/00-default.conf.prod
mv nginx/conf.d/main.conf nginx/conf.d/main.conf.prod

# Use development configs
mv nginx/conf.d/00-default-dev.conf nginx/conf.d/00-default.conf
mv nginx/conf.d/main-dev.conf nginx/conf.d/main.conf
```

> **Note**: For production with SSL, see the [Production Deployment](#production-deployment) section.

### 6. Start the Services

Start all Docker services:

```bash
make up
```

This will:
- Start PostgreSQL, Redis, RabbitMQ, Nginx
- Start the KWS gateway service
- Attach service containers to the bridge network
- Display logs

**Wait for all services to be healthy** (look for "ready to accept connections" messages).

Press `Ctrl+C` to stop following logs (services continue running in background).

### 7. Run Database Migrations

In a new terminal, run the migrations:

```bash
make migrate_up
```

Expected output:
```
1/u init (xxx.xxxs)
2/u init (xxx.xxxs)
...
```

### 8. Verify Installation

Check that all services are running:

```bash
docker ps
```

You should see containers:
- `postgres_db_kws`
- `redis_db_kws`
- `mq_q_kws`
- `nginx_proxy`
- `kws_gateway`
- `postgres.kws.services`
- `adminer.kws.services`
- `dnsmasq_kws`

### 9. Access the Platform

Open your browser and navigate to:

```
http://localhost:8080/kws_register
```

Or if you have a domain configured:

```
http://your-domain.com/kws_register
```

---

## Post-Installation

### Create Your First User

1. Navigate to the registration page
2. Fill in your details (use a valid email)
3. Check your email for the verification link
4. Click the verification link
5. Sign in at `/kws_signin`

### Deploy Your First Instance

1. After signing in, go to the home dashboard
2. Click "Deploy Instance"
3. Set a username and password for the container
4. Wait for deployment to complete
5. Access your instance via the provided URL

### Configure WireGuard Client

1. Go to "Devices" in the dashboard
2. Click "Register Device"
3. Download the WireGuard configuration file
4. Import it into your WireGuard client
5. Connect to access your instances privately

---

## Management Commands

### Start/Stop Services

```bash
# Start all services
make up

# Stop all services (keeps data)
make stop

# Start stopped services
make start

# Stop and remove containers (keeps data)
make down
```

### Database Management

```bash
# Create a new migration
make create_migration

# Run migrations
make migrate_up

# Rollback last N migrations
make migrate_down-N  # Replace N with number

# Rollback all migrations
make migrate_down-all
```

### Clean Up Data

```bash
# Remove main application volumes (PostgreSQL, Redis, RabbitMQ)
make dv

# Remove service volumes (Service PostgreSQL)
make dvs
```

⚠️ **Warning**: These commands will delete all data permanently.

### View Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f kws_gateway
docker compose logs -f postgres
docker compose logs -f rabbitmq
```

### Access RabbitMQ Management UI

```
http://localhost:15672
```

Login with credentials from `.env` (`MQ_USER` and `MQ_PASSWORD`)

---

## Production Deployment

### SSL/TLS Configuration

1. **Stop nginx temporarily** (Certbot needs port 80):
```bash
docker compose stop nginx_proxy
```

2. **Install Certbot**:
```bash
sudo apt install -y certbot python3-certbot-nginx
```

3. **Obtain SSL certificate**:
```bash
# For single domain
sudo certbot certonly --standalone -d your-domain.com

# For wildcard (requires DNS challenge)
sudo certbot certonly --manual --preferred-challenges dns -d your-domain.com -d *.your-domain.com
```

4. **Update nginx configs with your domain**:
```bash
# Restore production configs
cd nginx/conf.d/
mv 00-default.conf 00-default-dev.conf
mv main.conf main-dev.conf
mv 00-default.conf.prod 00-default.conf
mv main.conf.prod main.conf

# Update domain names
nano main.conf
# Replace all instances of kwscloud.in with your-domain.com
# Update certificate paths if needed

nano 00-default.conf
# Update certificate paths if needed

cd ../..
```

5. **Update `.env`**:
```env
ENV=production
```

6. **Restart services**:
```bash
make down && make up
```

7. **Set up certificate auto-renewal**:
```bash
# Test renewal
sudo certbot renew --dry-run

# Certbot automatically sets up a systemd timer for renewal
sudo systemctl status certbot.timer
```

### Firewall Configuration

```bash
# Allow HTTP and HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Allow WireGuard (default port)
sudo ufw allow 51820/udp

# Enable firewall
sudo ufw enable
```

### Domain Configuration

Update your DNS records to point to your server's IP:

```
A     @              your-server-ip
A     *              your-server-ip
```

---

## Troubleshooting

### kws_gateway: "Cannot load .env variables"

**Error**: `Cannot load .env variables into the OS`

**Cause**: The `.env` file is missing or in the wrong location.

**Solution**:
```bash
# Verify .env exists in root directory
ls -la .env

# If missing, create it
cp .env.example .env
nano .env  # Configure all required values

# Restart services
docker compose down
make up
```

### kws_gateway: "Failed to connect to rabbitmq"

**Error**: `Attempt mq connection: 1...10` followed by `Failed to connect to rabbitmq`

**Cause**: RabbitMQ takes time to initialize, and `kws_gateway` starts before it's ready.

**Solution 1: Wait and restart** (if services are already running)
```bash
# Check if RabbitMQ is healthy
docker ps | grep mq_q_kws

# Wait for RabbitMQ to be fully ready (look for "Server startup complete")
docker logs mq_q_kws

# Restart kws_gateway once RabbitMQ is ready
docker restart kws_gateway

# Follow logs
docker logs -f kws_gateway
```

**Solution 2: Use updated compose.yaml** (recommended)
The updated `compose.yaml` includes health checks that ensure services start in the correct order. If you're still having issues:

```bash
# Stop all services
docker compose down

# Start services (they will wait for health checks)
make up

# Services will start in order:
# 1. postgres, redis, rabbitmq, postgres_service (wait for healthy)
# 2. kws_gateway (starts only after all dependencies are healthy)
```

**Verify RabbitMQ is working**:
```bash
# Check RabbitMQ status
docker exec mq_q_kws rabbitmqctl status

# Access RabbitMQ Management UI
# Open browser: http://localhost:15672
# Login with MQ_USER and MQ_PASSWORD from .env
```

### nginx: SSL Certificate Error

**Error**: `cannot load certificate "/etc/letsencrypt/live/kwscloud.in-0001/fullchain.pem"`

**Cause**: SSL certificates don't exist (expected in development).

**Solution for Development**:
```bash
# Stop services
docker compose down

# Switch to development configs (no SSL)
cd nginx/conf.d/
mv 00-default.conf 00-default.conf.prod
mv main.conf main.conf.prod
mv 00-default-dev.conf 00-default.conf
mv main-dev.conf main.conf
cd ../..

# Restart services
make up
```

**Solution for Production**:
```bash
# Install SSL certificates first
sudo certbot certonly --standalone -d your-domain.com -d *.your-domain.com

# Update nginx configs with your domain
nano nginx/conf.d/main.conf
# Replace kwscloud.in with your-domain.com

# Restart services
docker compose down
make up
```

### Services Won't Start

**Check Docker status:**
```bash
sudo systemctl status docker
```

**Check logs:**
```bash
docker compose logs
```

**Restart Docker:**
```bash
sudo systemctl restart docker
make up
```

### Bridge Attachment Fails

**Error: "Container is not running or not found"**

This happens when the `attach_to_bridge` script runs before containers are fully started.

**Solution 1: Wait and retry**
```bash
# Stop the current attempt (Ctrl+C if logs are showing)
# Wait a few seconds, then run:
docker compose up -d
sleep 10
make start
```

**Solution 2: Manual attachment**
```bash
# Start containers without attachment
docker compose up -d

# Wait for containers to be running
docker ps | grep "postgres.kws.services\|adminer.kws.services\|dnsmasq_kws"

# Manually attach (after confirming they're running)
sudo attach_to_bridge postgres.kws.services lxdbr0 172.30.0.100/24
sudo attach_to_bridge adminer.kws.services lxdbr0 172.30.0.101/24
sudo attach_to_bridge dnsmasq_kws lxdbr0 172.30.0.102/24
```

**Solution 3: Check if containers are actually starting**
```bash
# View container status
docker compose ps

# Check specific container logs
docker compose logs postgres.kws.services
docker compose logs adminer.kws.services
docker compose logs dnsmasq_kws

# If containers are failing to start, check for port conflicts or configuration issues
```

### LXD Connection Issues

**Check LXD status:**
```bash
sudo systemctl status snap.lxd.daemon
```

**Verify socket permissions:**
```bash
ls -la /var/snap/lxd/common/lxd/unix.socket
```

**Restart LXD:**
```bash
sudo snap restart lxd
```

### WireGuard Interface Not Created

**Check kernel module:**
```bash
sudo modprobe wireguard
lsmod | grep wireguard
```

**Verify private key:**
```bash
# Ensure WG_PRIVATE_KEY in .env is valid
wg genkey  # Generate a new one if needed
```

### Database Migration Fails

**Check PostgreSQL is running:**
```bash
docker ps | grep postgres_db_kws
```

**Verify connection:**
```bash
docker exec -it postgres_db_kws psql -U $DB_USERNAME -d $DB_DBNAME
```

**Reset migrations (⚠️ deletes all data):**
```bash
make migrate_down-all
make dv
make up
# Wait for services to start
make migrate_up
```

### Port Already in Use

**Find process using port:**
```bash
sudo lsof -i :8080  # or other port
```

**Kill the process or change port in compose.yaml**

### Email Verification Not Working

**Verify Gmail credentials:**
- Ensure 2FA is enabled on your Google account
- Use an App Password, not your regular password
- Check `GMAIL_ADDRESS` and `GMAIL_APP_PASSWORD` in `.env`

**Check application logs:**
```bash
docker compose logs kws_gateway | grep -i mail
```

### Cannot Access Instances

**Check WireGuard connection:**
```bash
sudo wg show
```

**Verify IP allocation:**
```bash
docker exec -it redis_db_kws redis-cli -a $REDIS_PASSWORD
> KEYS *
```

**Check container status:**
```bash
lxc list
```

---

## Uninstallation

To completely remove KWS:

```bash
# Stop and remove containers
make down

# Remove volumes
make dv
make dvs

# Remove Docker networks
docker network rm kws_main kws_services

# Remove LXD containers
lxc list | grep instance | awk '{print $2}' | xargs -I {} lxc delete {} --force

# Remove WireGuard interface
sudo ip link delete wg0

# Remove project directory
cd ..
rm -rf KWS
```

---

## Getting Help

- **Troubleshooting**: See `TROUBLESHOOTING.md` for detailed diagnostics
- **Test Script**: Run `./test-env.sh` to verify your configuration
- **Issues**: [GitHub Issues](https://github.com/20vikash/KWS/issues)
- **Documentation**: See `readme.md` for feature overview
- **Logs**: Always check `docker compose logs` for errors

---

## Next Steps

After successful setup:

1. ✅ Register your first user account
2. ✅ Deploy a test instance
3. ✅ Configure WireGuard for private access
4. ✅ Set up a public domain for your app
5. ✅ Explore PostgreSQL service management
6. ✅ Invite team members or students

**Happy deploying! 🚀**
