# Sprint 2: Wire Core

**Duration:** 1 week
**Goal:** Add Paper commands and Fabric screens for homes, guilds, and admin. Wire events push integration.
**Prerequisite:** Sprint 1 complete.

---

## Paper Plugin Commands

### 1. Home Commands

**Command:** `/home`

| Subcommand | Description | Permission |
|-----------|-------------|------------|
| `/home set` | Set current location as home | default |
| `/home tp` | Teleport to home | default |
| `/home visit <player>` | Visit another player's home | default |
| `/home rate <player> <1-5>` | Rate a player's home | default |
| `/home top` | List top-rated homes | default |

**Implementation:**
- Create `HomeCommand.java` in `paper-plugin/src/main/java/com/vibelife/paper/commands/`
- Use `SidecarClient.postWithToken()` to forward player session to sidecar
- Teleportation uses Paper's `Player.teleportAsync()` API
- Location stored as world + x/y/z/yaw/pitch in sidecar

### 2. Admin Commands

**Command:** `/pcadmin` (PacketCraft admin)

| Subcommand | Description | Permission |
|-----------|-------------|------------|
| `/pcadmin give <player> <amount>` | Grant currency | `packetcraft.admin` |
| `/pcadmin take <player> <amount>` | Remove currency | `packetcraft.admin` |
| `/pcadmin ban <player> [reason]` | Ban account | `packetcraft.admin` |
| `/pcadmin unban <player>` | Unban account | `packetcraft.admin` |
| `/pcadmin parcel reset <x> <z>` | Unclaim a parcel | `packetcraft.admin` |
| `/pcadmin stats` | Server statistics | `packetcraft.admin` |

**Implementation:**
- Create `AdminCommand.java`
- All subcommands require `packetcraft.admin` permission
- Use `SidecarClient.post()` with API key auth (server-level operations)
- Add tab completion for online player names

### 3. Guild Commands

**Command:** `/guild`

| Subcommand | Description | Permission |
|-----------|-------------|------------|
| `/guild create <name>` | Create a guild | default |
| `/guild invite <player>` | Invite a player | default |
| `/guild accept` | Accept pending invitation | default |
| `/guild leave` | Leave current guild | default |
| `/guild info [name]` | Show guild info | default |
| `/guild deposit <amount>` | Deposit to treasury | default |
| `/guild members` | List guild members | default |
| `/guild promote <player>` | Promote a member | default (guild officer+) |
| `/guild demote <player>` | Demote a member | default (guild officer+) |
| `/guild disband` | Disband the guild | default (guild owner) |

**Implementation:**
- Create `GuildCommand.java`
- Guild ownership/role checks happen on the sidecar side, not in the plugin
- Player must be online and authenticated

---

## Fabric Client Screens

### 4. HomeScreen

**File:** `fabric-mod/src/main/java/com/packetcraft/fabric/screen/HomeScreen.java`

**Layout:**
- Top: "My Home" section showing coordinates, rating, visitor count
- Middle: "Set Home" button, "Teleport Home" button
- Bottom: "Top Homes" scrollable list with player name, rating, visit button

**API calls:**
- `GET /api/homes/mine` -- current player's home
- `POST /api/homes/set` -- set home location
- `GET /api/homes/top` -- leaderboard

### 5. Guild Tab (in SocialScreen)

Rather than a standalone screen, add a guild tab to the existing `SocialScreen`.

**Layout:**
- Guild name, motto, member count
- Member list with roles (Owner, Officer, Member)
- Treasury balance
- Action buttons: Deposit, Invite, Leave

**API calls:**
- `GET /api/guilds/mine` -- current player's guild
- `GET /api/guilds/:id/members` -- member list
- `POST /api/guilds/:id/deposit` -- treasury deposit

### 6. AdminScreen

**File:** `fabric-mod/src/main/java/com/packetcraft/fabric/screen/AdminScreen.java`

**Visibility:** Only shown if player has admin role (checked via sidecar session data).

**Layout:**
- Server stats (player count, parcel count, total currency)
- Player lookup (search by name, view account details)
- Quick actions: give/take currency, ban/unban
- Recent moderation log

**API calls:**
- `GET /api/admin/stats`
- `GET /api/admin/accounts?search=<name>`
- `POST /api/admin/give`, `POST /api/admin/ban`, etc.

---

## Events Push Integration

### 7. WebSocket Event Forwarding

**Problem:** Events (server-wide announcements, achievement unlocks, guild invitations)
are currently only available via polling REST endpoints. Players miss time-sensitive
notifications.

**Solution:**
- The sidecar already has WebSocket support via the session coordinator
- Add event types: `event:created`, `event:starting`, `guild:invited`, `achievement:unlocked`
- Paper plugin: forward WS events as action bar messages or chat notifications
- Fabric mod: show toast notifications for achievements, chat notifications for events

**Implementation:**
- Add `EventPushHandler` in the Paper plugin that listens to sidecar WS
- Add event listener in `VibeLifeClient` that routes to `AchievementToast` and chat

---

## Acceptance Criteria

- [ ] All 3 Paper command sets register and respond correctly
- [ ] Tab completion works for player names in all commands
- [ ] `/pcadmin` commands are restricted to `packetcraft.admin` permission
- [ ] HomeScreen, Guild tab, and AdminScreen render without errors
- [ ] AdminScreen is hidden for non-admin players
- [ ] Event push notifications appear in-game within 2 seconds of sidecar event
- [ ] `./gradlew build` succeeds in both Java projects
