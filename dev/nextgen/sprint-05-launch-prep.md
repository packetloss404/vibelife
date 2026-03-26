# Sprint 5: Launch Prep

**Duration:** 1 week
**Goal:** Security hardening, Docker deployment, load testing, documentation refresh,
and integration test checklist.
**Prerequisite:** Sprint 4 complete.

---

## 1. Security Pass

### Sidecar

- [ ] Audit all routes for missing `requireAuth` middleware
- [ ] Audit all admin routes for missing `requireAdmin` middleware
- [ ] Verify rate limiting on auth endpoints (max 10 attempts per minute per IP)
- [ ] Verify rate limiting on economy transfer endpoints (max 30 per minute per account)
- [ ] Sanitize all user-provided strings (strip HTML, control chars, null bytes)
- [ ] Validate all currency amounts are positive integers (no float exploits)
- [ ] Verify session token entropy (minimum 128 bits)
- [ ] Add CSRF protection for state-changing endpoints
- [ ] Review CORS configuration -- production should not use wildcard origins
- [ ] Ensure `DATABASE_URL` connection uses TLS in production

### Paper Plugin

- [ ] Verify all commands check permissions before executing
- [ ] Verify API key is not logged or exposed in error messages
- [ ] Verify sidecar URL is not exposed to players in error messages
- [ ] Add input length limits on all command arguments

### Fabric Mod

- [ ] Verify session token is stored in memory only (not written to disk)
- [ ] Verify sidecar URL is configurable (not hardcoded)
- [ ] Verify no sensitive data in client-side logs at INFO level

---

## 2. Docker Setup

### Compose File: `docker-compose.yml`

```yaml
services:
  sidecar:
    build: .
    ports:
      - "3000:3000"
    environment:
      - DATABASE_URL=postgresql://packetcraft:secret@db:5432/packetcraft
      - CORS_ORIGINS=http://localhost
      - NODE_ENV=production
    depends_on:
      - db

  db:
    image: postgres:16-alpine
    environment:
      - POSTGRES_USER=packetcraft
      - POSTGRES_PASSWORD=secret
      - POSTGRES_DB=packetcraft
    volumes:
      - pgdata:/var/lib/postgresql/data

volumes:
  pgdata:
```

### Dockerfile

```dockerfile
FROM node:22-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY dist/ ./dist/
COPY public/ ./public/
EXPOSE 3000
CMD ["node", "dist/server.js"]
```

### Tasks

- [ ] Create `Dockerfile` in project root
- [ ] Create `docker-compose.yml` in project root
- [ ] Add `.dockerignore` (node_modules, .git, fabric-mod, paper-plugin, native-client, dev)
- [ ] Verify `npm run build && docker build .` succeeds
- [ ] Verify `docker compose up` starts sidecar + PostgreSQL
- [ ] Verify sidecar connects to PostgreSQL and serves API
- [ ] Add health check endpoint: `GET /health` returns `{ status: "ok" }`

---

## 3. Load Testing

### Setup

Use `autocannon` (Node.js) or `k6` for load testing against the Docker deployment.

### Scenarios

| Scenario | Target | Threshold |
|----------|--------|-----------|
| Auth login | `POST /api/auth/login` | 500 req/s, p99 < 50ms |
| Balance check | `GET /api/economy/balance/:id` | 1000 req/s, p99 < 20ms |
| Marketplace browse | `GET /api/marketplace/listings` | 500 req/s, p99 < 50ms |
| Friend list | `GET /api/social/friends` | 500 req/s, p99 < 30ms |
| Mixed workload | All endpoints weighted | 200 req/s sustained, no errors |

### Tasks

- [ ] Write load test script in `scripts/load-test.mjs`
- [ ] Run against in-memory mode and record baseline
- [ ] Run against PostgreSQL mode and compare
- [ ] Identify and fix any endpoints below threshold
- [ ] Document results in `dev/nextgen/load-test-results.md`

---

## 4. Documentation Refresh

### Files to Update

- [ ] `README.md` -- update to reflect PacketCraft branding, current architecture, and setup instructions
- [ ] `CLAUDE.md` -- update project overview, build commands, and architecture notes
- [ ] `docs/index.html` -- update landing page with current feature list
- [ ] `paper-server/plugins/VibeLife/config.yml` -- rename to PacketCraft if applicable

### New Documentation

- [ ] `CONTRIBUTING.md` -- development setup, coding standards, PR process
- [ ] `docs/api.md` -- REST API reference (auto-generate from route files if possible)
- [ ] Update all user-facing strings from "VibeLife" to "PacketCraft" across:
  - Fabric mod (`fabric.mod.json`, screen titles, toast messages)
  - Paper plugin (`plugin.yml`, command descriptions, chat messages)
  - Sidecar (error messages, API responses)

---

## 5. Integration Test Checklist

End-to-end tests verifying the full stack works together. Run manually before launch.

### Auth Flow
- [ ] Player joins Paper server -> plugin calls sidecar mc-login -> token sent to Fabric mod via plugin channel -> Fabric mod stores token and can call sidecar API

### Economy Flow
- [ ] Player checks balance via `/balance` command -> correct amount shown
- [ ] Player sends currency via Fabric EconomyScreen -> recipient balance updates
- [ ] Vault plugin (e.g., ChestShop) deducts currency -> sidecar balance reflects change

### Social Flow
- [ ] Player sends friend request via SocialScreen -> recipient sees pending request
- [ ] Recipient accepts -> both see each other in friend list
- [ ] Player blocks another -> blocked player cannot send messages or friend requests

### Marketplace Flow
- [ ] Player lists item via `/market list` -> appears in MarketplaceScreen for other players
- [ ] Buyer purchases via MarketplaceScreen -> currency transferred, listing removed

### Guild Flow
- [ ] Player creates guild via `/guild create` -> guild appears in guild tab
- [ ] Player invites another -> invitation appears -> accepted -> both in guild

### Parcel Flow
- [ ] Player claims parcel -> can build inside -> cannot build outside
- [ ] Player upgrades parcel -> tier increases, currency deducted

### Pet Flow
- [ ] Player adopts pet -> appears in PetsScreen -> can rename, feed, summon

### Photo Flow
- [ ] Player takes photo -> appears in gallery -> community can like it

---

## Launch Checklist

- [ ] All 5 sprints complete
- [ ] All tests pass: `npm run check`
- [ ] Both Java projects build: `./gradlew build` (paper-plugin + fabric-mod)
- [ ] Docker deployment works: `docker compose up`
- [ ] Load test thresholds met
- [ ] Security checklist complete (all items above checked)
- [ ] Documentation updated
- [ ] Integration test checklist complete
- [ ] Branding: no remaining "VibeLife" references in user-facing strings
