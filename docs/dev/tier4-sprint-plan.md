# Tier 4 Sprint Plan — VibeLife

> "We're not building the metaverse. We're building *five* metaverses at the same time, which is definitely fine."

**Sprint Duration:** 2 weeks each
**Total Tier 4 Window:** 10 weeks (5 sprints)
**Methodology:** Agile with five parallel tracks. One standup to rule them all.
**Team Size:** 5 senior developers, each owning a full feature track

---

## Team Assignments

| Dev | Feature | Track |
|-----|---------|-------|
| Dev 1 | Feature 16: Mobile Companion App | Mobile |
| Dev 2 | Feature 17: Creator Tools Platform | Creator |
| Dev 3 | Feature 18: Federation / Multi-Server | Federation |
| Dev 4 | Feature 19: AI NPCs | NPCs |
| Dev 5 | Feature 20: VR Support | VR |

---

## Definition of Done (Global)

Every story across every sprint must meet ALL of the following before it leaves the board:

- [ ] Feature works in both solo and multiplayer contexts (where applicable)
- [ ] No regressions in existing Tier 1/Tier 2/Tier 3 functionality
- [ ] Unit tests written and passing
- [ ] Integration tested against the dev region server
- [ ] Code reviewed by at least one other dev (cross-track reviews are encouraged and earn karma)
- [ ] No `TODO: fix this later` comments that are older than the sprint itself
- [ ] Performance profiled — no single feature may drop client FPS below 30 on desktop, 24 on mobile, or 45 on VR (72 target)
- [ ] API contracts documented for any new endpoints or protocols
- [ ] Security review completed for any auth, identity, or cross-server communication changes
- [ ] Merged to `develop` without causing an incident
- [ ] Feature flag exists and defaults to OFF in production until the full track is complete

---

## Tier 3 Dependencies

Several Tier 4 features depend on Tier 3 systems. These must be stable before dependent work begins:

| Tier 4 Feature | Depends On | Tier 3 Source | Status |
|----------------|-----------|---------------|--------|
| AI NPCs | Visual Scripting (behavior trees build on state machines) | Sprint 1: The Brain | Implemented |
| AI NPCs | Voice Chat (NPC voice lines use spatial audio pipeline) | Sprint 2: Talk To Me | Implemented |
| VR Support | Voice Chat (spatial audio in VR) | Sprint 2: Talk To Me | Implemented |
| VR Support | In-World Scripting (VR building uses script triggers) | Sprint 1: The Brain | Implemented |
| Mobile Companion App | Photography (mobile gallery sync) | Sprint 4: Say Cheese | Implemented |
| Creator Tools Platform | In-World Scripting (plugin SDK extends scripting) | Sprint 1: The Brain | Implemented |
| Federation | Moderation Tools (federated moderation) | Tier 2 | Implemented |

---

## Cross-Feature Dependencies (Tier 4 Internal)

These are the points where the five parallel tracks intersect. Coordinate or die.

| Dependency | Producer | Consumer | Sprint | Notes |
|-----------|----------|----------|--------|-------|
| Auth token format changes for federation | Dev 3 (Federation) | Dev 1 (Mobile) | Sprint 2 | Mobile must support federated identity tokens |
| NPC marketplace integration | Dev 4 (NPCs) | Dev 2 (Creator Tools) | Sprint 4 | Shopkeeper NPCs use the creator marketplace API |
| Spatial audio abstraction layer | Dev 5 (VR) | Dev 4 (NPCs) | Sprint 2 | Both VR and NPC voice lines use spatial audio — share the abstraction |
| Asset pipeline format | Dev 2 (Creator Tools) | Dev 5 (VR) | Sprint 1 | VR assets must go through the same pipeline |
| Server registry API | Dev 3 (Federation) | Dev 1 (Mobile) | Sprint 3 | Mobile server browser consumes the registry |
| Federated marketplace API | Dev 3 (Federation) | Dev 2 (Creator Tools) | Sprint 4 | Creator analytics must account for cross-server sales |

---

## Sprint Calendar Overview

```
           Dev 1 (Mobile)      Dev 2 (Creator)     Dev 3 (Federation)  Dev 4 (NPCs)        Dev 5 (VR)
           ──────────────      ───────────────      ──────────────────  ────────────         ──────────
Wk 1–2    Mobile Core &       Asset Pipeline &     Server Registry &   NPC Entity Model &   XR Init &
Sprint 1   Data Sync           Review Queue         Discovery           Behavior Trees       Hand Tracking
           "Phone Home"        "The Pipeline"       "Hello, World(s)"   "It's Alive"         "Jazz Hands"

Wk 3–4    Push Notifications  Analytics Dashboard  Cross-Server         Dialogue System &    Spatial Audio &
Sprint 2   & Offline Queue     & Revenue Sharing    Teleportation        Shopkeepers          Comfort Options
           "Ping!"             "Show Me the Money"  "Beam Me Up"         "What're Ya Buyin?"  "Don't Hurl"

Wk 5–6    Mobile Chat &       Plugin SDK &         Shared Identity &    Quest-Givers &       VR UI &
Sprint 3   Friends              API Extensions       Federated Auth       Tour Guides          Locomotion
           "Pocket Social"     "Mod Support"        "One Ring"           "Follow Me!"         "Moving In Space"

Wk 7–8    Marketplace Browse  Creator Storefronts  Federated            NPC Scripting &      VR Building &
Sprint 4   & Inventory Mgmt    & Publishing         Marketplace          Customization        Object Manipulation
           "Window Shopping"   "Open For Business"  "Global Trade"       "Your NPCs, Rules"   "Build With Hands"

Wk 9–10   Simplified 3D View  Polish, Docs &       Federation Polish    NPC Polish &         VR Polish &
Sprint 5   & Quick Teleport     SDK Documentation    & Stress Testing     Performance Tuning   Performance Tuning
           "Mini World"        "Ship It"            "Stress Test"        "Smarter, Not Harder" "Smooth Operator"
```

---

## Sprint 1: Foundations

**Dates:** Weeks 1-2
**Sprint Goal:** Every track lays its architectural foundation. No UI chrome, no polish — just the bones that everything else will hang on.

---

### Track: Mobile Companion App (Dev 1) — "Phone Home"

#### 1.M1 — Mobile Session Management
**Points:** 8

Establish mobile client authentication and lightweight session handling.

**Acceptance Criteria:**
- [ ] Mobile client authenticates via the same OAuth flow as desktop (with PKCE)
- [ ] Sessions persist across app backgrounding and foregrounding
- [ ] Session tokens are stored securely in platform keychain (iOS Keychain / Android Keystore)
- [ ] Automatic token refresh with exponential backoff on failure
- [ ] Graceful degradation when offline — app launches to cached state, not a crash

#### 1.M2 — Lightweight Data Sync Protocol
**Points:** 8

Design and implement the sync protocol between mobile client and server.

**Acceptance Criteria:**
- [ ] Delta-based sync — only changed data is transferred, not full state dumps
- [ ] Sync works over both WiFi and cellular with adaptive payload sizes
- [ ] Conflict resolution strategy defined and implemented (server wins, with client notification)
- [ ] Sync operations are idempotent — retries don't create duplicates
- [ ] Battery-aware sync scheduling — less frequent syncs when battery is below 20%

---

### Track: Creator Tools Platform (Dev 2) — "The Pipeline"

#### 1.C1 — Asset Pipeline: Upload & Validation
**Points:** 8

Ingest pipeline for creator-submitted assets from external tools.

**Acceptance Criteria:**
- [ ] Upload endpoint accepts glTF 2.0, OBJ, and FBX formats
- [ ] Automatic validation: poly count limits, texture resolution limits, file size caps
- [ ] Asset is converted to the internal VibeLife format on upload
- [ ] Validation errors return human-readable messages with fix suggestions
- [ ] Upload progress is trackable via a status endpoint (queued, processing, complete, failed)

#### 1.C2 — Asset Review Queue
**Points:** 8

Moderation queue for submitted assets before they go live.

**Acceptance Criteria:**
- [ ] Submitted assets enter a review queue visible to designated reviewers
- [ ] Reviewers can approve, reject (with reason), or request changes
- [ ] Approved assets are automatically published to the marketplace
- [ ] Review queue has filtering by status, submission date, and creator
- [ ] Review decisions are logged in the audit trail with reviewer identity and timestamp

---

### Track: Federation / Multi-Server (Dev 3) — "Hello, World(s)"

#### 1.F1 — Server Registry & Discovery
**Points:** 8

Central registry where VibeLife server instances announce themselves and discover peers.

**Acceptance Criteria:**
- [ ] Servers register with a discovery endpoint providing: name, URL, version, region list, player count
- [ ] Registry supports heartbeat-based health checks (30-second interval)
- [ ] Servers that miss 3 heartbeats are marked as offline
- [ ] Registry API returns paginated server list with search/filter
- [ ] Registration requires a shared secret or mutual TLS — no random servers joining the federation

#### 1.F2 — Federation Protocol Handshake
**Points:** 8

Define and implement the server-to-server communication protocol.

**Acceptance Criteria:**
- [ ] Servers authenticate to each other using mutual TLS with pinned certificates
- [ ] Protocol version negotiation on handshake (forward compatibility)
- [ ] Message format is defined (protobuf or MessagePack — not raw JSON over the wire)
- [ ] Handshake completes in under 500ms on a healthy connection
- [ ] Connection failures are retried with exponential backoff and circuit breaker

---

### Track: AI NPCs (Dev 4) — "It's Alive"

#### 1.N1 — NPC Entity Model
**Points:** 8

Define how NPCs exist in the world as entities distinct from player avatars.

**Acceptance Criteria:**
- [ ] NPCs are first-class entities with position, rotation, appearance, and metadata
- [ ] NPC entities are synchronized to clients via the existing entity sync protocol
- [ ] NPCs are owned by either a parcel, a region, or the system
- [ ] NPC spawn/despawn is server-authoritative
- [ ] Maximum NPC count per region is configurable and enforced (default: 50)

#### 1.N2 — Behavior Tree Engine
**Points:** 8

Runtime engine for NPC behavior trees that drives decision-making.

**Acceptance Criteria:**
- [ ] Behavior tree supports standard node types: sequence, selector, parallel, decorator, leaf
- [ ] Trees are defined in a JSON format that can be authored via the visual scripting editor
- [ ] Tree evaluation is tick-based with configurable tick rate per NPC (default: 5 Hz)
- [ ] Behavior trees run server-side only — clients receive the results, not the logic
- [ ] A single region server can evaluate 50 NPC behavior trees at < 5% CPU overhead

---

### Track: VR Support (Dev 5) — "Jazz Hands"

#### 1.V1 — XR Runtime Initialization
**Points:** 8

Initialize the XR subsystem and establish a VR session in the Godot client.

**Acceptance Criteria:**
- [ ] OpenXR integration via Godot's XRInterface
- [ ] Supports Meta Quest 2/3/Pro and SteamVR headsets at launch
- [ ] VR mode is a launch flag — the same client binary works for both desktop and VR
- [ ] Headset tracking (6DoF) is mapped to the avatar head with correct scale
- [ ] Fallback to desktop mode if no headset is detected (graceful, not a crash)

#### 1.V2 — Hand Tracking Input
**Points:** 8

Map hand/controller input to in-world interactions.

**Acceptance Criteria:**
- [ ] Controller tracking with 6DoF for both hands
- [ ] Hand presence is visible to other players (hand models rendered on avatar)
- [ ] Grip and trigger inputs are mapped to grab and interact actions
- [ ] Hand tracking (controllerless) is supported on Quest devices
- [ ] Input abstraction layer allows the same actions to work with controllers and hand tracking

---

## Sprint 2: Core Mechanics

**Dates:** Weeks 3-4
**Sprint Goal:** Each track builds its primary interaction mechanic. This is where features start to feel like features.

---

### Track: Mobile Companion App (Dev 1) — "Ping!"

#### 2.M1 — Push Notification System
**Points:** 8

Server-to-mobile push notifications for important events.

**Acceptance Criteria:**
- [ ] Integration with APNs (iOS) and FCM (Android)
- [ ] Notification types: friend request, direct message, event reminder, marketplace sale
- [ ] Users can configure which notification types they receive
- [ ] Notifications are batched — no more than 1 push per minute per user
- [ ] Notification taps deep-link to the relevant screen in the app

#### 2.M2 — Offline Message Queue
**Points:** 5

Queue messages and events that arrive while the mobile app is backgrounded.

**Acceptance Criteria:**
- [ ] Messages received while offline are queued server-side (max 500 per user)
- [ ] On app foreground, queued messages sync in chronological order
- [ ] Queue entries expire after 7 days
- [ ] Queue size is visible in the notification badge count
- [ ] Duplicate messages are deduplicated on sync

---

### Track: Creator Tools Platform (Dev 2) — "Show Me the Money"

#### 2.C1 — Creator Analytics Dashboard
**Points:** 8

Real-time analytics for creators about their published assets.

**Acceptance Criteria:**
- [ ] Dashboard shows: views, downloads, purchases, revenue, and ratings per asset
- [ ] Time-range filtering: 24h, 7d, 30d, all-time
- [ ] Trend charts with daily granularity
- [ ] Top-performing assets are highlighted
- [ ] Data refreshes at most every 5 minutes (not real-time — don't melt the DB)

#### 2.C2 — Revenue Sharing System
**Points:** 8

Split marketplace revenue between the platform and creators.

**Acceptance Criteria:**
- [ ] Configurable revenue split (default: 70% creator, 30% platform)
- [ ] Revenue is tracked per transaction with creator ID, asset ID, amount, and split
- [ ] Creators can view their earnings and payout history
- [ ] Payout threshold and schedule are configurable (default: payout at 1000 VibeCoins)
- [ ] Revenue calculations are auditable — every coin is accounted for

---

### Track: Federation / Multi-Server (Dev 3) — "Beam Me Up"

#### 2.F1 — Cross-Server Teleportation
**Points:** 13

Players can teleport from one VibeLife server to another seamlessly.

**Acceptance Criteria:**
- [ ] Teleport UI shows available servers from the registry with player counts
- [ ] Teleport initiates a handoff: source server sends player state to destination server
- [ ] Player state transfer includes: avatar appearance, inventory snapshot, and active effects
- [ ] Teleport completes in under 3 seconds on healthy connections
- [ ] Failed teleports return the player to their origin with an error message (no limbo state)
- [ ] Rate limiting: max 1 cross-server teleport per 30 seconds per player

#### 2.F2 — Federation State Reconciliation
**Points:** 5

Handle the edge cases when servers disagree about world state.

**Acceptance Criteria:**
- [ ] State conflicts are resolved using vector clocks or CRDT-based merge
- [ ] Player inventory is authoritative on the player's home server
- [ ] Visiting players on a foreign server operate with a read-only inventory snapshot
- [ ] State reconciliation logs all conflicts for debugging
- [ ] Network partitions are detected and surfaced to server admins

---

### Track: AI NPCs (Dev 4) — "What're Ya Buyin'?"

#### 2.N1 — Dialogue System
**Points:** 8

Conversation system for NPC interactions with branching dialogue.

**Acceptance Criteria:**
- [ ] Dialogue trees are defined in a JSON format with nodes, choices, and conditions
- [ ] NPCs display dialogue in speech bubbles with a typewriter effect
- [ ] Player choices affect dialogue state (tracked per player per NPC)
- [ ] Dialogue can trigger behavior tree events (e.g., NPC walks to a location after conversation)
- [ ] Dialogue supports variable interpolation (player name, time of day, quest state)

#### 2.N2 — Shopkeeper NPCs
**Points:** 8

NPCs that sell items from the marketplace with a conversational interface.

**Acceptance Criteria:**
- [ ] Shopkeeper NPCs are tied to a curated list of marketplace items
- [ ] Interacting with a shopkeeper opens a shop UI with browse, inspect, and purchase
- [ ] Shopkeepers have personality-flavored dialogue ("You look like someone who needs a hat.")
- [ ] Purchase transactions go through the standard marketplace transaction system
- [ ] Shopkeeper inventory can be configured per parcel by the parcel owner

---

### Track: VR Support (Dev 5) — "Don't Hurl"

#### 2.V1 — VR Spatial Audio
**Points:** 8

Adapt the existing spatial audio system for VR with proper HRTF and head tracking.

**Acceptance Criteria:**
- [ ] Audio sources are spatialized relative to the headset position and orientation
- [ ] HRTF processing provides convincing directional audio
- [ ] Existing voice chat integrates with VR spatial audio (no separate pipeline)
- [ ] Audio occlusion: walls and objects attenuate sound realistically
- [ ] Performance: spatial audio processing adds no more than 1ms per frame on Quest 3

#### 2.V2 — Comfort Options
**Points:** 5

Anti-nausea and accessibility settings for VR.

**Acceptance Criteria:**
- [ ] Teleport locomotion mode (point and click to move)
- [ ] Smooth locomotion with configurable speed
- [ ] Comfort vignette that darkens peripheral vision during movement
- [ ] Snap turning with configurable angle (default: 30 degrees)
- [ ] All comfort settings are accessible from a VR-native settings panel (no flat UI)

---

## Sprint 3: Social & Identity

**Dates:** Weeks 5-6
**Sprint Goal:** Features get social. Chat, friends, identity, quests, and moving through VR space.

---

### Track: Mobile Companion App (Dev 1) — "Pocket Social"

#### 3.M1 — Mobile Chat Interface
**Points:** 8

Full chat experience on mobile with real-time messaging.

**Acceptance Criteria:**
- [ ] Chat supports direct messages, group chat, and region chat channels
- [ ] Messages sync bidirectionally with the desktop client in real-time
- [ ] Chat UI follows mobile conventions (swipe to reply, long-press for options)
- [ ] Typing indicators and read receipts are consistent with desktop
- [ ] Chat works on cellular with graceful degradation on poor connections

#### 3.M2 — Friends List & Status
**Points:** 5

View and manage friends with online/offline status.

**Acceptance Criteria:**
- [ ] Friends list shows online status, current region, and last seen time
- [ ] Friend requests can be sent and received on mobile
- [ ] Tap a friend to open a DM or view their profile
- [ ] Online status syncs within 30 seconds of a friend logging in/out
- [ ] Friends list is searchable and sortable (online first, then alphabetical)

---

### Track: Creator Tools Platform (Dev 2) — "Mod Support"

#### 3.C1 — Plugin SDK Core
**Points:** 13

SDK for third-party developers to extend VibeLife with custom tools and plugins.

**Acceptance Criteria:**
- [ ] SDK provides TypeScript bindings for the VibeLife API
- [ ] Plugins run in a sandboxed environment with limited API surface
- [ ] Plugin lifecycle: install, activate, deactivate, uninstall
- [ ] Plugins can register custom UI panels, tools, and script nodes
- [ ] SDK documentation includes quickstart guide, API reference, and 3 example plugins

#### 3.C2 — Plugin API Extensions
**Points:** 5

Expose key platform APIs to the plugin system.

**Acceptance Criteria:**
- [ ] Plugins can read (not write) world state: entities, parcels, player positions
- [ ] Plugins can register custom chat commands (e.g., `/myplugin help`)
- [ ] Plugins can create custom UI overlays with a constrained layout system
- [ ] API calls from plugins are rate-limited (100 calls/second per plugin)
- [ ] Permission model: plugins must declare required permissions, users approve on install

---

### Track: Federation / Multi-Server (Dev 3) — "One Ring"

#### 3.F1 — Shared Identity Across Servers
**Points:** 13

A player's identity (avatar, name, profile) is consistent across federated servers.

**Acceptance Criteria:**
- [ ] Identity is anchored to the player's home server
- [ ] Visiting a foreign server presents the player's home identity (name, avatar, profile)
- [ ] Identity verification uses signed tokens — foreign servers can verify without calling home
- [ ] Display name collisions across servers are handled (append server tag: "PlayerName@ServerName")
- [ ] Players can view a visitor's home server info in their profile

#### 3.F2 — Federated Authentication
**Points:** 5

Auth flow that works across server boundaries.

**Acceptance Criteria:**
- [ ] Cross-server auth uses a token exchange protocol (not shared passwords)
- [ ] Tokens issued for foreign servers are scoped and short-lived (1 hour max)
- [ ] Token refresh is transparent to the player during a cross-server session
- [ ] A compromised foreign server cannot impersonate players on other servers
- [ ] Auth failures during cross-server teleport abort the teleport cleanly

---

### Track: AI NPCs (Dev 4) — "Follow Me!"

#### 3.N1 — Quest-Giver NPCs
**Points:** 8

NPCs that offer daily challenges and track player progress.

**Acceptance Criteria:**
- [ ] Quest-givers offer a rotating set of daily quests (3 per day, refreshed at midnight UTC)
- [ ] Quest types: collection (gather N items), exploration (visit N locations), social (interact with N players)
- [ ] Quest progress is tracked per player and persists across sessions
- [ ] Completing a quest awards currency and XP through the existing progression system
- [ ] Quest-givers have contextual dialogue based on quest state ("Back so soon?" / "You did it!")

#### 3.N2 — Tour Guide NPCs
**Points:** 8

NPCs that help new players navigate the world.

**Acceptance Criteria:**
- [ ] Tour guides are placed at spawn points and region hubs
- [ ] Interacting with a tour guide starts a guided walkthrough of the region
- [ ] Guide NPCs walk along a predefined path, pausing at points of interest
- [ ] Players can leave the tour at any time and resume later
- [ ] Tour guides highlight key features: building, chat, teleportation, marketplace
- [ ] Tour guide dialogue adapts to the player's account age (new vs. returning player)

---

### Track: VR Support (Dev 5) — "Moving In Space"

#### 3.V1 — VR User Interface
**Points:** 8

VR-native UI that replaces flat 2D menus with spatial interfaces.

**Acceptance Criteria:**
- [ ] Main menu is a spatial panel anchored to the player's non-dominant hand
- [ ] Menus are interacted with via ray-casting from the dominant hand or direct touch
- [ ] Text input uses a virtual keyboard with hand/controller typing
- [ ] UI panels are world-space objects — they can be pinned in place or follow the player
- [ ] All existing desktop UI functionality is accessible in VR (chat, inventory, map, settings)

#### 3.V2 — VR Locomotion System
**Points:** 5

Multiple movement modes for VR players.

**Acceptance Criteria:**
- [ ] Teleport locomotion: aim arc, preview landing, confirm to move
- [ ] Smooth locomotion: joystick-based continuous movement
- [ ] Room-scale movement is respected (physical walking maps 1:1)
- [ ] Movement speed in VR matches desktop movement speed (fairness)
- [ ] Locomotion mode is switchable in real-time via a quick menu

---

## Sprint 4: Integration & Marketplace

**Dates:** Weeks 7-8
**Sprint Goal:** Features connect to each other and to the economy. This is the sprint where isolated tracks start talking.

---

### Track: Mobile Companion App (Dev 1) — "Window Shopping"

#### 4.M1 — Mobile Marketplace Browser
**Points:** 8

Browse and purchase marketplace items from mobile.

**Acceptance Criteria:**
- [ ] Marketplace UI with categories, search, and filtering
- [ ] Item detail view with 3D preview (rotating thumbnail, not full render)
- [ ] Purchase flow works on mobile with currency balance display
- [ ] Purchase history is accessible
- [ ] Marketplace data is cached aggressively — browsing works on spotty connections

#### 4.M2 — Mobile Inventory Management
**Points:** 5

View and organize inventory from the companion app.

**Acceptance Criteria:**
- [ ] Full inventory view with categories and search
- [ ] Items can be favorited, sorted, and organized into folders
- [ ] Item details show: name, description, creator, acquisition date
- [ ] Items cannot be placed or used from mobile (view-only for world items)
- [ ] Inventory syncs with the server within 10 seconds of changes on desktop

---

### Track: Creator Tools Platform (Dev 2) — "Open For Business"

#### 4.C1 — Creator Storefronts
**Points:** 8

Customizable storefront pages for creators to showcase their work.

**Acceptance Criteria:**
- [ ] Creators can set up a storefront with a name, banner image, and description
- [ ] Storefront displays all published assets with sorting and categories
- [ ] Featured items can be pinned to the top of the storefront
- [ ] Storefront URL is shareable and accessible from the marketplace
- [ ] Storefront analytics: views, click-through rate, conversion rate

#### 4.C2 — Asset Publishing Workflow
**Points:** 5

Streamlined flow from asset creation to marketplace listing.

**Acceptance Criteria:**
- [ ] One-click publish from the review queue to the marketplace
- [ ] Creators set price, description, tags, and preview images during publishing
- [ ] Published assets are versioned — creators can push updates without breaking existing purchases
- [ ] Delisting an asset removes it from search but doesn't revoke existing purchases
- [ ] Publishing creates a notification to the creator's followers

---

### Track: Federation / Multi-Server (Dev 3) — "Global Trade"

#### 4.F1 — Federated Marketplace
**Points:** 13

Browse and purchase assets across federated servers.

**Acceptance Criteria:**
- [ ] Marketplace search queries federated servers in parallel with a timeout (2 seconds)
- [ ] Results are merged and ranked by relevance, with server of origin displayed
- [ ] Purchases from a foreign server trigger a cross-server transaction protocol
- [ ] Currency exchange rate between servers is 1:1 (for now — configurable later)
- [ ] Transaction failures refund the buyer atomically (no lost currency)

#### 4.F2 — Federation Admin Dashboard
**Points:** 5

Admin tools for managing federation relationships.

**Acceptance Criteria:**
- [ ] Dashboard shows all federated servers with status, latency, and player count
- [ ] Admins can approve/deny federation requests from new servers
- [ ] Admins can temporarily suspend federation with a specific server
- [ ] Federation event log: connections, disconnections, teleports, transactions
- [ ] Alerts for federation anomalies: high latency, repeated auth failures, unusual traffic

---

### Track: AI NPCs (Dev 4) — "Your NPCs, Your Rules"

#### 4.N1 — NPC Scripting Integration
**Points:** 8

Connect the visual scripting system to NPC behavior configuration.

**Acceptance Criteria:**
- [ ] Parcel owners can assign custom behavior trees to NPCs they own
- [ ] Custom behaviors use the same visual scripting editor from Tier 3
- [ ] Script nodes specific to NPCs: "say dialogue", "walk to", "emote", "give item", "check quest"
- [ ] Custom NPC scripts are validated for performance before activation
- [ ] A library of pre-built NPC behavior templates is available (patrol, idle, greet)

#### 4.N2 — NPC Appearance Customization
**Points:** 5

Let parcel owners customize NPC looks.

**Acceptance Criteria:**
- [ ] NPCs use the same appearance system as player avatars
- [ ] Parcel owners can set NPC outfit, colors, and accessories via a configuration panel
- [ ] NPCs can be given custom names and title labels
- [ ] NPC appearances are stored in the parcel data and sync to all clients
- [ ] At least 10 pre-built NPC appearance presets are available

---

### Track: VR Support (Dev 5) — "Build With Hands"

#### 4.V1 — VR Building Mode
**Points:** 13

Use VR hands/controllers to place and manipulate objects in the world.

**Acceptance Criteria:**
- [ ] Grab objects with grip button and move them freely in 3D space
- [ ] Two-handed grab enables scaling and rotation simultaneously
- [ ] Build palette is accessible as a spatial panel on the non-dominant hand
- [ ] Snap-to-grid works in VR with haptic feedback at snap points
- [ ] Undo/redo is accessible via controller button combo (not just keyboard)
- [ ] Object placement precision in VR is comparable to desktop (within 0.1m)

#### 4.V2 — VR Object Interaction
**Points:** 5

Interact with scripted objects and world elements in VR.

**Acceptance Criteria:**
- [ ] Ray-cast pointing activates interactive objects (doors, switches, trigger zones)
- [ ] Direct touch interaction for nearby objects (push buttons, flip switches)
- [ ] Haptic feedback on interaction events
- [ ] Interaction prompts appear as world-space labels near the target object
- [ ] All Tier 3 scripted object interactions work in VR without modification

---

## Sprint 5: Polish & Performance

**Dates:** Weeks 9-10
**Sprint Goal:** Harden, optimize, test, and document. Nothing new — just make everything that exists work *well*.

---

### Track: Mobile Companion App (Dev 1) — "Mini World"

#### 5.M1 — Simplified 3D World View
**Points:** 8

Lightweight 3D view of the world for mobile devices.

**Acceptance Criteria:**
- [ ] Renders a low-LOD version of the current region (or home parcel)
- [ ] Frame rate target: 30 FPS on mid-range devices (Snapdragon 7 Gen 1 / A15 equivalent)
- [ ] Asset quality scales dynamically based on device capability
- [ ] Players can look around and see other avatars (simplified models)
- [ ] 3D view is optional — users can stay in the 2D companion mode

#### 5.M2 — Quick Teleport
**Points:** 3

Teleport your desktop/VR session from the mobile app.

**Acceptance Criteria:**
- [ ] Mobile app sends a teleport command to the active desktop/VR session
- [ ] Teleport targets: favorites, friends, regions from the directory
- [ ] Command is delivered within 5 seconds to the active session
- [ ] If no desktop/VR session is active, the teleport is queued for next login
- [ ] Confirmation dialog prevents accidental teleports

#### 5.M3 — Mobile Performance Optimization
**Points:** 5

Battery and bandwidth optimization pass.

**Acceptance Criteria:**
- [ ] App consumes less than 5% battery per hour in background (notification-only mode)
- [ ] Active use consumes less than 15% battery per hour (chat + marketplace browsing)
- [ ] 3D view mode consumes less than 25% battery per hour
- [ ] Data usage is under 10MB/hour for chat and notifications
- [ ] Memory usage stays under 200MB on the 2D companion mode

---

### Track: Creator Tools Platform (Dev 2) — "Ship It"

#### 5.C1 — SDK Documentation & Examples
**Points:** 8

Comprehensive documentation for the plugin SDK.

**Acceptance Criteria:**
- [ ] Quickstart guide: "Your first plugin in 10 minutes"
- [ ] Complete API reference auto-generated from TypeScript types
- [ ] 5 example plugins covering: custom tool, UI panel, chat command, script node, asset processor
- [ ] Troubleshooting guide for common issues
- [ ] Documentation site is deployed and accessible from the VibeLife website

#### 5.C2 — Creator Tools Polish & Edge Cases
**Points:** 5

Fix the rough edges found during integration testing.

**Acceptance Criteria:**
- [ ] Asset upload handles all error cases gracefully (timeout, too large, invalid format, server error)
- [ ] Revenue calculations are verified against a manual audit (every coin accounted for)
- [ ] Dashboard loads in under 2 seconds with 1000+ assets
- [ ] Plugin sandbox prevents resource exhaustion (CPU, memory, network limits)
- [ ] End-to-end test: upload asset, review, approve, publish, purchase, verify revenue split

---

### Track: Federation / Multi-Server (Dev 3) — "Stress Test"

#### 5.F1 — Federation Stress Testing
**Points:** 8

Load test the federation protocol under realistic conditions.

**Acceptance Criteria:**
- [ ] Simulate 10 federated servers with 100 concurrent cross-server teleports
- [ ] Marketplace search across 10 servers completes in under 3 seconds (p95)
- [ ] No data loss during simulated network partitions between servers
- [ ] Federation protocol handles server crash and recovery without manual intervention
- [ ] Stress test results are documented with bottlenecks identified and filed as issues

#### 5.F2 — Federation Security Hardening
**Points:** 8

Security review and hardening of all federation endpoints.

**Acceptance Criteria:**
- [ ] All server-to-server endpoints require mutual TLS (no exceptions)
- [ ] Rate limiting on all federation API endpoints (per-server, per-endpoint)
- [ ] Input validation on all cross-server data (player state, marketplace listings, identity tokens)
- [ ] Penetration test: attempt to inject malicious player state via a rogue server
- [ ] Security audit findings are documented and remediated before launch

---

### Track: AI NPCs (Dev 4) — "Smarter, Not Harder"

#### 5.N1 — NPC Performance Optimization
**Points:** 8

Optimize NPC server-side processing for scale.

**Acceptance Criteria:**
- [ ] 50 NPCs per region at 5 Hz tick rate uses less than 10% of a single CPU core
- [ ] NPC pathfinding is amortized — not all NPCs recalculate paths on the same frame
- [ ] NPCs beyond player visibility range tick at reduced rate (1 Hz)
- [ ] Memory per NPC is under 50KB including behavior tree state
- [ ] Load test: 500 NPCs across 10 regions with stable server performance

#### 5.N2 — NPC Ambient Behavior Polish
**Points:** 5

Make ambient NPCs feel alive and not like animatronic mannequins.

**Acceptance Criteria:**
- [ ] Ambient NPCs have idle behaviors: looking around, stretching, sitting on benches
- [ ] NPCs react to nearby players: wave, nod, step aside
- [ ] NPCs have randomized daily routines (walk between points of interest)
- [ ] NPC density adapts to region population (fewer NPCs when more players are present)
- [ ] No two ambient NPCs perform the same action at the same time (stagger animations)

---

### Track: VR Support (Dev 5) — "Smooth Operator"

#### 5.V1 — VR Performance Optimization
**Points:** 8

Hit frame rate targets consistently across supported headsets.

**Acceptance Criteria:**
- [ ] 72 FPS sustained on Quest 2 in a region with 20 players and 50 objects
- [ ] 90 FPS sustained on PC VR (SteamVR) with equivalent scene complexity
- [ ] Foveated rendering is enabled on supported headsets (Quest Pro, Quest 3)
- [ ] Dynamic resolution scaling maintains frame rate under load
- [ ] Performance profiling report documents GPU/CPU breakdown per system

#### 5.V2 — VR Integration Testing & Polish
**Points:** 5

End-to-end testing of all VR interactions with existing systems.

**Acceptance Criteria:**
- [ ] Voice chat works correctly in VR (spatial audio, PTT with controller button, indicators)
- [ ] All emotes are triggerable from VR (hand gesture recognition for common emotes)
- [ ] Marketplace and inventory are usable from VR UI
- [ ] Building in VR produces the same results as desktop (objects are interchangeable)
- [ ] Pet interactions work in VR (reach down to pet your dog, because you deserve it)

---

## Risk Register

| # | Risk | Likelihood | Impact | Mitigation | Owner |
|---|------|-----------|--------|------------|-------|
| R1 | **Federation security breach** — a compromised federated server injects malicious player state, inventory items, or identity tokens into the network | Medium | Critical | Mutual TLS on all server-to-server communication. Signed identity tokens verified locally. Input validation on all cross-server data. Ability to instantly de-federate a compromised server. Security audit in Sprint 5. | Dev 3 |
| R2 | **VR motion sickness complaints** — comfort options are insufficient, or default settings cause nausea for sensitive users | High | High | Default to teleport locomotion (safest). Comfort vignette ON by default. Extensive playtesting with VR-sensitive testers. In-app "VR comfort level" questionnaire that sets defaults. | Dev 5 |
| R3 | **NPC server load at scale** — 50 NPCs per region across hundreds of regions overwhelms server resources | Medium | High | Tick rate reduction for NPCs outside player visibility. NPC count scales inversely with player count. Behavior tree evaluation is amortized. Load testing in Sprint 5 with realistic NPC counts. | Dev 4 |
| R4 | **Mobile battery drain** — companion app drains battery unacceptably in background or active use | High | High | Battery-aware sync scheduling. Background mode limits to push notifications only. Aggressive power profiling on reference devices. Hard targets: <5%/hr background, <15%/hr active. Kill the 3D view if battery is below 15%. | Dev 1 |
| R5 | **Cross-server teleport data loss** — player inventory or state is lost during a cross-server handoff due to network failure | Medium | Critical | Two-phase commit on state transfer. Player state is never deleted from origin until destination confirms receipt. Failed teleports return player to origin. All state transfers are logged and auditable. | Dev 3 |
| R6 | **Plugin SDK security** — third-party plugins escape the sandbox, access unauthorized data, or cause crashes | Medium | High | Plugins run in isolated sandboxes with restricted API surface. CPU and memory limits enforced. All plugins require permission declarations. Review queue for plugins before public listing. Kill switch per plugin. | Dev 2 |
| R7 | **NPC dialogue feels robotic** — quest-givers and shopkeepers repeat the same lines, breaking immersion | High | Medium | Large dialogue variation pools. Context-aware dialogue selection (time of day, weather, player history). Placeholder system for dynamic content. Community feedback loop for dialogue quality. | Dev 4 |
| R8 | **Federation marketplace currency exploits** — players exploit cross-server transactions to duplicate currency or items | Medium | Critical | All transactions use a two-phase commit with idempotency keys. Cross-server purchase amounts are validated against the source server's balance. Transaction logs are reconciled daily. Rate limiting on cross-server purchases. | Dev 3 |
| R9 | **VR building precision** — placing objects with hand tracking is too imprecise for detailed building, frustrating builders | High | Medium | Snap-to-grid as default with adjustable grid size. Magnification mode for fine placement. Allow switching to laser pointer for precision. Desktop mode always available for complex builds. | Dev 5 |
| R10 | **Mobile 3D view performance on low-end devices** — the simplified 3D view still stutters or crashes on older phones | Medium | Medium | Dynamic LOD scaling based on device capability. Option to disable 3D view entirely. Minimum device requirements clearly documented. Progressive asset loading with quality fallbacks. | Dev 1 |
| R11 | **Five parallel tracks cause merge conflicts** — all five devs modifying shared code paths (auth, entity system, UI framework) simultaneously | High | Medium | Feature flags for all tracks. Shared code changes are PRed and reviewed before merging. Weekly sync meeting for architectural decisions. Shared abstraction layers are defined in Sprint 1 before divergence. | All Devs |
| R12 | **Creator asset pipeline processing time** — asset conversion (FBX/OBJ to internal format) takes too long, frustrating creators | Medium | Medium | Async processing with status tracking. Queue-based architecture with horizontal scaling. Target: 90% of assets processed within 2 minutes. Pre-validation on client side to reject obviously invalid files before upload. | Dev 2 |

---

## Integration Testing Plan

Integration testing happens continuously, but these are the key cross-track integration milestones:

### Sprint 2 Gate — Auth & Audio Interfaces
**What:** Verify that mobile auth tokens, federation auth tokens, and VR spatial audio all work with the shared auth and audio subsystems.
**Who:** Dev 1 + Dev 3 + Dev 5
**How:**
- [ ] Mobile client authenticates with a federated identity token
- [ ] VR spatial audio plays voice chat from a non-VR player correctly
- [ ] Cross-server teleport preserves the session on mobile companion app

### Sprint 3 Gate — Identity & Social
**What:** Federated identity, mobile chat, and NPC interactions all touch the social and identity systems.
**Who:** Dev 1 + Dev 3 + Dev 4
**How:**
- [ ] A federated player's name and profile display correctly on mobile friend list
- [ ] NPC quest-givers reference the correct player identity (including federated visitors)
- [ ] Mobile chat messages are delivered to players on foreign servers

### Sprint 4 Gate — Marketplace & Economy
**What:** The marketplace is touched by Creator Tools, Federation, Mobile, and NPCs. This is the big one.
**Who:** All devs
**How:**
- [ ] Creator publishes an asset, which appears in the federated marketplace
- [ ] Mobile user purchases a federated asset through the marketplace browser
- [ ] Shopkeeper NPC sells an item from a creator storefront
- [ ] Revenue is correctly split and visible in the creator analytics dashboard
- [ ] Currency is not duplicated or lost in any cross-server transaction scenario

### Sprint 5 Gate — Full System Integration
**What:** End-to-end test of all five features working simultaneously.
**Who:** All devs + QA
**How:**
- [ ] VR player teleports to a federated server, interacts with an NPC shopkeeper, purchases an item
- [ ] Mobile user receives a notification of the purchase, views it in their inventory
- [ ] Creator sees the sale in their analytics dashboard
- [ ] The player teleports back to their home server with the item intact
- [ ] Everything above works at 72 FPS in VR, with no data loss, and the mobile app doesn't crash

### Performance Integration Test
**What:** All five features running simultaneously don't exceed resource budgets.
**Who:** Dev 3 (server) + Dev 5 (client)
**How:**
- [ ] Region with 20 players (5 VR, 5 mobile-connected, 10 desktop) + 30 NPCs
- [ ] Server CPU usage stays under 70% on the target instance type
- [ ] Desktop client maintains 30+ FPS
- [ ] VR client maintains 72+ FPS
- [ ] Mobile app maintains responsive UI with < 2 second sync latency

---

## Retrospective Template

Use this at the end of each sprint. Time-boxed to 45 minutes. With five parallel tracks, this is the most important meeting of the sprint.

### What Went Well (Keep Doing)
| Item | Track | Who Raised It |
|------|-------|--------------|
|      |       |              |
|      |       |              |
|      |       |              |

### What Didn't Go Well (Stop Doing)
| Item | Track | Who Raised It |
|------|-------|--------------|
|      |       |              |
|      |       |              |
|      |       |              |

### What Could Be Improved (Start Doing)
| Item | Track | Who Raised It | Action Item | Owner | Due |
|------|-------|--------------|-------------|-------|-----|
|      |       |              |             |       |     |
|      |       |              |             |       |     |
|      |       |              |             |       |     |

### Cross-Track Friction
> Were there any cross-track dependencies that caused delays or rework?
>
> _____________________________________________

### The One Thing
> If we could only fix ONE thing before the next sprint, it would be:
>
> _____________________________________________

### Sprint Happiness Score
Each team member rates 1-5. We track the trend. If it ever hits 1, we stop and talk. With five solo tracks, isolation is a real risk.

| Team Member | Track | Score | Comment (optional) |
|-------------|-------|-------|--------------------|
|             |       |       |                    |
|             |       |       |                    |
|             |       |       |                    |
|             |       |       |                    |
|             |       |       |                    |

---

*Last updated: 2026-03-10*
*Document owner: Product Management*
*Five features, five devs, five sprints. What could possibly go wrong.*
