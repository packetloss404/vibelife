# Sprint 4: Pets & Photos

**Duration:** 1 week
**Goal:** Implement pet commands and screen, photography screen, achievement category
filters, and economy name resolution.
**Prerequisite:** Sprint 3 complete.

---

## 1. Pet System

### Paper Commands

**Command:** `/pet`

| Subcommand | Description |
|-----------|-------------|
| `/pet adopt <type>` | Adopt a pet (types: cat, dog, parrot, rabbit, fox) |
| `/pet list` | List owned pets |
| `/pet rename <name>` | Rename active pet |
| `/pet summon` | Summon active pet to follow player |
| `/pet dismiss` | Dismiss active pet |
| `/pet feed` | Feed active pet (costs currency) |
| `/pet release <name>` | Release a pet (permanent) |

**Implementation notes:**
- Pets are cosmetic companions, not Minecraft entities at launch
- Pet state (name, type, hunger, happiness) lives in the sidecar
- Paper plugin shows pet status in action bar when summoned
- Pet feeding costs a small amount of currency (configurable, default 10)
- Future: render pets as invisible armor stands with custom model data

### Fabric PetsScreen

**File:** `fabric-mod/src/main/java/com/packetcraft/fabric/screen/PetsScreen.java`

**Layout:**
- Top: Active pet display (name, type, happiness bar, hunger bar)
- Middle: Owned pets list with "Summon" / "Dismiss" / "Rename" buttons
- Bottom: "Adopt" section showing available pet types with costs
- Feed button with cost display

**API calls:**
- `GET /api/pets` -- list owned pets
- `POST /api/pets/adopt` -- adopt a new pet
- `POST /api/pets/:id/rename` -- rename
- `POST /api/pets/:id/feed` -- feed
- `POST /api/pets/:id/summon` -- summon/dismiss toggle
- `DELETE /api/pets/:id` -- release

---

## 2. Photography System

### Paper Commands

**Command:** `/photo`

| Subcommand | Description |
|-----------|-------------|
| `/photo take` | Take a screenshot and save to gallery |
| `/photo gallery` | Open gallery (hints to use Fabric screen) |
| `/photo like <id>` | Like a photo |
| `/photo top` | Show most-liked photos |

### Fabric PhotographyScreen

**File:** `fabric-mod/src/main/java/com/packetcraft/fabric/screen/PhotographyScreen.java`

**Layout:**
- Top: "Take Photo" button (captures current view, uploads to sidecar)
- Middle: Gallery grid showing thumbnails (own photos)
- Bottom: "Community Photos" tab showing top-rated photos with like counts
- Each photo shows: thumbnail, author, like count, "Like" button

**API calls:**
- `POST /api/photos/upload` -- upload screenshot (base64 encoded)
- `GET /api/photos/mine` -- player's gallery
- `GET /api/photos/top` -- community top photos
- `POST /api/photos/:id/like` -- like a photo
- `DELETE /api/photos/:id` -- delete own photo

**Implementation notes:**
- Screenshot capture uses `MinecraftClient.getInstance().getFramebuffer()`
- Photos are stored as base64 in sidecar (in-memory mode) or as blob references (PostgreSQL mode)
- Thumbnails are downscaled to 128x72 for gallery view
- Full-size view opens on click

---

## 3. Achievement Category Filters

### Fabric AchievementsScreen Enhancements

**Current state:** Shows a flat list of all achievements.

**Add:**
- Category tabs: All, Combat, Social, Economy, Building, Exploration, Events
- Progress bar per category (X/Y completed)
- Filter toggle: Show completed / Show incomplete / Show all
- Achievement detail popup on click (description, date earned, rarity percentage)

**API changes:**
- `GET /api/achievements/progress?category=X` -- filtered by category
- `GET /api/achievements/categories` -- list categories with counts

---

## 4. Economy Name Resolution

### Problem

The `EconomyScreen.sendCurrency()` method requires an `accountId` but the player types
a Minecraft username. There is no resolution step.

### Fix

**Sidecar:**
- Add `GET /api/auth/resolve?username=<name>` endpoint
- Returns `{ accountId, username, online }` or 404

**Fabric EconomyScreen:**
- Before sending currency, call `/api/auth/resolve?username=<input>`
- If resolved, proceed with transfer using the returned `accountId`
- If not found, show "Player not found" error
- Cache resolved names for the session to avoid repeated lookups

**Paper VaultProvider:**
- Implement `hasAccount(String playerName)` and `getBalance(String playerName)`
  using the resolve endpoint
- Enables compatibility with plugins that use name-based Vault calls

---

## Acceptance Criteria

- [ ] `/pet adopt cat` creates a pet, `/pet list` shows it, `/pet feed` deducts currency
- [ ] PetsScreen displays owned pets with all action buttons functional
- [ ] PhotographyScreen captures and displays screenshots
- [ ] Photo likes increment and display correctly
- [ ] AchievementsScreen filters by category
- [ ] Economy send resolves player names to account IDs
- [ ] VaultProvider name-based methods return real data
- [ ] All new endpoints have vitest coverage
- [ ] `npm run check` and `./gradlew build` pass
