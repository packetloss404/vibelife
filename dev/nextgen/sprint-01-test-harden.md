# Sprint 1: Test & Harden

**Duration:** 1 week
**Goal:** Achieve test coverage for all core sidecar systems. Harden input validation.
**Prerequisite:** Sprint 0 complete.

---

## Current Test Coverage

Existing test files in `src/__tests__/`:
- `auth.test.ts` -- authentication flows
- `chat.test.ts` -- chat messaging
- `objects.test.ts` -- world objects
- `social.test.ts` -- friends, blocking, profiles

## New Test Files Required

### 1. `economy.test.ts`
- Create account with starting balance
- Send currency between accounts
- Reject negative amounts
- Reject overdrafts (insufficient balance)
- Transaction history returns correct entries
- Server-transfer endpoint with API key auth
- Balance lookup by account ID

### 2. `parcels.test.ts`
- Claim a parcel
- Reject duplicate claims on same coordinates
- Transfer parcel ownership
- Add/remove collaborators
- Parcel tier validation
- List parcels by owner
- List parcels by region

### 3. `marketplace.test.ts`
- Create a listing
- Browse listings with pagination
- Buy a listing (transfers currency, changes ownership)
- Cancel own listing
- Reject buying own listing
- Auction: place bid, outbid, auction expiry
- Search/filter listings by category

### 4. `achievements.test.ts`
- Grant achievement to account
- Reject duplicate achievement grants
- Get progress (completed + in-progress)
- Leaderboard endpoint returns sorted results
- Category filtering

### 5. `events.test.ts`
- Create an event
- List upcoming events
- RSVP to an event
- Cancel RSVP
- Event expiry (past events filtered from active list)
- Admin-only event creation

### 6. `guilds.test.ts`
- Create a guild
- Invite a player
- Accept/reject invitation
- Promote/demote members
- Guild treasury deposit/withdraw
- Leave guild
- Disband guild (owner only)
- Alliance creation between guilds

### 7. `homes.test.ts`
- Set home location
- Get home location
- Rate a home
- List top-rated homes
- Delete home

### 8. `pets.test.ts`
- Adopt a pet
- List owned pets
- Rename pet
- Feed/interact with pet
- Release pet

---

## Input Validation Hardening

For every route file in `src/routes/`, add validation for:

### String fields
- Maximum length (names: 32 chars, descriptions: 500 chars, chat: 1000 chars)
- No null bytes or control characters
- Trim whitespace

### Numeric fields
- Integer check where appropriate (amounts, quantities)
- Positive-only where appropriate (currency amounts, page numbers)
- Range limits (page size max 100, limit max 500)

### ID fields
- UUID format validation for account IDs
- Non-empty check

### Auth
- Verify `requireAuth` is applied to all non-public endpoints
- Verify `requireAdmin` is applied to admin-only endpoints
- Verify rate limiting on auth endpoints (login, register)

---

## Acceptance Criteria

- [ ] All 8 new test files pass: `npm run test`
- [ ] Every sidecar route has at least one test exercising the happy path
- [ ] Every sidecar route validates required fields and returns 400 on bad input
- [ ] `npm run check` passes with no warnings
- [ ] No test uses `setTimeout` or real timers -- all tests are deterministic
