# Tier 2 Database Setup

This project now uses the shared **tier2-rails-postgres** container for database services, aligned with the flukebase Tier 2 infrastructure concept.

## Quick Reference

| Setting | Value |
|---------|-------|
| **Database Host** | `tier2-rails-postgres` (container name) |
| **External Port** | `5435` (from host machine) |
| **Username** | `postgres` |
| **Password** | `postgres_tier2_dev` |
| **Network** | `tier2-network` |

## Starting the Application

1. **Ensure shared postgres is running**:
   ```bash
   cd /home/cancelei/Projects/tier2-postgres
   docker compose up -d
   ```

2. **Start ca_small_claims**:
   ```bash
   cd /home/cancelei/Projects/ca_small_claims
   docker compose up
   ```

## Databases

This project uses 8 databases in the shared container:

**Development**:
- `ca_small_claims_development` - Main application
- `ca_small_claims_cache_development` - Solid Cache
- `ca_small_claims_queue_development` - Solid Queue
- `ca_small_claims_cable_development` - Solid Cable

**Test**:
- `ca_small_claims_test` - Test application
- `ca_small_claims_cache_test` - Test cache
- `ca_small_claims_queue_test` - Test queue
- `ca_small_claims_cable_test` - Test cable

## Connecting Directly to Database

### From Host Machine
```bash
# Connect to main database
psql -h localhost -p 5435 -U postgres -d ca_small_claims_development

# Password: postgres_tier2_dev
```

### From Rails Console
```bash
# Enter rails console
docker compose exec web bin/rails console

# Database is already connected via ActiveRecord
```

### Using Database Tools

**Connection String**:
```
postgresql://postgres:postgres_tier2_dev@localhost:5435/ca_small_claims_development
```

Use this in tools like:
- TablePlus
- pgAdmin
- DBeaver
- DataGrip

## Common Tasks

### Run Migrations
```bash
docker compose run --rm web bin/rails db:migrate
```

### Reset Database
```bash
docker compose run --rm web bin/rails db:reset
```

### Seed Database
```bash
docker compose run --rm web bin/rails db:seed
```

### Check Database Status
```bash
# Rails way
docker compose exec web bin/rails db:version

# Direct postgres
docker compose exec web psql -h tier2-rails-postgres -U postgres -d ca_small_claims_development -c "SELECT version();"
```

### Backup Database
```bash
# From host
pg_dump -h localhost -p 5435 -U postgres ca_small_claims_development > backup.sql

# Or using docker
docker exec tier2-rails-postgres pg_dump -U postgres ca_small_claims_development > backup.sql
```

### Restore Database
```bash
# From host
psql -h localhost -p 5435 -U postgres ca_small_claims_development < backup.sql

# Or using docker
cat backup.sql | docker exec -i tier2-rails-postgres psql -U postgres ca_small_claims_development
```

## Architecture

```
┌─────────────────────────────────────┐
│   ca_small_claims_web (port 3001)  │
│   ca_small_claims_worker            │
└────────────┬────────────────────────┘
             │ tier2-network
             ▼
┌─────────────────────────────────────┐
│   tier2-rails-postgres (port 5435) │
│   ├── ca_small_claims_development   │
│   ├── ca_small_claims_cache_dev     │
│   ├── ca_small_claims_queue_dev     │
│   ├── ca_small_claims_cable_dev     │
│   ├── ca_small_claims_test          │
│   ├── ca_small_claims_cache_test    │
│   ├── ca_small_claims_queue_test    │
│   ├── ca_small_claims_cable_test    │
│   ├── seeinsp_development           │
│   └── seeinsp_test                  │
└─────────────────────────────────────┘
```

## Troubleshooting

### "Connection refused" error
The shared postgres container might not be running:
```bash
cd /home/cancelei/Projects/tier2-postgres
docker compose up -d
```

### "Database does not exist" error
Create the database:
```bash
docker exec tier2-rails-postgres psql -U postgres -c "CREATE DATABASE ca_small_claims_development;"
```

### Wrong password error
Verify `docker-compose.yml` has:
```yaml
DATABASE_PASSWORD: postgres_tier2_dev
```

### Network not found error
Create the network:
```bash
docker network create tier2-network
```

## Benefits of Shared Setup

1. **Resource Efficiency**: Single postgres instance serves multiple projects
2. **Easier Maintenance**: One place to backup/restore/upgrade
3. **Consistent Environment**: All Tier 2 projects use same postgres version
4. **flukebase Aligned**: Follows Tier 2 infrastructure pattern

## Related Documentation

- Shared Postgres README: `/home/cancelei/Projects/tier2-postgres/README.md`
- Migration Guide: `/home/cancelei/Projects/tier2-postgres/MIGRATION_GUIDE.md`
- Project CLAUDE.md: See "Troubleshooting > Database Issues" section
