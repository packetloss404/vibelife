# VibeLife Minecraft-Style Refactor — Master Plan

## Vision

Refactor VibeLife — a community-owned open-source virtual world MMORPG (Second Life meets Minecraft meets World of Warcraft) — to look, feel, and play like Minecraft while preserving all existing features: combat, pets, economy, guilds, voice, radio, parcels, storefronts, achievements, seasonal events, and more.

## Stack

| Layer | Technology | Entry Point |
|-------|-----------|-------------|
| Server | TypeScript / Fastify | `src/server.ts` |
| Client | Godot 4.6 / GDScript | `native-client/godot/scripts/main.gd` |
| Realtime | WebSocket | `RegionEvent` / `RegionCommand` in `src/contracts.ts` |
| Persistence | In-memory + PostgreSQL | `src/data/persistence.ts` |
| Types | Shared contracts | `src/contracts.ts` |
| Services | 39 service files | `src/world/*.ts`, barrel via `src/world/store.ts` |
| Routes | 48 route files | `src/routes/*.ts` |
| Client Scripts | 75+ GDScript files | `native-client/godot/scripts/**/*.gd` |
| Scene | 1 main scene | `native-client/godot/scenes/main.tscn` |

## Sprint Overview

| Sprint | Name | Phase | Status | Doc |
|--------|------|-------|--------|-----|
| 1 | Voxel World Foundation | 1A, 1B | Not Started | [sprint-01.md](sprints/sprint-01.md) |
| 2 | Player & Camera | 1C, 1D | Not Started | [sprint-02.md](sprints/sprint-02.md) |
| 3 | Mining & Inventory | 2A, 2B | Not Started | [sprint-03.md](sprints/sprint-03.md) |
| 4 | Crafting & Combat | 2C, 2D | Not Started | [sprint-04.md](sprints/sprint-04.md) |
| 5 | Mobs & AI | 2E | Not Started | [sprint-05.md](sprints/sprint-05.md) |
| 6 | World Systems | 3A, 3B, 3C | Not Started | [sprint-06.md](sprints/sprint-06.md) |
| 7 | Sound & Audio | 3D | Not Started | [sprint-07.md](sprints/sprint-07.md) |
| 8 | UI Overhaul | 4A, 4B, 4C, 4D | Not Started | [sprint-08.md](sprints/sprint-08.md) |
| 9 | Multiplayer Integration | 5A, 5B, 5C | Not Started | [sprint-09.md](sprints/sprint-09.md) |
| 10 | Visual Polish | 6A, 6B, 6C | Not Started | [sprint-10.md](sprints/sprint-10.md) |

## Feature Index

### Sprint 1 — Voxel World Foundation
- [terrain-generation.md](features/terrain-generation.md) — Procedural world gen with biomes, caves, ores
- [block-types.md](features/block-types.md) — Expand from 12 to 60+ block types
- [greedy-meshing.md](features/greedy-meshing.md) — Merge adjacent faces to reduce vertex count
- [texture-atlas.md](features/texture-atlas.md) — UV-mapped block textures from atlas
- [chunk-management.md](features/chunk-management.md) — Render distance, LOD, spiral loading, culling

### Sprint 2 — Player & Camera
- [player-model.md](features/player-model.md) — Blocky Steve-style character with animations
- [first-person-camera.md](features/first-person-camera.md) — Mouse look, F5 toggle, crosshair, bob

### Sprint 3 — Mining & Inventory
- [block-breaking.md](features/block-breaking.md) — Hold-to-mine, crack overlay, drops, tool speed
- [inventory-system.md](features/inventory-system.md) — 36 slots, hotbar, armor, drag-and-drop, stacking

### Sprint 4 — Crafting & Combat
- [crafting-system.md](features/crafting-system.md) — 3x3 grid, recipes, furnace smelting
- [hunger-system.md](features/hunger-system.md) — 20 hunger points, food, starvation
- [combat-overhaul.md](features/combat-overhaul.md) — Cooldown, sweep, crit, armor, shield, fall damage

### Sprint 5 — Mobs & AI
- [mob-overhaul.md](features/mob-overhaul.md) — Hostile, passive, neutral mobs with blocky models

### Sprint 6 — World Systems
- [day-night-cycle.md](features/day-night-cycle.md) — 20-min cycle, sun/moon, mob spawning by light
- [lighting-system.md](features/lighting-system.md) — Block light, sky light, BFS propagation
- [voxel-physics.md](features/voxel-physics.md) — AABB collision, gravity, sprint, sneak, swim

### Sprint 7 — Sound & Audio
- [sound-system.md](features/sound-system.md) — Block sounds, ambient, music, mob, UI, combat audio

### Sprint 8 — UI Overhaul
- [minecraft-hud.md](features/minecraft-hud.md) — Hotbar, hearts, hunger, XP bar, crosshair
- [escape-menu.md](features/escape-menu.md) — Pause menu, settings, social/economy overlays
- [title-screen.md](features/title-screen.md) — Main menu with panorama, server browser
- [inventory-screen.md](features/inventory-screen.md) — E-key overlay, armor, mini-craft, drag-drop

### Sprint 9 — Multiplayer Integration
- [chat-overhaul.md](features/chat-overhaul.md) — Fade messages, T to type, commands, colors
- [player-interactions.md](features/player-interactions.md) — Radial menu, trade, inspect, party
- [feature-integration.md](features/feature-integration.md) — Adapt pets, radio, economy, guilds, parcels, etc.

### Sprint 10 — Visual Polish
- [block-textures.md](features/block-textures.md) — 16x16 pixel art atlas, per-face UVs
- [particles-system.md](features/particles-system.md) — Break, torch, splash, XP orb, weather particles
- [sky-weather.md](features/sky-weather.md) — Skybox, sun/moon, clouds, rain, thunder, snow

## Architecture Principles

### What Changes
- World rendering: flat plane → full voxel terrain
- Player: colored capsule → blocky character model
- Camera: orbit-only → first-person default
- UI: panel-heavy sidebar → minimal Minecraft HUD
- Combat: click-to-attack → hold-to-mine, cooldown melee
- Inventory: none → 36-slot with hotbar
- Mobs: abstract shapes → blocky Minecraft-style models

### What Stays
- Server framework (Fastify)
- WebSocket protocol (RegionEvent / RegionCommand unions)
- Authentication (token-based)
- Persistence (dual memory + postgres)
- Service file pattern (individual service files)
- All existing features (adapted visually, not removed)
- Client-server architecture
- Contracts-based type system

### File Organization
- New client scripts → `native-client/godot/scripts/<category>/`
- New server services → `src/world/`
- New routes → `src/routes/`
- All new types → `src/contracts.ts`
- New events/commands → `RegionEvent` / `RegionCommand` unions
- New services → exported through `src/world/store.ts`

### Performance Targets
| Metric | Target |
|--------|--------|
| FPS | 60 at 8-chunk render distance |
| Chunk mesh build | < 50ms |
| Chunk load from server | < 200ms |
| Vertices per chunk | < 10,000 (greedy meshing) |
| Visible entities | 50+ without FPS drop |

### Godot 4.6 Requirements
- Use explicit typing (`var x: Type = ...`) not `:=` when RHS is Variant
- Prefix unused params with `_`
- Don't shadow built-in method names (e.g., `tr`, `name`)
- Use `PackedByteArray`, `PackedVector3Array` for performance
- Use `SurfaceTool` for mesh generation
- All UI built in code (no scene instancing for dynamic UI)

## Priority Order

1. Sprint 1 (voxel world + blocks) — foundation everything builds on
2. Sprint 2 (player model + first-person camera) — makes it feel like Minecraft immediately
3. Sprint 8 (UI overhaul) — remove current UI clutter, add Minecraft HUD
4. Sprint 3 (mining + inventory) — core gameplay loop
5. Sprint 6 (physics, lighting, day/night) — world feels alive
6. Sprint 5 (mobs) — populate the world
7. Sprint 4 (crafting + combat) — depth
8. Sprint 7 (sound) — immersion
9. Sprint 9 (multiplayer integration) — social features adapted
10. Sprint 10 (visual polish) — final coat of paint
