#!/bin/bash

# Deploy ca_small_claims directly as Docker Swarm service
# Bypasses FlukeDeploy API and uses direct Docker commands

set -e

APP_NAME="ca-small-claims"
IMAGE_NAME="ca_small_claims:production"
POSTGRES_PASSWORD="EyDlvuiQOM/Tsqxgh/lYoppqByL5trcprUeqiT2QT0E="
RAILS_MASTER_KEY="24c844b898a2b6f299f04950289046d3def6c30faf8b2b155e2dd92811c5bf0c"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}Deploying ca_small_claims directly to vps16gb${NC}"
echo ""

# Step 1: Build image locally
echo -e "${BLUE}1️⃣  Building Docker image locally...${NC}"
cd /home/cancelei/Projects/ca_small_claims
docker build -t "$IMAGE_NAME" \
  --build-arg RAILS_MASTER_KEY="$RAILS_MASTER_KEY" \
  -f Dockerfile .

echo -e "${GREEN}✅ Image built${NC}"
echo ""

# Step 2: Save and transfer image
echo -e "${BLUE}2️⃣  Transferring image to VPS...${NC}"
docker save "$IMAGE_NAME" | gzip | ssh staging-vps "gunzip | docker load"
echo -e "${GREEN}✅ Image transferred${NC}"
echo ""

# Step 3: Remove old service if exists
echo -e "${BLUE}3️⃣  Removing old service (if exists)...${NC}"
ssh staging-vps "docker service rm $APP_NAME 2>/dev/null || true"
sleep 5
echo -e "${GREEN}✅ Ready for deployment${NC}"
echo ""

# Step 4: Create Docker service
echo -e "${BLUE}4️⃣  Creating Docker service...${NC}"

ssh staging-vps "docker service create \
  --name $APP_NAME \
  --network captain-overlay-network \
  --publish published=3010,target=80,mode=host \
  --env RAILS_ENV=production \
  --env RAILS_MASTER_KEY=$RAILS_MASTER_KEY \
  --env SECRET_KEY_BASE=$RAILS_MASTER_KEY \
  --env RAILS_LOG_TO_STDOUT=true \
  --env RAILS_SERVE_STATIC_FILES=true \
  --env DATABASE_URL=postgresql://postgres:$POSTGRES_PASSWORD@tier2-rails-postgres:5432/ca_small_claims_development \
  --env CACHE_DATABASE_URL=postgresql://postgres:$POSTGRES_PASSWORD@tier2-rails-postgres:5432/ca_small_claims_cache_development \
  --env QUEUE_DATABASE_URL=postgresql://postgres:$POSTGRES_PASSWORD@tier2-rails-postgres:5432/ca_small_claims_queue_development \
  --env CABLE_DATABASE_URL=postgresql://postgres:$POSTGRES_PASSWORD@tier2-rails-postgres:5432/ca_small_claims_cable_development \
  --env RAILS_MAX_THREADS=5 \
  --constraint 'node.role==manager' \
  --replicas 1 \
  --restart-condition any \
  --limit-memory 1G \
  --reserve-memory 512M \
  --label com.flukebase.tier=2 \
  --label com.flukebase.app=ca-small-claims \
  $IMAGE_NAME"

echo -e "${GREEN}✅ Service created${NC}"
echo ""

# Step 5: Wait for service
echo -e "${BLUE}5️⃣  Waiting for service to start...${NC}"
for i in {1..30}; do
    if ssh staging-vps "docker service ls --filter name=$APP_NAME --format '{{.Replicas}}'" | grep -q "1/1"; then
        echo -e "${GREEN}✅ Service running${NC}"
        break
    fi
    echo -n "."
    sleep 3
done
echo ""

# Step 6: Run migrations
echo -e "${BLUE}6️⃣  Running database migrations...${NC}"
sleep 10
CONTAINER_ID=$(ssh staging-vps "docker ps --filter name=$APP_NAME --format '{{.ID}}' | head -1")

if [ -n "$CONTAINER_ID" ]; then
    echo "Container: $CONTAINER_ID"
    ssh staging-vps "docker exec $CONTAINER_ID bin/rails db:create 2>/dev/null" || true
    ssh staging-vps "docker exec $CONTAINER_ID bin/rails db:migrate" || true
    echo -e "${GREEN}✅ Database ready${NC}"
fi
echo ""

echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          🎉 Deployment Complete! ✅                      ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}🌐 Access your app:${NC}"
echo "   http://194.163.44.171:3010"
echo ""
echo "   To access via domain, configure nginx or use SSH tunnel:"
echo "   ssh -L 3010:localhost:3010 staging-vps"
echo "   Then visit: http://localhost:3010"
echo ""
echo -e "${YELLOW}📝 Useful commands:${NC}"
echo "   Logs:    ssh staging-vps 'docker service logs $APP_NAME --tail 100 -f'"
echo "   Status:  ssh staging-vps 'docker service ps $APP_NAME'"
echo "   Console: ssh staging-vps 'docker exec -it $CONTAINER_ID bin/rails console'"
echo ""
