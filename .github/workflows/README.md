# GitHub Actions Workflows for ca_small_claims

This directory contains GitHub Actions workflows for CI/CD.

## Workflows

### 1. `ci.yml` - Continuous Integration
Runs on every push and pull request:
- Security scanning (Brakeman, Bundler Audit)
- Linting (RuboCop)
- Unit tests (RSpec with coverage)
- E2E tests (Playwright)

**Runner**: Can use `ubuntu-latest` or `self-hosted` (configurable via workflow_dispatch)

### 2. `deploy-to-flukedeploy.yml` - Deployment
Deploys to production on vps16gb using FlukeDeploy:
- Builds Docker image and pushes to GHCR
- Deploys to vps16gb as Docker Swarm service
- Runs database migrations
- Connects to tier2-rails-postgres

**Runner**: Uses `self-hosted` runners from cancelei-org

**Triggers**:
- Push to `main` or `production` branches
- Manual trigger via workflow_dispatch

## Required Secrets

These must be configured in GitHub repository settings:

| Secret | Description | Where to Find |
|--------|-------------|---------------|
| `RAILS_MASTER_KEY` | Rails master key for credentials | `config/master.key` (local) |
| `VPS_SSH_KEY` | SSH private key for vps16gb | SSH key with access to root@194.163.44.171 |
| `TIER2_POSTGRES_PASSWORD` | Password for tier2-rails-postgres | `/root/.tier2-postgres-credentials` on VPS |

### Setting Up Secrets

1. Go to repository Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Add each secret:

```bash
# Get RAILS_MASTER_KEY
cat config/master.key

# Get TIER2_POSTGRES_PASSWORD
ssh staging-vps "cat /root/.tier2-postgres-credentials | grep PASSWORD"

# Get VPS_SSH_KEY
cat ~/.ssh/id_rsa  # Or your VPS SSH key
```

## Self-Hosted Runners

This project uses self-hosted runners from the `cancelei-org` organization.

**Runner labels**: `[self-hosted, linux]`

**Benefits**:
- Faster builds (no cold start)
- Direct VPS access
- More resources
- No GitHub Actions minutes consumed

**Setup**: Runners are managed at organization level. Contact org admin if runners need to be added.

## Deployment Process

### Automatic Deployment (Push to main/production)
```bash
git push origin main
# Triggers build and deploy automatically
```

### Manual Deployment
1. Go to Actions tab in GitHub
2. Select "Deploy to FlukeDeploy" workflow
3. Click "Run workflow"
4. Select branch
5. Click "Run workflow"

### Monitoring Deployment

**In GitHub**:
- Actions tab shows real-time logs
- Summary shows deployment status and URL

**On VPS**:
```bash
# Check service status
ssh staging-vps "docker service ps ca-small-claims"

# View logs
ssh staging-vps "docker service logs ca-small-claims --tail 100 -f"

# Check if running
ssh staging-vps "docker service ls | grep ca-small-claims"
```

## Deployment Architecture

```
GitHub Actions (self-hosted runner)
  ↓ Build Docker image
GitHub Container Registry (ghcr.io)
  ↓ Pull image
vps16gb (194.163.44.171)
  ↓ Create/update Docker Swarm service
captain-overlay-network
  ├── ca-small-claims (port 3010)
  └── tier2-rails-postgres (port 5432 internal)
```

## Troubleshooting

### Deployment Fails

**Check secrets**:
```bash
# In GitHub Actions logs, look for:
- "permission denied" → Check VPS_SSH_KEY
- "authentication failed" → Check TIER2_POSTGRES_PASSWORD
- "credentials" errors → Check RAILS_MASTER_KEY
```

**Check VPS**:
```bash
# Is VPS accessible?
ssh staging-vps "uptime"

# Is tier2-postgres running?
ssh staging-vps "docker service ps tier2-rails-postgres"

# Is there enough resources?
ssh staging-vps "free -h && df -h"
```

### Build Fails

**Asset precompilation fails**:
- Check Node.js installation in Dockerfile
- Verify npm dependencies are installed
- Check for Tailwind CSS issues

**Database errors during build**:
- Build should use dummy DATABASE_URL
- Check Dockerfile environment variables

### Service Won't Start

```bash
# Check service logs
ssh staging-vps "docker service logs ca-small-claims"

# Check for common issues:
# - Memory limit exceeded
# - Database connection failed
# - Missing environment variables
```

## Adding New Environment Variables

1. **Update workflow file**:
   ```yaml
   --env NEW_VAR=${{ secrets.NEW_VAR }}
   ```

2. **Add secret to GitHub**:
   - Settings → Secrets → New secret

3. **Update service**:
   ```bash
   docker service update --env-add NEW_VAR=value ca-small-claims
   ```

## Rollback

If deployment fails:

```bash
# List previous versions
docker service inspect ca-small-claims | grep Image

# Rollback to previous image
docker service update --image ghcr.io/cancelei-org/ca_small_claims:previous-tag ca-small-claims
```

## Local Testing

Test the Docker build locally before pushing:

```bash
# Build image
docker build -t ca_small_claims:test .

# Run locally
docker run -p 3000:80 \
  -e RAILS_MASTER_KEY=... \
  -e DATABASE_URL=... \
  ca_small_claims:test
```

## Performance Optimization

**Build time**:
- Uses GitHub Actions cache for Docker layers
- Self-hosted runners cache dependencies
- Typical build: 2-3 minutes

**Deployment time**:
- Image pull: ~30 seconds
- Service update: ~10 seconds
- Total: ~1 minute for updates

## Security Notes

- Secrets are never logged
- SSH keys are temporary (removed after deployment)
- Docker images are scanned for vulnerabilities
- Only specific branches trigger deployment

## Related Documentation

- FlukeDeploy setup: `/home/cancelei/Projects/flukedeploy/`
- Tier 2 Postgres: `/home/cancelei/Projects/tier2-postgres/`
- VPS deployment guide: `~/.claude/memory/DEPLOYING_TO_VPS16GB.md`
