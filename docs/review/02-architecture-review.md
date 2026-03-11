# Architecture Review

## Current Stack Analysis

### Backend: TypeScript + Fastify + WebSocket
**Grade: B+**

**Strengths:**
- Fastify is an excellent choice - fast, well-maintained, modern async/await patterns
- Clean separation: `contracts.ts` (shared types), `server.ts` (HTTP/WS routing), `store.ts` (business logic), `persistence.ts` (data layer), `region.ts` (real-time)
- The persistence abstraction (in-memory vs Postgres) is well-designed for development velocity
- scrypt password hashing with per-account salts and timing-safe comparison - proper security practices
- Session TTL enforcement with sliding expiration

**Concerns:**
- `server.ts` at 1,083 lines is a single route file - needs splitting into route modules
- `persistence.ts` at 2,180 lines handles all data operations - should be split by domain
- `store.ts` at 950 lines mixes too many domains (auth, parcels, objects, friends, groups, currency, etc.)
- No request validation beyond basic null checks - should use Fastify schemas or Zod
- Token passed in request body instead of Authorization header - non-standard
- No rate limiting on any endpoints
- No request/response logging beyond Fastify default

### Frontend: Three.js Browser Client
**Grade: C+**

**Strengths:**
- Functional 3D rendering with glTF model loading
- TransformControls for build mode editing
- Decent UI layout with CSS custom properties

**Concerns:**
- 1,844 lines in a single `app.js` file with no module structure
- No framework - vanilla DOM manipulation at scale becomes unmaintainable
- Still branded as "ThirdLife" in HTML title and UI text
- No asset preloading or loading states
- No error boundary or graceful degradation

### Native Client: Godot 4 + GDScript
**Grade: B-**

**Strengths:**
- Proper choice of engine for a 3D virtual world
- Full API integration (auth, regions, objects, chat, inventory)
- glTF asset pipeline with fallback geometry
- Multiple manipulation modes (move, rotate, scale)
- Parcel overlay rendering

**Concerns:**
- 1,297 lines in a single `main.gd` - critical code smell for Godot
- No scene composition - everything is monolithic
- No animation controller or state machine
- Hard-coded UI layout values instead of using Godot's anchoring system
- No shader work - everything uses default materials

### Database: PostgreSQL (optional)
**Grade: B**

**Strengths:**
- Schema auto-creation on startup
- Proper foreign key relationships
- Index usage on high-query tables
- Graceful fallback to in-memory mode

**Concerns:**
- No migrations system - schema changes require manual intervention
- No connection pooling configuration
- No query optimization or prepared statements
- No database-level constraints beyond basic types

## Recommended Architecture Evolution

### Phase 1: Modularize (Weeks 1-4)
```
src/
  routes/
    auth.ts
    regions.ts
    parcels.ts
    objects.ts
    social.ts
    admin.ts
    economy.ts
  services/
    auth.service.ts
    region.service.ts
    parcel.service.ts
    object.service.ts
    social.service.ts
    economy.service.ts
  data/
    repositories/
      account.repo.ts
      region.repo.ts
      parcel.repo.ts
      object.repo.ts
    migrations/
    persistence.ts
  world/
    region.ts
    interest.ts
    physics.ts
  contracts.ts
  server.ts
```

### Phase 2: Scale (Weeks 5-12)
- Redis for session store and pub/sub
- Region worker processes
- CDN for static assets
- Database connection pooling with pgBouncer

### Phase 3: Production (Weeks 13-20)
- Container orchestration (Docker + K8s or Fly.io)
- CI/CD pipeline
- Monitoring and alerting
- Automated backups
- Load testing
