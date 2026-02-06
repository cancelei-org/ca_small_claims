#!/bin/bash
set -e

# ============================================================================
# ca_small_claims Deployment Script
# Deploys to vps16gb using FlukeDeploy's new deployment API
# ============================================================================

VPS="staging-vps"
APP_NAME="ca-small-claims"
PORT=3010
IMAGE_NAME="ca-small-claims:$(date +%Y%m%d-%H%M)"

# Get credentials
RAILS_MASTER_KEY=$(cat config/master.key)
TIER2_POSTGRES_PASSWORD="EyDlvuiQOM/Tsqxgh/lYoppqByL5trcprUeqiT2QT0E="

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 Deploying ca_small_claims to vps16gb"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "App:    $APP_NAME"
echo "Port:   $PORT"
echo "Image:  $IMAGE_NAME"
echo ""

# Step 1: Build Docker image locally
echo "━━━ Step 1/5: Building Docker image ━━━"
echo ""
docker build -t $IMAGE_NAME .
echo "✓ Image built successfully"
echo ""

# Step 2: Transfer image to VPS
echo "━━━ Step 2/5: Transferring image to VPS ━━━"
echo ""
docker save $IMAGE_NAME | ssh $VPS "docker load"
echo "✓ Image transferred successfully"
echo ""

# Step 3: Create or update Docker service
echo "━━━ Step 3/5: Deploying Docker service ━━━"
echo ""

# Check if service exists
if ssh $VPS "docker service inspect $APP_NAME >/dev/null 2>&1"; then
    echo "Service exists, updating..."
    ssh $VPS "docker service update \\
        --image $IMAGE_NAME \\
        --env-add RAILS_ENV=production \\
        --env-add RAILS_MASTER_KEY=$RAILS_MASTER_KEY \\
        --env-add DATABASE_URL=postgresql://postgres:$TIER2_POSTGRES_PASSWORD@tier2-rails-postgres:5432/ca_small_claims_development \\
        --env-add CACHE_DATABASE_URL=postgresql://postgres:$TIER2_POSTGRES_PASSWORD@tier2-rails-postgres:5432/ca_small_claims_cache_development \\
        --env-add QUEUE_DATABASE_URL=postgresql://postgres:$TIER2_POSTGRES_PASSWORD@tier2-rails-postgres:5432/ca_small_claims_queue_development \\
        --env-add CABLE_DATABASE_URL=postgresql://postgres:$TIER2_POSTGRES_PASSWORD@tier2-rails-postgres:5432/ca_small_claims_cable_development \\
        $APP_NAME"
else
    echo "Creating new service..."
    ssh $VPS "docker service create \\
        --name $APP_NAME \\
        --network captain-overlay-network \\
        --publish published=$PORT,target=80,mode=host \\
        --env RAILS_ENV=production \\
        --env RAILS_MASTER_KEY=$RAILS_MASTER_KEY \\
        --env DATABASE_URL=postgresql://postgres:$TIER2_POSTGRES_PASSWORD@tier2-rails-postgres:5432/ca_small_claims_development \\
        --env CACHE_DATABASE_URL=postgresql://postgres:$TIER2_POSTGRES_PASSWORD@tier2-rails-postgres:5432/ca_small_claims_cache_development \\
        --env QUEUE_DATABASE_URL=postgresql://postgres:$TIER2_POSTGRES_PASSWORD@tier2-rails-postgres:5432/ca_small_claims_queue_development \\
        --env CABLE_DATABASE_URL=postgresql://postgres:$TIER2_POSTGRES_PASSWORD@tier2-rails-postgres:5432/ca_small_claims_cable_development \\
        --constraint 'node.role==manager' \\
        --limit-memory 1G \\
        --reserve-memory 512M \\
        --label com.flukebase.tier=2 \\
        $IMAGE_NAME"
fi

echo "✓ Service deployed successfully"
echo ""

# Step 4: Run database migrations
echo "━━━ Step 4/5: Running database migrations ━━━"
echo ""
# Wait for service to be running
sleep 10
CONTAINER_ID=$(ssh $VPS "docker ps -q -f name=$APP_NAME | head -1")
if [ -n "$CONTAINER_ID" ]; then
    ssh $VPS "docker exec $CONTAINER_ID bin/rails db:migrate"
    echo "✓ Migrations completed"
else
    echo "⚠ Could not find running container, migrations skipped"
    echo "  Run manually: ssh $VPS 'docker exec \$(docker ps -q -f name=$APP_NAME | head -1) bin/rails db:migrate'"
fi
echo ""

# Step 5: Verify deployment
echo "━━━ Step 5/5: Verifying deployment ━━━"
echo ""
ssh $VPS "docker service ps $APP_NAME"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Deployment Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Access URL: http://194.163.44.171:$PORT"
echo ""
echo "Useful commands:"
echo "  View logs:   ssh $VPS 'docker service logs $APP_NAME -f'"
echo "  Check status: ssh $VPS 'docker service ps $APP_NAME'"
echo "  Run console: ssh $VPS 'docker exec -it \$(docker ps -q -f name=$APP_NAME | head -1) bin/rails console'"
echo ""
