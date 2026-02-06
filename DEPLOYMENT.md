# Deployment Guide - ca_small_claims

## Quick Deploy

Push to main branch:
```bash
git push origin main
```

This triggers automatic deployment to vps16gb via GitHub Actions.

## Deployment Methods

### 1. GitHub Actions (Recommended) ✅

**Automatic**: Pushes to `main` or `production` branches trigger deployment

**Manual**:
1. Go to Actions tab in GitHub
2. Select "Deploy to FlukeDeploy"
3. Click "Run workflow"

**What it does**:
- Builds Docker image on self-hosted runner
- Pushes to GitHub Container Registry
- Deploys to vps16gb as Docker Swarm service
- Runs database migrations
- Verifies deployment

**Monitoring**:
- GitHub Actions UI shows real-time logs
- Deployment summary shows status and URL

### 2. Direct Deployment (Manual)

For local testing or emergency deploys:

```bash
cd /home/cancelei/Projects/ca_small_claims
./deploy-direct.sh
```

This script builds locally and deploys directly to VPS.

## Environment

**Production VPS**: vps16gb (194.163.44.171)
**Access URL**: http://194.163.44.171:3010
**Database**: tier2-rails-postgres (shared Tier 2 database)

## Database Configuration

**Connection from app**:
```
Host: tier2-rails-postgres (service name on captain-overlay-network)
Port: 5432 (internal)
User: postgres
Password: [from TIER2_POSTGRES_PASSWORD secret]
```

**Databases**:
- ca_small_claims_development (main)
- ca_small_claims_cache_development (Solid Cache)
- ca_small_claims_queue_development (Solid Queue)
- ca_small_claims_cable_development (Solid Cable)

## GitHub Secrets Required

Configure these in GitHub repository settings:

| Secret | Description | How to Get |
|--------|-------------|------------|
| `RAILS_MASTER_KEY` | Rails credentials key | `cat config/master.key` |
| `VPS_SSH_KEY` | SSH key for VPS access | Your SSH private key |
| `TIER2_POSTGRES_PASSWORD` | Database password | On VPS: `/root/.tier2-postgres-credentials` |

## Service Configuration

**Docker Service Name**: `ca-small-claims`
**Network**: `captain-overlay-network`
**Port**: 3010 (external) → 80 (internal)
**Memory**: 1GB limit, 512MB reserved
**Replicas**: 1

## Common Tasks

### View Logs
```bash
ssh staging-vps "docker service logs ca-small-claims --tail 100 -f"
```

### Check Status
```bash
ssh staging-vps "docker service ps ca-small-claims"
```

### Run Rails Console
```bash
ssh staging-vps "docker exec -it \$(docker ps --filter name=ca-small-claims -q | head -1) bin/rails console"
```

### Run Migrations
```bash
ssh staging-vps "docker exec \$(docker ps --filter name=ca-small-claims -q | head -1) bin/rails db:migrate"
```

### Restart Service
```bash
ssh staging-vps "docker service update --force ca-small-claims"
```

### Check Resources
```bash
ssh staging-vps "docker stats --no-stream | grep ca-small-claims"
```

## Troubleshooting

### Deployment Fails

**Check GitHub Actions logs**:
1. Go to Actions tab
2. Click on failed workflow
3. Expand failed step
4. Look for error messages

**Common issues**:
- Missing secrets → Configure in GitHub settings
- SSH key issues → Verify VPS_SSH_KEY secret
- Database connection → Check TIER2_POSTGRES_PASSWORD
- Resource limits → Check VPS memory/CPU

### Service Won't Start

```bash
# Check service logs
ssh staging-vps "docker service logs ca-small-claims"

# Check for errors
ssh staging-vps "docker service ps ca-small-claims --no-trunc"

# Verify environment variables
ssh staging-vps "docker service inspect ca-small-claims | grep -A30 Env"
```

### Database Connection Issues

```bash
# Check tier2-postgres is running
ssh staging-vps "docker service ps tier2-rails-postgres"

# Test database connection from app
ssh staging-vps "docker exec \$(docker ps -q -f name=ca-small-claims) \
  psql -h tier2-rails-postgres -U postgres -d ca_small_claims_development -c 'SELECT 1;'"
```

### Asset Precompilation Fails

This is fixed in the Dockerfile, but if issues occur:

1. Check Node.js is installed in build stage
2. Verify npm dependencies installed
3. Check Tailwind CSS configuration
4. Review build logs for specific errors

## Rollback

If a deployment breaks production:

```bash
# 1. Find previous working version
ssh staging-vps "docker service inspect ca-small-claims | grep Image"

# 2. Update to previous version
ssh staging-vps "docker service update \
  --image ghcr.io/cancelei-org/ca_small_claims:previous-sha-here \
  ca-small-claims"

# 3. Verify
ssh staging-vps "docker service ps ca-small-claims"
```

Or trigger a workflow run from the last working commit in GitHub Actions.

## Adding Environment Variables

1. **Update workflow file**:
   ```yaml
   # In .github/workflows/deploy-to-flukedeploy.yml
   --env NEW_VAR=${{ secrets.NEW_VAR }}
   ```

2. **Add secret to GitHub**:
   - Settings → Secrets and variables → Actions
   - New repository secret
   - Name: `NEW_VAR`, Value: your value

3. **Update existing service** (if already deployed):
   ```bash
   ssh staging-vps "docker service update \
     --env-add NEW_VAR=value \
     ca-small-claims"
   ```

## Performance Monitoring

### Check Response Times
```bash
# View logs with timestamps
ssh staging-vps "docker service logs ca-small-claims --timestamps --tail 100"
```

### Resource Usage
```bash
# Current usage
ssh staging-vps "docker stats --no-stream | grep ca-small-claims"

# Historical usage
ssh staging-vps "docker service inspect ca-small-claims | grep -A10 Resources"
```

### Database Performance
```bash
# Connect to database
ssh staging-vps "docker exec tier2-rails-postgres psql -U postgres -d ca_small_claims_development"

# Check slow queries (in psql)
SELECT * FROM pg_stat_statements ORDER BY mean_exec_time DESC LIMIT 10;
```

## Security

**Secrets Management**:
- Never commit secrets to git
- Use GitHub Secrets for sensitive data
- Rotate credentials periodically

**SSH Access**:
- Use SSH keys (no passwords)
- Key is temporary during deployment (deleted after)
- Limited to deployment actions only

**Docker Images**:
- Stored in private GHCR
- Only accessible with GitHub token
- Scanned for vulnerabilities

## Documentation

- **Workflow file**: `.github/workflows/deploy-to-flukedeploy.yml`
- **Workflow README**: `.github/workflows/README.md`
- **VPS deployment patterns**: `~/.claude/memory/DEPLOYING_TO_VPS16GB.md`
- **GitHub Actions + FlukeDeploy**: `~/.claude/memory/GITHUB_ACTIONS_FLUKEDEPLOY.md`
- **Tier 2 Postgres**: `/home/cancelei/Projects/tier2-postgres/README.md`

## Support

**Logs**: Always check logs first
```bash
ssh staging-vps "docker service logs ca-small-claims --tail 100"
```

**Status**: Verify service is running
```bash
ssh staging-vps "docker service ps ca-small-claims"
```

**Health**: Check if responding
```bash
curl http://194.163.44.171:3010/up
```

---

**Last Updated**: 2026-02-04
**Deployment Method**: GitHub Actions with self-hosted runners
**Environment**: Production (vps16gb)
