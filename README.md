# VibeLife

An open-source virtual world MMORPG built with a TypeScript/Fastify backend and a Godot 4.x native client. Think Second Life meets Minecraft meets an RPG — build, fight, socialize, and create in a persistent shared world.

**[Game Manual](docs/manual/index.html)** | **[Developer Manual](docs/devmanual/index.html)** | **[Website](docs/index.html)**

## Features

### World & Building
- Persistent shared regions with real-time multiplayer via WebSocket
- Parcel-based land ownership with build permissions and collaborators
- Object placement, transform gizmos (move/rotate/scale), snapping, and undo
- Blueprint system — save, load, and share prefab builds
- Region scene manifests and generated glTF assets

### Voxel Engine
- 16x64x16 chunk-based voxel world with terrain generation
- 13 block types with RLE compression for network efficiency
- Place and break blocks in real-time (synced to all players)
- Voxel blueprints and a custom block shop
- LRU chunk cache with distance-based streaming

### RPG Combat
- Player stats (HP, Mana, Strength, Defense), XP, and leveling
- 5 enemy types (Slime, Skeleton, Golem, Shadow, Drake) with AI state machines
- Melee and magic attack styles with damage formulas and critical hits
- Loot tables with currency and item drops
- Death penalties, respawn system, and HP/Mana regeneration

### Social
- Friends list, friend requests, blocking, and presence status
- Real-time region chat, whispers, and group chat
- Guilds with roles, treasury, emblems, alliances, and parcel assignment
- Avatar profiles with bios, titles, and play-time stats
- Offline messages and activity feeds
- Emote system with combo detection

### Economy
- Currency system with balance tracking and transaction history
- Marketplace with fixed-price and auction listings
- Peer-to-peer trading with offer/accept/decline flow
- Storefronts, commissions, and trending items
- Creator tools with asset submission, analytics, and revenue tracking

### Progression
- 5 achievement categories (Explorer, Builder, Social, Collector, Warrior)
- Daily and weekly challenges with XP rewards
- Leaderboards by category
- Unlockable titles

### Pets
- 8 species (Cat, Dog, Bird, Bunny, Fox, Dragon, Slime, Owl)
- Adopt, summon, feed, play, pet, and teach tricks
- Pet customization (colors, accessories), leveling, and happiness/energy

### Media & Photography
- In-game camera mode with 8 filters (vintage, noir, warm, cool, dreamy, pixel, posterize)
- Photo gallery with likes, comments, and visibility controls
- In-world media objects (photo frames, billboards, slideshows)

### Homes
- Set home parcel with teleport-home support
- Privacy controls (public, friends-only, private)
- Home ratings, favorites, featured homes, and visitor counts
- Doorbell notifications when visitors arrive

### Events & Seasonal
- Player-created events with types, RSVP, and scheduling
- 4 seasons with themed world visuals (fog, sky, particles)
- 7 holidays with collectible seasonal items
- Seasonal achievements and leaderboards

### Radio & Voice
- Multi-station radio with genre labels and track skipping
- Voice chat channels with join/leave, mute, deafen
- Spatial audio with distance-based volume falloff
- Speaking indicators on avatars

### Platform
- Mobile companion service (REST API for mobile clients)
- Federation/multi-server architecture
- AI NPCs with dialogue trees and behavior states
- VR support service
- Creator tools platform with plugins, webhooks, and API keys

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Server | TypeScript, Fastify, Node.js |
| Client | Godot 4.x, GDScript |
| Transport | WebSocket (real-time), REST (CRUD) |
| Persistence | In-memory Maps + PostgreSQL (dual-mode) |
| Auth | Guest, Register, Login with per-account salted hashes |

## Architecture

```
src/
  server.ts          — Route registration, WS handlers, tick loops
  contracts.ts       — Shared types (RegionEvent, RegionCommand unions)
  routes/            — 37 Fastify route plugins
  world/             — 30+ service modules
    store.ts         — Barrel re-exports from all services
    _shared-state.ts — Sessions, regions, shared helpers
  data/
    persistence.ts   — Dual-mode persistence layer

native-client/godot/
  scripts/
    main.gd          — Entry point, module init, WS handling
    network/         — Session coordinator, WS event router
    ui/              — 15 GUI panels, panel manager, toast system
    world/           — Object, avatar, voxel, pet, enemy managers
    build/           — Build controller, blueprints, grid, undo
    visual/          — Sky, weather, day/night, particles, materials
    audio/           — Radio controller
    camera/          — Camera controller
  scenes/
    main.tscn        — Scene tree with responsive UI anchoring
```

## Run It

```bash
npm install
npm run dev
```

Backend starts on `http://localhost:3000`. Open the Godot project at `native-client/godot/project.godot` in Godot 4.2+ and connect.

## Development

```bash
npm run dev          # Backend only
npm run dev:local    # Guided local startup
npm run dev:postgres # Backend with local Postgres
npm run check        # Full verification (TypeScript + Godot + asset drift)
```

### Optional PostgreSQL

Set `DATABASE_URL` to use persistent storage. Falls back to in-memory mode if not set.

```bash
export DATABASE_URL=postgres://postgres:postgres@localhost:5432/vibelife
npm run dev
```

### Scene Pipeline

- Region layouts: `public/scenes/*.json`
- World assets: `public/assets/models/*.gltf`
- Regenerate: `npm run generate:assets`

## Client GUI

The Godot client features a tabbed panel system with 15 feature panels:

| Tab | Features |
|-----|----------|
| Chat | Region chat, whispers, group chat channel selector |
| Inventory | Item list, equip, use |
| Social | Friends, requests, blocking, presence, offline messages |
| Economy | Balance, send currency, transaction history |
| Market | Browse, buy, sell, auction, bid, trade offers |
| Guild | Create/join, members, treasury, settings, alliances |
| Achievements | Progress, challenges, leaderboards, titles |
| Events | Upcoming, create, RSVP |
| Pets | Adopt, summon, interact, customize |
| Photos | Camera mode, gallery, likes, comments |
| Radio | Stations, now playing, skip, volume |
| Seasonal | Items, collection progress, achievements |
| Voice | Join/leave, mute/deafen, participants |
| Creator | Asset submission, analytics, revenue |
| Admin | Bans, parcel/object management, audit log |

Plus: currency HUD, toast notifications, right-click context menus, and responsive viewport scaling.

## WebSocket Protocol

**13 commands** (client -> server): move, chat, whisper, radio:tune, radio:skip, emote, typing, sit, stand, group_chat, voxel:place_block, voxel:break_block, combat:attack

**43 events** (server -> client): snapshot, avatar:joined/moved/updated/left/typing/emote/sit/stand, chat, whisper, chat:history, object:created/updated/deleted, parcel:updated, media:created/updated/removed, pet:summoned/dismissed/trick/state_updated, voice:participant_joined/left/speaking_changed, radio:changed, emote:combo, group:chat, home:doorbell, event:started/ended, voxel:chunk_data/block_placed/block_broken, combat:damage/death/respawn/loot/level_up, enemy:spawned/moved/despawned

## Auth

- Guest, register, and login flows
- Admin registration requires `ADMIN_BOOTSTRAP_TOKEN`
- Per-account salted password hashes
- Server-side session expiry with TTL management
- Rate limiting: 60 req/min global, 5-10 req/min on auth endpoints
- CORS whitelist with configurable `CORS_ORIGINS`

## Documentation

- **[Game Manual](docs/manual/index.html)** — Player-facing guide covering all features
- **[Developer Manual](docs/devmanual/index.html)** — Architecture, services, API reference, and how-to guides
- **[Website](docs/index.html)** — Interactive project website
- **[Sprint Plans](dev/rev3/)** — Rev3 GUI sprint documentation

## Contributing

VibeLife is open source. The developer manual covers how to add new services, routes, WebSocket commands, and client modules with step-by-step guides.

## License

Open source. See repository for details.
