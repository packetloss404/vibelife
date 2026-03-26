# Code Quality Audit

## File-by-File Analysis

### src/contracts.ts (200 lines) - Grade: A
- Clean, well-typed contract definitions
- Good use of discriminated unions for RegionEvent
- Runtime type guard `isRegionCommand` is properly defensive
- **Issue:** Some contract types duplicate persistence record types - consider generating one from the other

### src/server.ts (1,083 lines) - Grade: C+
- **Major Issue:** All routes in a single file. Should be split into route modules.
- **Issue:** Token passed in request body instead of Authorization header
- **Issue:** No request validation schemas - Fastify supports JSON Schema validation natively
- **Issue:** Repetitive token-checking boilerplate on every route
- **Issue:** No rate limiting
- **Issue:** No CORS origin restriction (origin: true allows everything)
- **Good:** Consistent error response patterns
- **Good:** Proper HTTP status codes

### src/data/persistence.ts (2,180 lines) - Grade: B-
- **Issue:** Massive file handling all data domains
- **Issue:** In-memory implementation duplicates Postgres logic entirely
- **Good:** Clean interface-based abstraction
- **Good:** Auto-schema creation
- **Issue:** No database migrations - schema changes are destructive
- **Issue:** No connection pool configuration
- **Issue:** SQL queries use string interpolation in some places (injection risk)

### src/world/store.ts (950 lines) - Grade: B
- **Issue:** Mixes too many concerns (auth, avatars, parcels, objects, social, economy)
- **Issue:** `addFriend` function has dead code (unused `authenticateAccount` and `getOrCreateGuestAccount` calls)
- **Issue:** `saveObjectPermissions` queries all objects with empty string regionId
- **Good:** Clean session management with expiry
- **Good:** Proper build permission checking with parcel awareness

### src/world/region.ts (60 lines) - Grade: A-
- Clean, focused module
- Proper WebSocket lifecycle management
- **Issue:** No interest management - broadcasts everything to everyone in region
- **Issue:** No message queuing for reconnection

### public/app.js (1,844 lines) - Grade: C
- **Major Issue:** Single monolithic file, no module structure
- **Issue:** Mixed concerns (rendering, networking, UI, state management)
- **Issue:** No error handling for WebSocket disconnects
- **Issue:** Global state scattered across module-level variables
- **Issue:** Still references "ThirdLife" in UI
- **Good:** Functional 3D rendering with glTF loading
- **Good:** Build mode with transform controls works

### native-client/godot/scripts/main.gd (1,297 lines) - Grade: C+
- **Major Issue:** Single monolithic script - Godot best practice is one script per scene node
- **Issue:** Hard-coded UI positions instead of anchor-based layout
- **Issue:** No scene composition (everything built in one script)
- **Issue:** No state machine for avatar/game states
- **Issue:** HTTP requests use blocking patterns
- **Good:** Full API integration
- **Good:** Multiple manipulation modes

## Security Concerns

| Severity | Issue | Location |
|----------|-------|----------|
| HIGH | No rate limiting on auth endpoints | server.ts |
| HIGH | CORS allows all origins | server.ts:85 |
| MEDIUM | Token in body instead of header | All routes |
| MEDIUM | No input sanitization on chat messages | server.ts:1040 |
| MEDIUM | No CSRF protection | All POST routes |
| LOW | Admin bootstrap token in env var | store.ts:162 |
| LOW | Session tokens are UUIDs (predictable format) | store.ts:195 |

## Recommended Quick Fixes

1. **Split server.ts into route modules** using Fastify plugins
2. **Add Fastify schema validation** to all routes
3. **Create auth middleware** to eliminate token-checking boilerplate
4. **Add rate limiting** via `@fastify/rate-limit`
5. **Fix CORS** to whitelist specific origins
6. **Remove dead code** in `addFriend` function
7. **Fix `saveObjectPermissions`** empty string regionId bug
8. **Update all "ThirdLife" references** to "VibeLife"
9. **Add `.env` file support** for configuration
10. **Add basic test suite** with Fastify's testing utilities

## Test Coverage Recommendations

```
Priority 1: Auth flows (guest, register, login, session expiry)
Priority 2: Build permissions (parcel ownership, collaborators, public)
Priority 3: Object CRUD (create, update, delete, permissions)
Priority 4: WebSocket events (join, move, chat, leave)
Priority 5: Social features (friends, groups, currency)
```
