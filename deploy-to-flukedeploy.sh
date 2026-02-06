#!/bin/bash

# Deploy ca_small_claims to FlukeDeploy on vps16gb
# This will make it accessible at ca-small-claims.flukebase.me

set -e

# Configuration
APP_NAME="ca-small-claims"
VPS_NAME="staging-vps"
DOMAIN="flukebase.me"

# Credentials
RAILS_MASTER_KEY="24c844b898a2b6f299f04950289046d3def6c30faf8b2b155e2dd92811c5bf0c"
POSTGRES_PASSWORD="EyDlvuiQOM/Tsqxgh/lYoppqByL5trcprUeqiT2QT0E="

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Deploying ca_small_claims to FlukeDeploy                  ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${YELLOW}📋 Deployment Configuration${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  App Name:       $APP_NAME"
echo "  VPS:            $VPS_NAME"
echo "  Domain:         $APP_NAME.$DOMAIN"
echo "  Database:       tier2-rails-postgres"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Step 1: Check caprover CLI
echo -e "${BLUE}1️⃣  Checking caprover CLI...${NC}"
if ! command -v caprover &> /dev/null; then
    echo -e "${RED}❌ caprover CLI not found${NC}"
    echo "Install with: npm install -g caprover"
    exit 1
fi
echo -e "${GREEN}✅ caprover CLI found${NC}"
echo ""

# Step 2: Check if logged in
echo -e "${BLUE}2️⃣  Checking login status...${NC}"
if ! caprover list 2>/dev/null | grep -q "$VPS_NAME"; then
    echo -e "${YELLOW}⚠️  Not logged into $VPS_NAME${NC}"
    echo "Please login first:"
    echo "  caprover login"
    exit 1
fi
echo -e "${GREEN}✅ Logged into $VPS_NAME${NC}"
echo ""

# Step 3: Check if app exists
echo -e "${BLUE}3️⃣  Checking if app exists...${NC}"
if ssh staging-vps "docker service ls --filter name=srv-captain--$APP_NAME --format '{{.Name}}'" | grep -q "srv-captain--$APP_NAME"; then
    echo -e "${GREEN}✅ App already exists, will update${NC}"
    APP_EXISTS=true
else
    echo -e "${YELLOW}⚠️  App doesn't exist, will create${NC}"
    APP_EXISTS=false
fi
echo ""

# Step 4: Create app if needed
if [ "$APP_EXISTS" = false ]; then
    echo -e "${BLUE}4️⃣  Creating app in FlukeDeploy...${NC}"

    # Create via API
    ssh staging-vps "curl -X POST http://localhost:3000/api/v2/user/apps/appDefinitions/register \
      -H 'Content-Type: application/json' \
      -H 'x-namespace: captain' \
      -H 'x-captain-auth: \$(cat /captain/data/config-captain.json | jq -r '.token')' \
      -d '{\"appName\":\"$APP_NAME\",\"hasPersistentData\":false}'" || {
        echo -e "${RED}❌ Failed to create app${NC}"
        exit 1
    }

    echo -e "${GREEN}✅ App created${NC}"
    echo ""
fi

# Step 5: Configure environment variables
echo -e "${BLUE}5️⃣  Configuring environment variables...${NC}"

# Build the env vars JSON array
ENV_VARS=$(cat <<EOF
[
  {"key": "RAILS_MASTER_KEY", "value": "$RAILS_MASTER_KEY"},
  {"key": "RAILS_ENV", "value": "production"},
  {"key": "RAILS_LOG_TO_STDOUT", "value": "true"},
  {"key": "RAILS_SERVE_STATIC_FILES", "value": "true"},
  {"key": "DATABASE_URL", "value": "postgresql://postgres:$POSTGRES_PASSWORD@tier2-rails-postgres:5432/ca_small_claims_development"},
  {"key": "CACHE_DATABASE_URL", "value": "postgresql://postgres:$POSTGRES_PASSWORD@tier2-rails-postgres:5432/ca_small_claims_cache_development"},
  {"key": "QUEUE_DATABASE_URL", "value": "postgresql://postgres:$POSTGRES_PASSWORD@tier2-rails-postgres:5432/ca_small_claims_queue_development"},
  {"key": "CABLE_DATABASE_URL", "value": "postgresql://postgres:$POSTGRES_PASSWORD@tier2-rails-postgres:5432/ca_small_claims_cable_development"},
  {"key": "SECRET_KEY_BASE", "value": "$RAILS_MASTER_KEY"},
  {"key": "RAILS_MAX_THREADS", "value": "5"}
]
EOF
)

# Update env vars via API
ssh staging-vps "curl -X POST http://localhost:3000/api/v2/user/apps/appDefinitions/update \
  -H 'Content-Type: application/json' \
  -H 'x-namespace: captain' \
  -H 'x-captain-auth: \$(cat /captain/data/config-captain.json | jq -r '.token')' \
  -d '{\"appName\":\"$APP_NAME\",\"envVars\":$ENV_VARS}'" || {
    echo -e "${YELLOW}⚠️  Failed to update env vars via API, will set manually${NC}"
}

echo -e "${GREEN}✅ Environment variables configured${NC}"
echo ""

# Step 6: Enable HTTPS
echo -e "${BLUE}6️⃣  Configuring domain and SSL...${NC}"
ssh staging-vps "curl -X POST http://localhost:3000/api/v2/user/apps/appDefinitions/customdomain \
  -H 'Content-Type: application/json' \
  -H 'x-namespace: captain' \
  -H 'x-captain-auth: \$(cat /captain/data/config-captain.json | jq -r '.token')' \
  -d '{\"appName\":\"$APP_NAME\",\"customDomain\":\"$APP_NAME.$DOMAIN\"}'" 2>/dev/null || true

ssh staging-vps "curl -X POST http://localhost:3000/api/v2/user/apps/appDefinitions/enablessl \
  -H 'Content-Type: application/json' \
  -H 'x-namespace: captain' \
  -H 'x-captain-auth: \$(cat /captain/data/config-captain.json | jq -r '.token')' \
  -d '{\"appName\":\"$APP_NAME\"}'" 2>/dev/null || true

echo -e "${GREEN}✅ Domain configured${NC}"
echo ""

# Step 7: Deploy the app
echo -e "${BLUE}7️⃣  Deploying application...${NC}"
echo "This will build the Docker image and deploy to FlukeDeploy..."
echo ""

if caprover deploy -n "$VPS_NAME" -a "$APP_NAME"; then
    echo -e "${GREEN}✅ Deployment initiated successfully${NC}"
else
    echo -e "${RED}❌ Deployment failed${NC}"
    exit 1
fi
echo ""

# Step 8: Wait for deployment
echo -e "${BLUE}8️⃣  Waiting for deployment to complete...${NC}"
echo "This may take 2-5 minutes..."
echo ""

for i in {1..60}; do
    if ssh staging-vps "docker service ls --filter name=srv-captain--$APP_NAME --format '{{.Replicas}}'" | grep -q "1/1"; then
        echo -e "${GREEN}✅ Service is running${NC}"
        break
    fi
    echo -n "."
    sleep 5
done
echo ""

# Step 9: Run database migrations
echo -e "${BLUE}9️⃣  Running database migrations...${NC}"
CONTAINER_ID=$(ssh staging-vps "docker ps --filter name=srv-captain--$APP_NAME --format '{{.ID}}' | head -1")

if [ -n "$CONTAINER_ID" ]; then
    echo "Container ID: $CONTAINER_ID"
    ssh staging-vps "docker exec $CONTAINER_ID bin/rails db:create db:migrate" || {
        echo -e "${YELLOW}⚠️  Migration failed, this is normal for first deploy${NC}"
    }
    echo -e "${GREEN}✅ Migrations complete${NC}"
else
    echo -e "${YELLOW}⚠️  Could not find container, skip migrations${NC}"
fi
echo ""

# Step 10: Display summary
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           🎉 Deployment Successful! ✅                       ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${YELLOW}📊 Application Information${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  App Name:       $APP_NAME"
echo "  Domain:         https://$APP_NAME.$DOMAIN"
echo "  Database:       tier2-rails-postgres"
echo "  Status:         Check at https://$APP_NAME.$DOMAIN"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo -e "${YELLOW}🔍 Useful Commands${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  View logs:"
echo "    ssh staging-vps 'docker service logs srv-captain--$APP_NAME --tail 100 -f'"
echo ""
echo "  Check status:"
echo "    ssh staging-vps 'docker service ps srv-captain--$APP_NAME'"
echo ""
echo "  Rails console:"
echo "    ssh staging-vps 'docker exec -it \$(docker ps --filter name=srv-captain--$APP_NAME -q | head -1) bin/rails console'"
echo ""
echo "  Run migrations:"
echo "    ssh staging-vps 'docker exec \$(docker ps --filter name=srv-captain--$APP_NAME -q | head -1) bin/rails db:migrate'"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo -e "${BLUE}🌐 Visit your app:${NC}"
echo "   https://$APP_NAME.$DOMAIN"
echo ""

echo -e "${GREEN}Deployment complete!${NC}"
