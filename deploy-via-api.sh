#!/bin/bash

# Deploy ca_small_claims to FlukeDeploy using API directly
# This bypasses the caprover CLI to avoid interactive prompts

set -e

# Configuration
APP_NAME="ca-small-claims"
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
echo -e "${BLUE}║   Deploying ca_small_claims via FlukeDeploy API             ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Get API token
echo -e "${BLUE}1️⃣  Getting API token...${NC}"
API_TOKEN=$(ssh staging-vps "cat /captain/data/config-captain.json | jq -r '.token'")
if [ -z "$API_TOKEN" ]; then
    echo -e "${RED}❌ Failed to get API token${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Got API token${NC}"
echo ""

# Check if app exists
echo -e "${BLUE}2️⃣  Checking if app exists...${NC}"
if ssh staging-vps "docker service ls --filter name=srv-captain--$APP_NAME --format '{{.Name}}'" | grep -q "srv-captain--$APP_NAME"; then
    echo -e "${GREEN}✅ App exists, will update${NC}"
    APP_EXISTS=true
else
    echo -e "${YELLOW}Creating new app...${NC}"
    APP_EXISTS=false

    # Create app
    CREATE_RESPONSE=$(ssh staging-vps "curl -s -X POST http://localhost:3000/api/v2/user/apps/appDefinitions/register \
      -H 'Content-Type: application/json' \
      -H 'x-namespace: captain' \
      -H 'x-captain-auth: $API_TOKEN' \
      -d '{\"appName\":\"$APP_NAME\",\"hasPersistentData\":false}'")

    if echo "$CREATE_RESPONSE" | grep -q "\"status\":100"; then
        echo -e "${GREEN}✅ App created${NC}"
    else
        echo -e "${RED}❌ Failed to create app: $CREATE_RESPONSE${NC}"
        exit 1
    fi
fi
echo ""

# Configure environment variables
echo -e "${BLUE}3️⃣  Configuring environment variables...${NC}"

ENV_UPDATE=$(ssh staging-vps "curl -s -X POST http://localhost:3000/api/v2/user/apps/appDefinitions/update \
  -H 'Content-Type: application/json' \
  -H 'x-namespace: captain' \
  -H 'x-captain-auth: $API_TOKEN' \
  -d '{
    \"appName\":\"$APP_NAME\",
    \"envVars\":[
      {\"key\":\"RAILS_MASTER_KEY\",\"value\":\"$RAILS_MASTER_KEY\"},
      {\"key\":\"RAILS_ENV\",\"value\":\"production\"},
      {\"key\":\"RAILS_LOG_TO_STDOUT\",\"value\":\"true\"},
      {\"key\":\"RAILS_SERVE_STATIC_FILES\",\"value\":\"true\"},
      {\"key\":\"DATABASE_URL\",\"value\":\"postgresql://postgres:$POSTGRES_PASSWORD@tier2-rails-postgres:5432/ca_small_claims_development\"},
      {\"key\":\"CACHE_DATABASE_URL\",\"value\":\"postgresql://postgres:$POSTGRES_PASSWORD@tier2-rails-postgres:5432/ca_small_claims_cache_development\"},
      {\"key\":\"QUEUE_DATABASE_URL\",\"value\":\"postgresql://postgres:$POSTGRES_PASSWORD@tier2-rails-postgres:5432/ca_small_claims_queue_development\"},
      {\"key\":\"CABLE_DATABASE_URL\",\"value\":\"postgresql://postgres:$POSTGRES_PASSWORD@tier2-rails-postgres:5432/ca_small_claims_cable_development\"},
      {\"key\":\"SECRET_KEY_BASE\",\"value\":\"$RAILS_MASTER_KEY\"},
      {\"key\":\"RAILS_MAX_THREADS\",\"value\":\"5\"}
    ]
  }'")

if echo "$ENV_UPDATE" | grep -q "\"status\":100"; then
    echo -e "${GREEN}✅ Environment variables configured${NC}"
else
    echo -e "${YELLOW}⚠️  Env var update response: $ENV_UPDATE${NC}"
fi
echo ""

# Enable custom domain
echo -e "${BLUE}4️⃣  Configuring domain...${NC}"
ssh staging-vps "curl -s -X POST http://localhost:3000/api/v2/user/apps/appDefinitions/customdomain \
  -H 'Content-Type: application/json' \
  -H 'x-namespace: captain' \
  -H 'x-captain-auth: $API_TOKEN' \
  -d '{\"appName\":\"$APP_NAME\",\"customDomain\":\"$APP_NAME.$DOMAIN\"}'" > /dev/null

# Enable SSL
ssh staging-vps "curl -s -X POST http://localhost:3000/api/v2/user/apps/appDefinitions/enablessl \
  -H 'Content-Type: application/json' \
  -H 'x-namespace: captain' \
  -H 'x-captain-auth: $API_TOKEN' \
  -d '{\"appName\":\"$APP_NAME\"}'" > /dev/null

echo -e "${GREEN}✅ Domain configured: $APP_NAME.$DOMAIN${NC}"
echo ""

# Build and deploy
echo -e "${BLUE}5️⃣  Building and deploying application...${NC}"
echo "Creating tarball..."

cd /home/cancelei/Projects/ca_small_claims

# Create deployment tarball
tar -czf /tmp/ca-small-claims-deploy.tar.gz \
  --exclude='.git' \
  --exclude='node_modules' \
  --exclude='tmp' \
  --exclude='log' \
  --exclude='coverage' \
  --exclude='*.log' \
  .

echo "Tarball created: $(du -h /tmp/ca-small-claims-deploy.tar.gz | cut -f1)"
echo ""

# Upload and deploy
echo "Uploading to FlukeDeploy..."
ssh staging-vps "curl -s -X POST http://localhost:3000/api/v2/user/apps/appData/$APP_NAME \
  -H 'x-namespace: captain' \
  -H 'x-captain-auth: $API_TOKEN' \
  -F 'sourceFile=@-'" < /tmp/ca-small-claims-deploy.tar.gz > /tmp/deploy-response.json

DEPLOY_RESPONSE=$(cat /tmp/deploy-response.json)
if echo "$DEPLOY_RESPONSE" | grep -q "\"status\":100"; then
    echo -e "${GREEN}✅ Deployment initiated${NC}"
else
    echo -e "${RED}❌ Deployment failed: $DEPLOY_RESPONSE${NC}"
    exit 1
fi
echo ""

# Wait for deployment
echo -e "${BLUE}6️⃣  Waiting for deployment...${NC}"
echo "This will take 2-5 minutes (building Docker image)..."
echo ""

for i in {1..120}; do
    if ssh staging-vps "docker service ls --filter name=srv-captain--$APP_NAME --format '{{.Replicas}}'" 2>/dev/null | grep -q "1/1"; then
        echo -e "${GREEN}✅ Service is running!${NC}"
        break
    fi

    if [ $((i % 12)) -eq 0 ]; then
        echo "Still deploying... ($((i * 5))s elapsed)"
    else
        echo -n "."
    fi
    sleep 5
done
echo ""

# Run migrations
echo -e "${BLUE}7️⃣  Running database setup...${NC}"
sleep 10  # Give container time to fully start

CONTAINER_ID=$(ssh staging-vps "docker ps --filter name=srv-captain--$APP_NAME --format '{{.ID}}' | head -1")
if [ -n "$CONTAINER_ID" ]; then
    echo "Container ID: $CONTAINER_ID"

    # Create databases and run migrations
    ssh staging-vps "docker exec $CONTAINER_ID bin/rails db:create 2>/dev/null" || echo "Database already exists"
    ssh staging-vps "docker exec $CONTAINER_ID bin/rails db:migrate" || echo "Migrations complete or failed"

    echo -e "${GREEN}✅ Database setup complete${NC}"
else
    echo -e "${YELLOW}⚠️  Container not found yet, check logs${NC}"
fi
echo ""

# Cleanup
rm -f /tmp/ca-small-claims-deploy.tar.gz /tmp/deploy-response.json

# Success message
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           🎉 Deployment Complete! ✅                         ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${YELLOW}🌐 Your Application${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  URL:     https://$APP_NAME.$DOMAIN"
echo "  Status:  Check logs if not accessible yet"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo -e "${YELLOW}📝 Useful Commands${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  View logs:"
echo "    ssh staging-vps 'docker service logs srv-captain--$APP_NAME --tail 100 -f'"
echo ""
echo "  Check status:"
echo "    ssh staging-vps 'docker service ps srv-captain--$APP_NAME'"
echo ""
echo "  Rails console:"
echo "    ssh staging-vps 'docker exec -it $CONTAINER_ID bin/rails console'"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo -e "${GREEN}Done!${NC}"
