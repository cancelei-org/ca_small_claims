#!/bin/bash
set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 Completing ca_small_claims Deployment"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

VPS="staging-vps"
APP_NAME="ca-small-claims"

# Step 1: Build on VPS with fixed Gemfile
echo "━━━ Step 1/3: Building image on VPS (without turbo_boost-commands) ━━━"
echo ""
ssh $VPS "cd /tmp/ca-build && docker build -t ca_small_claims:fixed -t ca_small_claims:production ."
echo "✓ Image built"
echo ""

# Step 2: Update service
echo "━━━ Step 2/3: Updating Docker service ━━━"
echo ""
ssh $VPS "docker service update --image ca_small_claims:production ca-small-claims"
echo "✓ Service updated"
echo ""

# Step 3: Run migrations
echo "━━━ Step 3/3: Running database migrations ━━━"
echo ""
sleep 10
CONTAINER_ID=$(ssh $VPS "docker ps -q -f name=ca-small-claims | head -1")
if [ -n "$CONTAINER_ID" ]; then
    ssh $VPS "docker exec $CONTAINER_ID bin/rails db:create db:migrate"
    echo "✓ Migrations completed"
else
    echo "⚠  Container not ready yet. Run migrations manually:"
    echo "   ssh $VPS 'docker exec \$(docker ps -q -f name=ca-small-claims | head -1) bin/rails db:migrate'"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Deployment Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Access: http://194.163.44.171:3010"
echo ""
echo "Check status:"
echo "  ssh $VPS 'docker service ps ca-small-claims'"
echo ""
echo "View logs:"
echo "  ssh $VPS 'docker service logs ca-small-claims -f'"
echo ""
