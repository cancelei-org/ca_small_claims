# GitHub Secrets Setup Guide

Before deploying, configure these secrets in your GitHub repository.

## Required Secrets

### 1. RAILS_MASTER_KEY

**Purpose**: Decrypts Rails credentials for production

**Get the value**:
```bash
cat /home/cancelei/Projects/ca_small_claims/config/master.key
```

**Add to GitHub**:
1. Go to: https://github.com/cancelei-org/ca_small_claims/settings/secrets/actions
2. Click: "New repository secret"
3. Name: `RAILS_MASTER_KEY`
4. Value: (paste the content from master.key)
5. Click: "Add secret"

---

### 2. VPS_SSH_KEY

**Purpose**: SSH access to vps16gb for deployment

**Get the value**:
```bash
# Your SSH private key that has access to root@194.163.44.171
cat ~/.ssh/id_rsa

# Or if you use a specific key for the VPS:
cat ~/.ssh/vps_deploy_key
```

**Add to GitHub**:
1. Go to: https://github.com/cancelei-org/ca_small_claims/settings/secrets/actions
2. Click: "New repository secret"
3. Name: `VPS_SSH_KEY`
4. Value: (paste the ENTIRE private key including -----BEGIN and -----END lines)
5. Click: "Add secret"

**Security Note**: This key should only have access to the VPS, not other systems.

---

### 3. TIER2_POSTGRES_PASSWORD

**Purpose**: Password for tier2-rails-postgres database

**Get the value**:
```bash
ssh staging-vps "cat /root/.tier2-postgres-credentials | grep PASSWORD"
```

This will output something like:
```
PASSWORD=EyDlvuiQOM/Tsqxgh/lYoppqByL5trcprUeqiT2QT0E=
```

**Add to GitHub**:
1. Go to: https://github.com/cancelei-org/ca_small_claims/settings/secrets/actions
2. Click: "New repository secret"
3. Name: `TIER2_POSTGRES_PASSWORD`
4. Value: `EyDlvuiQOM/Tsqxgh/lYoppqByL5trcprUeqiT2QT0E=` (just the password part)
5. Click: "Add secret"

---

## Verification

After adding all secrets, you should see these in your repository settings:

✅ RAILS_MASTER_KEY
✅ VPS_SSH_KEY
✅ TIER2_POSTGRES_PASSWORD

**Note**: You won't be able to view the values after creation, only update or delete them.

## Auto-Provided Secrets

These are automatically available (no setup needed):

- `GITHUB_TOKEN`: Auto-generated for each workflow run
- Used for pushing to GitHub Container Registry

## Testing

To test if secrets are configured correctly:

1. Go to Actions tab
2. Select "Deploy to FlukeDeploy" workflow
3. Click "Run workflow"
4. Select branch: `main`
5. Click "Run workflow"

If any secrets are missing or incorrect, the workflow will fail with a descriptive error.

## Security Best Practices

1. **Never commit secrets** to git
2. **Rotate credentials** periodically
3. **Limit SSH key** scope (only VPS access)
4. **Use separate keys** for different environments if possible
5. **Review secret access** regularly in GitHub audit log

## Troubleshooting

### "Permission denied" during SSH
- Check VPS_SSH_KEY is the complete private key
- Verify key has access: `ssh -i ~/.ssh/your_key root@194.163.44.171 "echo success"`

### "Authentication failed" to database
- Check TIER2_POSTGRES_PASSWORD matches VPS
- Verify: `ssh staging-vps "cat /root/.tier2-postgres-credentials"`

### "Failed to decrypt credentials"
- Check RAILS_MASTER_KEY matches local file
- Verify: `cat config/master.key`

## Updating Secrets

To update a secret:
1. Go to repository settings → Secrets
2. Click on the secret name
3. Click "Update secret"
4. Enter new value
5. Click "Update secret"

## Additional Secrets (Optional)

You may want to add these for future features:

- `S3_ACCESS_KEY_ID` - For file storage
- `S3_SECRET_ACCESS_KEY` - For file storage
- `SENTRY_DSN` - For error tracking
- `SLACK_WEBHOOK_URL` - For deployment notifications

---

**Setup Time**: ~5 minutes
**Required Access**: GitHub repo admin, VPS SSH access
**One-time Setup**: Yes (unless credentials rotate)
