# ThirdLife 2026 Prototype

This is a minimal Second Life-inspired prototype using a modern TypeScript service instead of the original multi-daemon era architecture.

## What is included

- guest account creation endpoint
- region directory endpoint
- Postgres-ready region, account, and inventory persistence
- WebSocket region presence and chat
- browser 3D viewer with click-to-move avatar sync
- region scene manifests and generated glTF assets

## Why this is a good 2026-style starting point

- one deployable service for fast iteration
- clean split between auth, region state, and transport layers
- optional Postgres bootstrap gives you a real persistence path without breaking local development
- browser-first 3D client lets you validate social loops before investing in a heavier custom viewer

## Run it

```bash
npm install
npm run dev
```

Then open `http://localhost:3000`.

## Optional Postgres mode

Set `DATABASE_URL` before starting the server. If the connection succeeds, the app creates `regions`, `accounts`, and `inventory_items` automatically and seeds starter regions. If not set, it falls back to in-memory mode.

```bash
set DATABASE_URL=postgres://postgres:postgres@localhost:5432/thirdlife
npm run dev
```

For this machine, I wired a local Postgres target to the running container on `127.0.0.1:5432` and created the `thirdlife` database, so this shortcut should work:

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

## Suggested next milestones

1. Split region simulation into dedicated workers with interest management.
2. Replace the browser viewer with a WebGPU or Unity/Godot production client.
3. Add parcel ownership, scripts, and permission graphs.
4. Introduce asset storage and CDN delivery.
5. Add federation or shard-to-shard travel.
