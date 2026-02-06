#!/bin/bash
# Fix CapRover routing for ca-small-claims
# This script ensures only one domain (smallclaims.flukebase.me) is configured

set -e

VPS_HOST="${VPS_HOST:-staging-vps}"
APP_NAME="ca-small-claims"
DOMAIN="smallclaims.flukebase.me"

echo "=== Fixing CapRover Routing for $APP_NAME ==="

# Step 1: Check if the service is running
echo "Checking service status..."
ssh "$VPS_HOST" "docker service ps srv-captain--$APP_NAME --format '{{.CurrentState}}'"

# Step 2: Verify the app is accessible directly
echo -e "\nTesting direct container access..."
CONTAINER_ID=$(ssh "$VPS_HOST" "docker ps -q -f name=srv-captain--$APP_NAME | head -1")
if [ -z "$CONTAINER_ID" ]; then
    echo "ERROR: No container found for $APP_NAME"
    exit 1
fi

echo "Container ID: $CONTAINER_ID"
ssh "$VPS_HOST" "docker exec $CONTAINER_ID curl -sI http://localhost:3000/ | head -5"

# Step 3: Check CapRover app configuration
echo -e "\nChecking CapRover configuration..."
ssh "$VPS_HOST" "docker exec captain-captain cat /captain/data/config-captain.json" | \
    python3 -c "import sys, json; apps=json.load(sys.stdin).get('appDefinitions', {}); print(json.dumps(apps.get('$APP_NAME', {}), indent=2))"

# Step 4: Recommendations
cat <<EOF

=== RECOMMENDED FIXES ===

1. **Access CapRover Dashboard**:
   - URL: https://captain.flukebase.me (or your CapRover domain)
   - Login with your credentials

2. **Fix App Routing**:
   - Navigate to: Apps → ca-small-claims
   - Under "HTTP Settings":
     * Ensure only ONE domain is listed: $DOMAIN
     * Remove any other domains
     * Enable "HTTPS" if not already enabled
   - Click "Save & Update" to regenerate nginx configuration

3. **If routing still broken**:
   Run on VPS:
   docker service update --force srv-captain--captain-nginx

   This will restart CapRover's nginx service and refresh all routing.

4. **Verify Fix**:
   curl -I https://$DOMAIN

EOF

echo -e "\n=== Current Domain Resolution ==="
nslookup "$DOMAIN" || echo "Domain not resolving"

echo -e "\n=== Testing HTTPS Access ==="
curl -sI "https://$DOMAIN" | head -10 || echo "HTTPS access failed"
