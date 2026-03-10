# VibeLife

This is a Second Life-inspired virtual world with a modern TypeScript backend and a Godot-based native client direction.

## What is included

- guest account creation endpoint
- region directory endpoint
- Postgres-ready region, account, and inventory persistence
- WebSocket region presence and chat
- Godot native client scaffold connected to the live backend
- region scene manifests and generated glTF assets
- in-world object placement, selection, transform, and deletion tools
- imported avatar models with idle and walk clips
- live WebSocket sync for object creation, updates, and deletion
- parcel-aware build permissions for public and owned land
- avatar appearance controls with outfits, accessories, and synced style updates
- mouse transform gizmos for move, rotate, and scale editing
- wearable outfits and accessories now equip from inventory items
- build snapping and parcel highlight feedback while placing or editing
- multi-select, duplicate, and prefab saving tools for faster building

## Why this is a good 2026-style starting point

- one deployable service for fast iteration
- clean split between auth, region state, and transport layers
- optional Postgres bootstrap gives you a real persistence path without breaking local development
- the backend is already usable from a native viewer instead of being locked to the browser

## Run it

```bash
npm install
npm run dev
```

That starts the backend on `http://localhost:3000`.

Verification:

```bash
npm run check
```

Open the native client from `native-client/godot/project.godot` in Godot 4.2+.

The browser client under `public/` is still available as a debug/admin prototype, but it is no longer the primary client direction.

## Optional Postgres mode

Set `DATABASE_URL` before starting the server. If the connection succeeds, the app creates `regions`, `accounts`, and `inventory_items` automatically and seeds starter regions. If not set, it falls back to in-memory mode.

```bash
set DATABASE_URL=postgres://postgres:postgres@localhost:5432/vibelife
npm run dev
```

For this machine, I wired a local Postgres target to the running container on `127.0.0.1:5432` and created the `vibelife` database, so this shortcut should work:

```bash
npm run dev:postgres
```

## New persistence features

- reuses guest accounts by display name
- saves avatar positions per account and region
- seeds claimable parcels in each region
- lets a connected user claim an unowned parcel

## Scene pipeline

- region layouts live in `public/scenes/*.json`
- reusable world assets live in `public/assets/models/*.gltf`
- regenerate assets with `npm run generate:assets`

## Native client

- primary client scaffold lives in `native-client/godot`
- uses the existing `/api/regions`, `/api/auth/guest`, `/api/regions/:id/objects`, and `/ws/regions/:regionId` backend flow
- imports local glTF assets from `native-client/godot/assets/models` when available and falls back to placeholder geometry when needed
- already includes native login, region, chat, and inventory panels
- includes `native-client/godot/export_presets.cfg` as a starting point for desktop exports
- now includes native build-mode object placement and imported avatar scene usage in Godot
- native client now has parcel-aware build checks and move/rotate/scale editing modes
- native client HUD is now split into a docked layout with status, build controls, inventory, and chat
- native inventory now supports equip/use actions and native object editing now supports axis-handle dragging
- native client now saves backend profiles locally and renders parcel overlays with ownership colors in-world
- native HUD now supports parcel claims plus saved graphics and input settings
- parcel ownership changes now propagate live over WebSocket to both native and browser debug clients
- register/login auth endpoints now exist alongside guest access, with admin moderation controls for parcel reassignment and object cleanup
- browser debug and Godot native clients now both support auth modes and admin parcel/object moderation flows
- admin audit logs now surface in both clients and register/login flows support account-mode switching

## Shared contracts

- shared runtime contract types now live in `src/contracts.ts`
- `scripts/check.mjs` verifies TypeScript build health, Godot duplicate-function regressions, and browser/native asset copy drift

## Auth notes

- guest, register, and login flows now exist side by side
- admin registration now requires `ADMIN_BOOTSTRAP_TOKEN`; display name alone no longer grants admin access
- registered password hashes now use per-account salts instead of a single shared salt
- session expiry is now enforced server-side

## Building tools

- enable build mode in the sidebar after joining a region
- click terrain to place the selected asset
- click one of your placed objects to select it
- use move, rotate, and scale gizmo buttons for mouse-driven editing
- use build snap to place and move objects on a clean grid
- shift-select multiple owned objects and press `Ctrl+D` to duplicate the current selection
- save a selected group as a preset and place that prefab anywhere you have build access
- use arrow keys to move, `Q` and `E` to rotate, `R` and `F` to scale, and `Delete` to remove it
- public parcels allow open building, while owned parcels only allow the owner to place or move objects there
- active parcel boundaries highlight while hovering, placing, or transforming an object

## Avatar styling

- change body, accent, and hair colors from the sidebar
- equip voyager, pilot, or formal wearables from inventory
- equip visor, cape, or utility pack accessories from inventory
- style updates sync live to everyone in the same region

## Suggested next milestones

1. Split region simulation into dedicated workers with interest management.
2. Expand the Godot client into a production viewer with imported assets, animation controllers, and native UI.
3. Add parcel ownership, scripts, and permission graphs.
4. Introduce asset storage and CDN delivery.
5. Add federation or shard-to-shard travel.

## Current roadmap

1. Add instant parcel permission refresh for every open client view.
2. Add stronger moderation tools for parcel reassignment and object cleanup.
3. Add native login persistence with account switching instead of guest-only flow.
4. Replace placeholder/native fallback props with fully imported Godot scene assets.
5. Add animated avatar state machines, emotes, and equipable wearables in Godot.
6. Add native build gizmos with proper axis dragging, snapping, and rotation handles.
7. Add in-world scriptable objects and permissions tied to parcel ownership.
8. Add voice/chat channels, chat history, and social presence systems.
9. Add desktop export automation and per-platform packaging/signing workflow.
10. Add region-worker scaling, persistence hardening, and production deployment setup.
