# VibeLife

A social MMORPG platform built on Minecraft. Uses a Paper server for core gameplay, a Fabric client mod for custom GUI, and a Fastify/TypeScript sidecar for social features, economy, marketplace, achievements, and events.

## Architecture

```
┌─────────────┐     Plugin Messages     ┌───────────────┐
│  Fabric Mod  │◄──────────────────────►│  Paper Plugin  │
│  (Client UI) │                        │  (MC Server)   │
└──────┬───────┘                        └──────┬─────────┘
       │ HTTP (direct)                         │ HTTP (localhost)
       │                                       │
       └──────────►┌──────────────┐◄───────────┘
                   │   Fastify    │
                   │  (Sidecar)   │
                   │  :3000       │
                   └──────────────┘
```

- **Paper Plugin** (Java 21) — Thin bridge: intercepts MC events, calls sidecar REST API, forwards notifications to Fabric mod via plugin message channel
- **Fastify Sidecar** (TypeScript) — All business logic: social, economy, marketplace, achievements, events, parcels, media, and more
- **Fabric Mod** (Java 21) — Custom GUI screens, HUD overlays, keybinds. Calls sidecar HTTP directly for UI data

## Features

### Social
- Friends list, friend requests, blocking, and presence status
- Real-time chat persistence and achievement tracking
- Guilds with roles, treasury, emblems, alliances, and parcel assignment
- Avatar profiles with bios, titles, and play-time stats
- Offline messages and activity feeds

### Economy
- Currency system (Vibes) with balance tracking and transaction history
- Vault API integration — any Vault-compatible plugin works with VibeLife currency
- In-game commands: `/balance`, `/pay <player> <amount>`
- Fabric GUI for full economy management (V key)

### Marketplace
- Fixed-price and auction listings
- Peer-to-peer trading with offer/accept/decline flow
- Storefronts, commissions, and trending items
- In-game `/market` command + full Fabric GUI (M key)

### Parcels & Building
- Parcel-based land ownership with build permissions and collaborators
- Server-side block protection (cached parcel checks + sidecar fallback)
- In-game commands: `/parcel info|claim|release|list`
- Periodic parcel sync from sidecar (source of truth)

### Achievements & Progression
- 5 achievement categories (Explorer, Builder, Social, Collector, Warrior)
- Automatic stat tracking from MC events (block place/break, mob kills, world changes)
- Daily and weekly challenges with XP rewards
- Leaderboards, unlockable titles
- Toast notifications via Fabric mod (J key for full GUI)

### Events & Seasonal
- Player-created events with types, RSVP, and scheduling
- 4 seasons with themed content, 7 holidays with collectibles
- Seasonal achievements and leaderboards
- Fabric GUI (K key)

### Additional Features
- Pets (8 species, adopt/summon/interact/customize)
- In-game photography with filters and galleries
- Home system with privacy, ratings, and doorbell notifications
- Radio stations with genre labels and track skipping
- Voice chat channels with spatial audio
- NPC dialogue trees and quests
- Creator tools platform
- Mobile companion API
- Federation/multi-server support

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Game Server | Paper (Minecraft 1.21.4) |
| Client Mod | Fabric API (Minecraft 1.21.4) |
| Sidecar | TypeScript, Fastify, Node.js |
| Persistence | In-memory Maps + PostgreSQL (dual-mode) |
| Auth | MC UUID linking + guest/register/login flows |
| Build | Gradle 8.12 (Java), npm (TypeScript) |

## Project Structure

```
src/                              # Fastify sidecar
  server.ts                       — Route registration, event system
  contracts.ts                    — Shared types
  routes/                         — 32 Fastify route plugins
  world/                          — 25+ service modules
    store.ts                      — Barrel re-exports
    _shared-state.ts              — Sessions, regions, permissions
  data/
    persistence.ts                — Dual-mode persistence layer

spigot-plugin/                    # Paper server plugin (Java 21, Spigot API)
  src/main/java/com/vibelife/spigot/
    VibeLifePlugin.java           — Main entry, registers all listeners/commands
    bridge/SidecarClient.java     — Async HTTP client for sidecar
    auth/LoginListener.java       — MC UUID → VibeLife account linking
    parcels/ParcelManager.java    — Parcel cache + WorldGuard sync
    parcels/ParcelListener.java   — Block protection via parcel permissions
    economy/VaultProvider.java    — Vault Economy backed by sidecar
    achievements/AchievementHook.java — MC events → achievement stat tracking
    chat/ChatListener.java        — Chat persistence + achievement hooks
    commands/                     — /parcel, /friends, /market, /balance, /pay
    messaging/                    — Plugin channel for Fabric mod

fabric-mod/                       # Fabric client mod (Java 21)
  src/main/java/com/vibelife/fabric/
    VibeLifeClient.java           — Mod entry, session management
    network/SidecarApi.java       — Async HTTP client for sidecar
    network/PluginChannelHandler.java — Server → client notifications
    screen/                       — EconomyScreen, SocialScreen, MarketplaceScreen,
                                    AchievementsScreen, EventsScreen
    hud/AchievementToast.java     — Achievement unlock notifications
    keybind/KeybindManager.java   — V/N/M/J/K keybinds

native-client/                    # DEPRECATED (Godot 4.x client, kept for reference)
```

## Keybinds (Fabric Mod)

| Key | Screen |
|-----|--------|
| V | Economy (balance, send, transactions) |
| N | Social (friends, groups, messages) |
| M | Marketplace (browse, buy, sell, trades) |
| J | Achievements (progress, challenges, leaderboard) |
| K | Events (calendar, RSVP) |

## Setup

### Prerequisites
- Java 21 (OpenJDK)
- Node.js 20+
- Paper 1.21.4 server
- (Optional) PostgreSQL for persistent storage

### Build

```bash
# Sidecar
npm install
npm run dev

# Paper plugin (builds against Spigot API)
cd spigot-plugin
./gradlew build
# Output: build/libs/vibelife-spigot-1.0.0-SNAPSHOT.jar

# Fabric mod
cd fabric-mod
./gradlew build
# Output: build/libs/vibelife-fabric-1.0.0-SNAPSHOT.jar
```

### Deploy

1. Copy `vibelife-spigot-*.jar` to your Paper server's `plugins/` directory
2. Start the Fastify sidecar (`npm run dev`) on the same machine
3. Edit `plugins/VibeLife/config.yml` to set sidecar URL and region mappings
4. Players install `vibelife-fabric-*.jar` in their Fabric mods folder
5. Connect to the MC server — account is auto-created on first join

### Configuration

**Plugin config** (`plugins/VibeLife/config.yml`):
```yaml
sidecar:
  url: "http://localhost:3000"
  api-key: "change-me-in-production"
  timeout-ms: 5000

regions:
  world: "aurora-docks"
  world_nether: "nether-realm"
  world_the_end: "end-realm"
```

**Sidecar environment**:
```bash
PORT=3000                    # Sidecar port
DATABASE_URL=postgres://...  # Optional, falls back to in-memory
CORS_ORIGINS=http://...      # Allowed origins
ADMIN_BOOTSTRAP_TOKEN=...    # For first admin registration
```

## Auth Flow

1. Player joins MC server with their UUID
2. Plugin calls `POST /api/auth/mc-login` with UUID + username
3. Sidecar creates or finds linked VibeLife account, returns session token
4. Token sent to Fabric mod via plugin message channel
5. Fabric mod uses token for all direct sidecar API calls
6. Existing accounts can link via `/vibelife link <displayName> <password>`

## Development

```bash
npm run dev          # Sidecar with hot reload
npm run check        # TypeScript type checking
npm test             # Run test suite
```

### Optional Plugins
- **Vault** — Required for economy integration with other plugins
- **WorldGuard** — Optional, parcels sync to WG regions for native protection

## License

Open source. See repository for details.
