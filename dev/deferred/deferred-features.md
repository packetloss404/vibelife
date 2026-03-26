# Deferred Features -- Restoration Guide

Features removed from the PacketCraft codebase on 2026-03-26 during the pivot from
Godot native client to Paper + Fabric + Fastify sidecar architecture. All deleted code
remains in git history. This document catalogues each feature, why it was deferred,
conditions for bringing it back, and which files to reference.

---

## 1. Mobile Client

**What it was:** A companion mobile app (planned as a React Native or Flutter build) that
mirrored social, economy, and marketplace features from the main client. Allowed players
to chat, check balances, and manage marketplace listings on the go.

**Why removed:** The pivot to Fabric mod eliminated the need for a standalone mobile
client. Minecraft players use the desktop Java client; a mobile companion adds
maintenance burden with minimal user value at launch.

**When to bring back:** After launch, if player demand for out-of-game management is
high, or if Bedrock Edition support is added.

**Spec files:** `dev/deferred/mobile-client.md`

**Deleted file paths:**
- `native-client/godot/scripts/experimental/ui/mobile_companion.gd`
- `src/routes/mobile.ts`

---

## 2. Creator Tools

**What it was:** An in-game dashboard for content creators to manage custom assets,
upload blueprints, configure storefronts, and track analytics on their creations.

**Why removed:** Depends on a custom asset pipeline and storefront economy that are not
yet built. Premature to ship creator tools without the underlying infrastructure.

**When to bring back:** After marketplace and storefronts are live, when there is a real
creator ecosystem to support.

**Spec files:** `dev/deferred/specs/creator-tools.md`

**Deleted file paths:**
- `native-client/godot/scripts/experimental/ui/creator_dashboard.gd`
- `native-client/godot/scripts/ui/panels/creator_panel.gd`
- `src/routes/creator-tools.ts`

---

## 3. Federation

**What it was:** Server-to-server federation protocol allowing multiple PacketCraft
instances to share player data, economy, and social graphs. Modeled loosely on
ActivityPub concepts.

**Why removed:** Massive complexity with no immediate user benefit. Federation requires
solving trust, identity, and conflict resolution across independent servers. Not viable
for a single-server launch.

**When to bring back:** When PacketCraft has multiple independent server operators who
want interoperability. Likely post-1.0, after the single-server experience is solid.

**Spec files:** None preserved (was exploratory code only).

**Deleted file paths:**
- `src/routes/federation.ts`

---

## 4. NPC Manager

**What it was:** A system for spawning and controlling non-player characters in the
world. NPCs could patrol routes, engage in scripted dialogue, sell items, and give
quests.

**Why removed:** NPCs require AI pathfinding, dialogue trees, and quest scripting -- all
complex systems that distract from core social features. Paper already has a robust mob
API if simple NPCs are needed later.

**When to bring back:** When a quest or guided-experience system is designed. Could use
Citizens2 plugin as a starting point on Paper.

**Spec files:** None preserved (was Godot-only implementation).

**Deleted file paths:**
- `native-client/godot/scripts/experimental/world/npc_manager.gd`
- `src/routes/npcs.ts`

---

## 5. Scripts (User Scripting)

**What it was:** A sandboxed scripting runtime allowing players to write custom behaviors
for objects in their parcels. Planned as a Lua or restricted JS environment.

**Why removed:** Sandboxed user scripting is a security minefield. Requires a full
runtime sandbox, resource limits, and abuse prevention. Too risky and complex for launch.

**When to bring back:** Post-launch, with a dedicated security review. Consider
leveraging Paper's plugin API or a restricted command-block-style system instead of
arbitrary scripting.

**Spec files:** None preserved (was exploratory code only).

**Deleted file paths:**
- `native-client/godot/scripts/world/script_manager.gd`
- `src/routes/scripts.ts`

---

## 6. Seasonal Events

**What it was:** A time-limited event system with seasonal themes (winter festival,
spring carnival, etc.). Included exclusive items, decorations, challenges, and a seasonal
currency.

**Why removed:** Seasonal content requires a live-ops pipeline, scheduled content drops,
and time-gated rewards. This is operational overhead that is premature before a stable
player base exists.

**When to bring back:** After launch, when there is a regular content cadence and player
retention data to justify seasonal investment.

**Spec files:** `dev/deferred/specs/seasonal.md`

**Deleted file paths:**
- `native-client/godot/scripts/world/seasonal_manager.gd`
- `native-client/godot/scripts/ui/panels/seasonal_panel.gd`
- `src/routes/seasonal.ts`

---

## 7. Interactive Objects

**What it was:** A system allowing placed world objects to respond to player interaction
(sit on benches, open doors, activate switches, play animations). Objects had
configurable interaction types and callbacks.

**Why removed:** The Godot native client handled this with custom GDScript. In the
Fabric + Paper architecture, interactive blocks are handled natively by Minecraft.
Custom interactions can be added via Paper event listeners when needed.

**When to bring back:** When specific interactive furniture or custom block behaviors
are designed. Paper's BlockInteractEvent covers most use cases.

**Spec files:** None preserved (was Godot-only implementation).

**Deleted file paths:**
- `native-client/godot/scripts/world/interactive_manager.gd`
- `src/routes/interactives.ts`

---

## 8. Radio

**What it was:** An in-game radio system where players could tune into music stations.
Stations were configurable per region, with DJ controls and a song queue.

**Why removed:** Audio streaming in a Minecraft mod is technically challenging and
legally complex (music licensing). Not a core social feature.

**When to bring back:** Post-launch, if there is player demand for ambient music.
Could be implemented as external web radio with a simple URL-based player in the
Fabric mod HUD.

**Spec files:** `dev/deferred/specs/radio.md`

**Deleted file paths:**
- `native-client/godot/scripts/audio/radio_controller.gd`
- `native-client/godot/scripts/ui/panels/radio_panel.gd`
- `src/routes/radio.ts`

---

## Restoration Process

To restore any deferred feature:

1. Find the last commit containing the code: `git log --all --oneline -- <path>`
2. Recover files: `git checkout <commit> -- <path>`
3. Review the spec file in `dev/deferred/specs/` (if available)
4. Adapt the implementation to current architecture (Paper + Fabric + Fastify)
5. Add tests before merging
6. Update this document to remove the restored feature
