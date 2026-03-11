# Development Documentation

This directory contains technical implementation specs for VibeLife features — both pending and planned.

For the strategic codebase review, architecture analysis, and feature roadmap, see [docs/review/](../review/README.md).

## Implemented Features (No Spec Doc)

These features are built and working but don't have standalone spec documents. Their implementation lives directly in the codebase:

| Feature | Where to Find It |
|---------|-----------------|
| Inter-region Teleportation | `src/world/store.ts` — `teleportToRegion()` |
| Avatar Animations (Godot) | `native-client/godot/scripts/main.gd` |
| In-world Scripting | `src/world/store.ts` — `createObjectScript()` and related |
| Asset Library System | `src/world/store.ts` — `listAssets()`, `createAsset()`, `deleteAsset()` |
| Friend/Block Lists | `src/world/store.ts` — `addFriend()`, `blockAccount()` and related |
| Group/Guild System | `src/world/store.ts` — `createGroup()`, `addGroupMember()` and related |
| Instant Messaging | `src/world/store.ts` — `sendOfflineMessage()`, `listOfflineMessages()` |
| Linden-like Currency | `src/world/store.ts` — `sendCurrency()`, `getCurrencyBalance()` |
| Object Permissions | `src/world/store.ts` — `saveObjectPermissions()` |
| Region Events/Notices | `src/world/store.ts` — `createRegionNotice()`, `listRegionNotices()` |
| Avatar Profiles | `src/world/store.ts` — `saveAvatarProfile()`, `getAvatarProfile()` |
| Teleport Landing Points | `src/world/store.ts` — `createTeleportPoint()`, `listTeleportPoints()` |
| Multi-region Persistence | `src/data/persistence.ts` — full Postgres + in-memory layer |
| Moderation Tools | `src/world/store.ts` — `banAccount()`, `adminAssignParcel()`, audit logs |
| Parcel Collaborators | `src/world/store.ts` — `addParcelCollaborator()`, `removeParcelCollaborator()` |

## Pending Feature Specs

Full implementation specs for features still in the planning phase:

| Feature | Spec | Priority | Review Cross-Reference |
|---------|------|----------|----------------------|
| [Voice Chat (VoIP)](voice-chat.md) | WebRTC architecture, signaling, spatial audio | High | [Review: Feature Roadmap T3](../review/04-feature-roadmap.md) |
| [Region Simulation Workers](region-workers.md) | Worker pool, Redis pub/sub, Docker deployment | Critical | [Review: Architecture](../review/02-architecture-review.md) |
| [Parcel Tier Upgrades](parcel-tier-upgrades.md) | Premium tiers, pricing, DB schema | Medium | [Review: Feature Roadmap T2](../review/04-feature-roadmap.md) |
| [Parcel Traffic Analytics](traffic-analytics.md) | Event tracking, daily/hourly stats, privacy | Low | [Review: Feature Roadmap T2](../review/04-feature-roadmap.md) |
| [Mobile Client](mobile-client.md) | React Native, Zustand, touch controls | Low | [Review: Feature Roadmap T4](../review/04-feature-roadmap.md) |

## Contributing

To add documentation for a new feature:

1. Create a markdown file in this directory
2. Follow the existing document structure (overview, architecture, API contracts, DB schema, implementation notes)
3. Update this index to reference the new document
4. Add a cross-reference to the relevant review roadmap section if applicable
