# Technical Debt & Critical Fixes

## Critical (Fix This Week)

### 1. Branding Inconsistency
- `public/index.html:6` - Title says "ThirdLife 2026 Prototype"
- `public/index.html:205` - UI text says "ThirdLife / 2026 stack"
- `native-client/godot/scenes/main.tscn:89` - TopTitle says "ThirdLife Native Client"
- All should say "VibeLife"

### 2. Dead Code in addFriend (store.ts:792-793)
```typescript
// These two lines do nothing useful:
const friendAccount = await persistence.authenticateAccount("");
const accountResult = await persistence.getOrCreateGuestAccount("");
```
These call authenticate with empty string and create a guest with empty name. Pure dead code.

### 3. saveObjectPermissions Bug (store.ts:945)
```typescript
const objects = await persistence.listRegionObjects("");
```
Queries all objects with empty string regionId - should use the actual regionId from the object being modified. This means the permission check silently fails.

### 4. No Rate Limiting
Authentication endpoints can be brute-forced. Add `@fastify/rate-limit`:
```
/api/auth/guest     - 10 req/min per IP
/api/auth/register  - 5 req/min per IP
/api/auth/login     - 10 req/min per IP
/api/admin/*        - 30 req/min per token
All other endpoints  - 60 req/min per token
```

### 5. CORS Wide Open
```typescript
await app.register(cors, { origin: true }); // Allows everything
```
Should whitelist specific origins in production.

## High Priority (Fix This Month)

### 6. Route Modularization
Split `server.ts` into Fastify plugin files:
```
routes/auth.ts      - guest, register, login
routes/avatar.ts    - appearance, teleport, profile
routes/regions.ts   - list, objects, parcels
routes/social.ts    - friends, groups, messages
routes/economy.ts   - currency, marketplace
routes/admin.ts     - moderation, audit logs
routes/assets.ts    - asset management
```

### 7. Auth Middleware
Create a reusable auth hook instead of checking token in every route:
```typescript
app.decorateRequest('session', null);
app.addHook('preHandler', async (request) => {
  const token = request.headers.authorization?.replace('Bearer ', '')
    || request.body?.token || request.query?.token;
  if (token) request.session = getSession(token);
});
```

### 8. Godot Scene Decomposition
Split `main.gd` into:
```
scripts/
  main.gd            - scene root, high-level state
  network/
    api_client.gd     - HTTP requests
    ws_client.gd      - WebSocket management
  world/
    region_loader.gd  - region/scene loading
    avatar_manager.gd - avatar spawning/movement
    object_manager.gd - world objects
    parcel_manager.gd - parcel overlays
  ui/
    hud_controller.gd - HUD state management
    chat_panel.gd     - chat functionality
    inventory_panel.gd - inventory
    build_panel.gd    - build mode tools
  camera/
    orbit_camera.gd   - camera controller
```

### 9. Persistence Layer Split
Split `persistence.ts` into domain repositories:
```
data/
  persistence.ts        - factory + interface
  memory-store.ts       - in-memory implementation
  postgres-store.ts     - Postgres implementation
  repositories/
    account.repo.ts
    region.repo.ts
    parcel.repo.ts
    object.repo.ts
    social.repo.ts
    economy.repo.ts
```

### 10. Add Testing
```
Minimum viable test suite:
- Auth flow tests (guest, register, login, duplicate name)
- Session expiry test
- Build permission tests (public, owned, collaborator, unauthorized)
- Object CRUD tests
- WebSocket snapshot test
- Currency balance and transfer tests
```

## Medium Priority (Fix This Quarter)

### 11. Database Migrations
Implement a migration system (even simple SQL files with version tracking):
```
migrations/
  001_initial_schema.sql
  002_add_teleport_points.sql
  003_add_social_tables.sql
  004_add_currency.sql
```

### 12. Environment Configuration
Add `.env` support with `dotenv` or Fastify's built-in config:
```env
PORT=3000
DATABASE_URL=postgres://...
ADMIN_BOOTSTRAP_TOKEN=...
CORS_ORIGINS=http://localhost:3000
SESSION_TTL_HOURS=8
LOG_LEVEL=info
```

### 13. Error Handling Standardization
Create a consistent error response format:
```typescript
{
  error: {
    code: "PARCEL_UNAVAILABLE",
    message: "This parcel is already owned by another resident",
    details: { parcelId: "...", ownerId: "..." }
  }
}
```

### 14. WebSocket Reconnection
The browser client has no reconnection logic. The Godot client partially handles disconnects. Both need:
- Automatic reconnection with exponential backoff
- State re-sync after reconnection
- Queued messages during disconnection

### 15. Asset Loading Optimization
- Implement asset caching headers
- Add ETag support for glTF files
- Consider Draco compression for geometry
- Add loading progress indicators
