# Tier 3 Sprint Plan — VibeLife

> "We're not just building a virtual world. We're building a virtual world with *pets*."

**Sprint Duration:** 2 weeks each
**Total Tier 3 Window:** 10 weeks (5 sprints)
**Methodology:** Agile-ish. We do standups. Sometimes we even stand.

---

## Definition of Done (Global)

Every story across every sprint must meet ALL of the following before it leaves the board:

- [ ] Feature works in both solo and multiplayer contexts
- [ ] No regressions in existing Tier 1/Tier 2 functionality
- [ ] Unit tests written and passing (yes, really)
- [ ] Integration tested against the dev region server
- [ ] Code reviewed by at least one other human (LLMs don't count, sorry)
- [ ] No `TODO: fix this later` comments that are older than the sprint itself
- [ ] Performance profiled — no single feature may drop client FPS below 30
- [ ] Docs updated (API, user-facing, or at minimum a coherent commit message)
- [ ] Merged to `develop` without setting anything on fire

---

## Velocity

Yes.

---

## Sprint 1: "The Brain" — Visual Scripting Core

**Dates:** Weeks 1–2
**Epic:** In-World Scripting (Visual)
**Team:** Dev 1 (core engine) + Dev 2 (interactive objects)
**Sprint Goal:** Give players the ability to make things *do stuff* without writing a single line of code. Scratch for adults who own virtual land.

### Stories

#### 1.1 — Script Data Model
**Assignee:** Dev 1
**Points:** 8

Define the underlying data model for visual scripts: nodes, connections, variable types, and execution flow.

**Acceptance Criteria:**
- [ ] Scripts are represented as a directed graph of typed nodes
- [ ] Supported variable types: bool, int, float, string, vector3, entity reference
- [ ] Scripts can be serialized to and deserialized from JSON
- [ ] Maximum script complexity is enforced (node count limit per parcel tier)
- [ ] Data model is validated on both client and server — no trusting the client, ever

#### 1.2 — Trigger Zones
**Assignee:** Dev 2
**Points:** 5

Spatial volumes that fire events when avatars or objects enter, exit, or dwell within them.

**Acceptance Criteria:**
- [ ] Parcel owners can place box and sphere trigger zones
- [ ] Events fire on enter, exit, and configurable dwell time
- [ ] Triggers respect parcel boundaries — no neighbor-snooping
- [ ] Trigger zones are visible in edit mode, invisible in play mode
- [ ] Server authoritative — client cannot fake trigger events

#### 1.3 — State Machines
**Assignee:** Dev 1
**Points:** 8

Visual state machine nodes that allow objects to have discrete states with transitions.

**Acceptance Criteria:**
- [ ] Objects can define named states (e.g., "open", "closed", "exploding")
- [ ] Transitions between states can be triggered by events, timers, or conditions
- [ ] State is synchronized across all clients viewing the object
- [ ] Invalid transitions are rejected gracefully (no silent failures)
- [ ] State machine visualization renders in the script editor UI

#### 1.4 — Node-Based Script Storage
**Assignee:** Dev 2
**Points:** 5

Persist visual scripts so they survive server restarts, region migrations, and the heat death of the universe (or at least a Tuesday deploy).

**Acceptance Criteria:**
- [ ] Scripts are stored per-object in the parcel data store
- [ ] Scripts are included in parcel export/import
- [ ] Version field present for future migration support
- [ ] Scripts load within 200ms of object becoming visible
- [ ] Corrupted scripts fail gracefully with a visible error indicator on the object

---

## Sprint 2: "Talk To Me" — Voice Chat

**Dates:** Weeks 3–4
**Epic:** Voice Chat (Spatial)
**Team:** Dev 3 (server signaling) + Dev 4 (client integration)
**Sprint Goal:** Let players talk to each other with their actual voices. What could go wrong. (See: Risk Register.)

### Stories

#### 2.1 — Signaling Server
**Assignee:** Dev 3
**Points:** 8

WebSocket-based signaling server for WebRTC session negotiation.

**Acceptance Criteria:**
- [ ] Signaling server handles SDP offer/answer exchange between peers
- [ ] ICE candidate trickle is supported
- [ ] Authenticated via existing session tokens — no anonymous voice ghosts
- [ ] Handles at least 50 concurrent voice sessions per region
- [ ] Graceful cleanup on disconnect (no phantom voice channels)

#### 2.2 — WebRTC Relay (TURN)
**Assignee:** Dev 3
**Points:** 5

TURN server configuration for players behind restrictive NATs, because corporate firewalls ruin everything.

**Acceptance Criteria:**
- [ ] TURN server is deployed and accessible from the client
- [ ] Fallback from STUN to TURN is automatic and seamless
- [ ] TURN credentials are short-lived and per-session
- [ ] Bandwidth usage per relay connection is capped
- [ ] Relay adds no more than 80ms additional latency (p95)

#### 2.3 — Spatial Audio Distance Calculation
**Assignee:** Dev 4
**Points:** 5

Voice volume attenuates based on distance between avatars. Just like real life, except nobody can smell you.

**Acceptance Criteria:**
- [ ] Volume scales inversely with distance using configurable rolloff curve
- [ ] Stereo panning reflects relative avatar positions
- [ ] Maximum audible range is configurable per region (default: 20m)
- [ ] Avatars beyond max range are fully silent (not just quiet)
- [ ] Distance calc runs on client side using server-authoritative positions

#### 2.4 — Push-To-Talk
**Assignee:** Dev 4
**Points:** 3

PTT keybind for players who don't want to broadcast their keyboard clacking and/or household arguments.

**Acceptance Criteria:**
- [ ] Configurable keybind (default: V)
- [ ] Visual indicator when PTT is active (transmitting icon on avatar)
- [ ] Toggle mode available as an accessibility option
- [ ] PTT state is local-only — server just receives audio or doesn't
- [ ] Works correctly when game window loses and regains focus

#### 2.5 — Mute & Deafen
**Assignee:** Dev 4
**Points:** 3

Individual mute (shut someone else up) and self-deafen (shut everyone up).

**Acceptance Criteria:**
- [ ] Players can mute individual other players via right-click menu
- [ ] Mute is per-session and does not persist across logins (for now)
- [ ] Self-deafen stops all incoming audio and shows a visual indicator
- [ ] Muted players see no indication that they've been muted (kindness)
- [ ] Moderators can server-mute players, which persists and overrides client

#### 2.6 — Voice Activity Indicators
**Assignee:** Dev 4
**Points:** 2

Show who's talking. The green-circle-around-the-avatar thing. You know the one.

**Acceptance Criteria:**
- [ ] Speaking indicator appears above avatar nameplate when voice is detected
- [ ] Indicator responds within 100ms of voice activity
- [ ] Works for both PTT and open-mic modes
- [ ] Indicator is visible from at least 30m away
- [ ] No indicator flicker from background noise (VAD threshold is tuned)

---

## Sprint 3: "Good Boy" — Pets & Companions

**Dates:** Weeks 5–6
**Epic:** Pets & Companions
**Team:** Dev 5 (full feature, you magnificent solo warrior)
**Sprint Goal:** Every virtual world needs pets. It's the law. We checked.

### Stories

#### 3.1 — Pet Adoption
**Assignee:** Dev 5
**Points:** 5

Players can adopt pets from an in-world shelter or marketplace. Impulse adoption is encouraged.

**Acceptance Criteria:**
- [ ] At least 5 pet species available at launch (dog, cat, bird, lizard, ??? mystery creature)
- [ ] Adoption flow: browse > select > name > confirm
- [ ] Pets are bound to the adopting player's account
- [ ] Maximum pet limit per player is enforced (default: 3 active, unlimited stored)
- [ ] Adoption creates a persistent pet entity in the database

#### 3.2 — Following AI
**Assignee:** Dev 5
**Points:** 8

Pets follow their owner around the world using pathfinding that mostly works.

**Acceptance Criteria:**
- [ ] Pets follow owner with configurable follow distance (default: 2m)
- [ ] Pathfinding avoids obstacles and does not clip through walls (most of the time)
- [ ] Pets teleport to owner if distance exceeds 30m (the rubber-band of love)
- [ ] Following behavior pauses when owner is stationary (pet idles/plays)
- [ ] Pet movement is server-authoritative to prevent speed-hacking pets

#### 3.3 — Pet Customization
**Assignee:** Dev 5
**Points:** 5

Color, accessories, and naming. The real endgame content.

**Acceptance Criteria:**
- [ ] Pets can be renamed at any time
- [ ] At least 8 color/pattern options per species
- [ ] Accessories slot: hats, collars, and tiny sunglasses (non-negotiable)
- [ ] Customization preview before applying
- [ ] Customization is visible to all other players in the region

#### 3.4 — Pet Interactions
**Assignee:** Dev 5
**Points:** 5

Petting, feeding, playing. The basics of virtual animal husbandry.

**Acceptance Criteria:**
- [ ] Interaction menu: pet, feed, play, sit/stay
- [ ] Interactions play animations on both avatar and pet
- [ ] Happiness meter is affected by interaction frequency
- [ ] Neglected pets get visually sad (but never die — we're not monsters)
- [ ] Other players can interact with your pet if you allow it (permission toggle)

#### 3.5 — Tricks
**Assignee:** Dev 5
**Points:** 3

Teachable tricks that pets can perform on command.

**Acceptance Criteria:**
- [ ] At least 4 tricks per species (sit, spin, jump, species-specific)
- [ ] Tricks are learned over time / through interaction count
- [ ] Trick commands work via emote menu or chat commands
- [ ] Tricks play a unique animation with optional particle effect
- [ ] Other players can see tricks being performed

#### 3.6 — Rare Variants
**Assignee:** Dev 5
**Points:** 3

Because if there's no shiny version, what's even the point.

**Acceptance Criteria:**
- [ ] Each species has at least 2 rare color/pattern variants
- [ ] Rare variant chance: ~5% on adoption (configurable)
- [ ] Rare pets have a subtle visual flair (sparkle, glow, etc.)
- [ ] Rarity is visible in pet info panel
- [ ] Rare variants are tradeable (future marketplace integration hook)

---

## Sprint 4: "Say Cheese" — Photography & Media

**Dates:** Weeks 7–8
**Epic:** Photography & Media
**Team:** Dev 6 (camera & gallery) + Dev 7 (placeable media)
**Sprint Goal:** Instagram but you live inside the photos. Kind of. Don't think about it too hard.

### Stories

#### 4.1 — In-World Camera
**Assignee:** Dev 6
**Points:** 5

A virtual camera tool with framing controls and a satisfying shutter sound.

**Acceptance Criteria:**
- [ ] Camera mode activates via toolbar or hotkey
- [ ] Free-look camera with zoom, pan, and orbit
- [ ] Camera has a viewfinder UI overlay with rule-of-thirds grid (toggleable)
- [ ] Shutter button captures the current frame at up to 4K resolution
- [ ] Camera mode disables avatar movement (you're holding a camera, not a gun)

#### 4.2 — Filters & Effects
**Assignee:** Dev 6
**Points:** 5

Post-processing filters because no one wants to see virtual reality as it actually looks.

**Acceptance Criteria:**
- [ ] At least 8 filters: sepia, noir, vintage, vibrant, dreamy, pixel, sketch, "normal"
- [ ] Filter preview is real-time in the viewfinder
- [ ] Filters are applied client-side before capture
- [ ] Filter name is stored in photo metadata
- [ ] Custom filter parameters (brightness, contrast, saturation) are adjustable

#### 4.3 — Photo Gallery
**Assignee:** Dev 6
**Points:** 5

Personal photo storage and browsing. Your virtual photo album.

**Acceptance Criteria:**
- [ ] Photos are stored in player's account with metadata (location, date, filter, tagged players)
- [ ] Gallery UI with grid view and full-screen view
- [ ] Photos can be favorited, deleted, and sorted by date/location
- [ ] Storage limit per player (default: 500 photos)
- [ ] Gallery is accessible from the main menu and in-world

#### 4.4 — Screenshot Sharing
**Assignee:** Dev 6
**Points:** 3

Share photos to a public feed or directly with friends. Clout-chasing in the metaverse.

**Acceptance Criteria:**
- [ ] One-click share to a public region photo board
- [ ] Direct share to friends via the messaging system
- [ ] Shared photos include a "visit this location" link
- [ ] Content moderation hook on public shares (flag for review)
- [ ] Share count and likes are tracked (but displayed tastefully)

#### 4.5 — Photo Frames
**Assignee:** Dev 7
**Points:** 5

Placeable frames that display photos from the gallery on parcel walls.

**Acceptance Criteria:**
- [ ] At least 5 frame styles (modern, ornate, rustic, floating, polaroid)
- [ ] Frames are placeable on walls and surfaces via the build tool
- [ ] Photos can be swapped without replacing the frame
- [ ] Frames are visible to all visitors with the photo loaded on proximity
- [ ] Photos in frames respect the original aspect ratio (no stretching crimes)

#### 4.6 — Video Screens
**Assignee:** Dev 7
**Points:** 8

Placeable screens that can display video content. Movie night in the metaverse.

**Acceptance Criteria:**
- [ ] Parcel owners can place video screen objects
- [ ] Supports streaming from URL (YouTube, Twitch, direct MP4 — via proxy)
- [ ] Video audio is spatial (volume by distance)
- [ ] Playback is synchronized across all viewers in the region
- [ ] Content whitelist/moderation controls for region admins

---

## Sprint 5: "Deck The Halls" — Seasonal Content

**Dates:** Weeks 9–10
**Epic:** Seasonal Content
**Team:** Dev 8 (full feature, keeper of the holiday spirit)
**Sprint Goal:** Make the world feel alive and ever-changing. Also, sell limited-time hats.

### Stories

#### 5.1 — Season System
**Assignee:** Dev 8
**Points:** 8

Backend system for defining, scheduling, and activating seasonal periods.

**Acceptance Criteria:**
- [ ] Seasons are defined as config entries with start date, end date, and theme ID
- [ ] Season transitions are automatic — no manual deploy required at midnight on Halloween
- [ ] Multiple seasons can overlap (e.g., "Winter" + "Holiday Event")
- [ ] Season state is queryable via API for other systems to react to
- [ ] Off-season: a default "normal" state exists and is not boring

#### 5.2 — Seasonal Decorations
**Assignee:** Dev 8
**Points:** 5

Automatic and player-placed decorations that match the current season.

**Acceptance Criteria:**
- [ ] Common areas get automatic seasonal decorations (trees, lights, etc.)
- [ ] Players receive a set of free seasonal decoration items for their parcels
- [ ] Decorations auto-remove when the season ends (or players can keep them, greyed out)
- [ ] At least 10 unique decoration objects per season
- [ ] Decorations don't count against parcel object limits (they're festive, not furniture)

#### 5.3 — Limited-Time Items
**Assignee:** Dev 8
**Points:** 5

Seasonal exclusives for avatar and parcel customization. FOMO as a feature.

**Acceptance Criteria:**
- [ ] Items are tagged with their season and marked as limited
- [ ] Items are obtainable through gameplay, events, or the marketplace
- [ ] Once obtained, items persist in inventory permanently
- [ ] Items display a "Season X Exclusive" badge
- [ ] Items cannot be obtained after the season ends (truly limited)

#### 5.4 — Seasonal Events
**Assignee:** Dev 8
**Points:** 8

Structured activities during seasonal periods. Egg hunts, snowball fights, that sort of thing.

**Acceptance Criteria:**
- [ ] Event system supports quests with objectives and rewards
- [ ] At least 2 event types per season (collection event + competitive event)
- [ ] Progress is tracked per-player with a seasonal event UI
- [ ] Events award exclusive items and a seasonal currency
- [ ] Leaderboards for competitive events (top 100)

#### 5.5 — Region Visual Overhaul
**Assignee:** Dev 8
**Points:** 5

Skyboxes, lighting, particles, and ambient audio change with the seasons.

**Acceptance Criteria:**
- [ ] Each season defines a skybox, ambient light color, and particle set
- [ ] Transitions between seasons are gradual (fade over 1 in-game day)
- [ ] Seasonal weather effects: falling leaves, snow, cherry blossoms, etc.
- [ ] Ambient audio changes (birds in spring, crickets in summer, wind in winter)
- [ ] Players can opt out of seasonal visuals in settings (but why would you)

#### 5.6 — Seasonal Achievements
**Assignee:** Dev 8
**Points:** 3

Trackable accomplishments tied to seasonal participation.

**Acceptance Criteria:**
- [ ] Each season has 5–10 achievements (mix of easy, medium, hard)
- [ ] Achievements award titles, badges, or exclusive cosmetics
- [ ] Achievement progress is visible in a seasonal tab on the profile
- [ ] "Completionist" meta-achievement for getting all achievements in a season
- [ ] Historical seasons and their achievements remain visible (greyed out if missed)

---

## Risk Register

| # | Risk | Likelihood | Impact | Mitigation | Owner |
|---|------|-----------|--------|------------|-------|
| R1 | **NAT traversal failures in voice chat** — symmetric NATs, corporate firewalls, and ISPs who think UDP is a suggestion | High | High | Deploy TURN relay servers in 3+ regions. Budget for bandwidth. Test behind the worst NATs we can find. | Dev 3 |
| R2 | **WebRTC support in Godot** — GDExtension bindings may be immature or unstable | Medium | High | Evaluate `godot-webrtc` and `libdatachannel` early in Sprint 2. Have a fallback plan using a native WebSocket audio stream (lower quality, but it works). | Dev 4 |
| R3 | **Pet pathfinding performance** — NavMesh generation on complex parcels could be expensive | Medium | Medium | Pre-bake NavMesh on parcel save. Use simplified collision for pet pathing. Cap pet count per region. | Dev 5 |
| R4 | **Photo storage costs** — 500 photos per player at 4K adds up fast | Medium | Medium | Compress aggressively (WebP), generate thumbnails, lazy-load full resolution. Monitor storage growth weekly. Set up alerts before the S3 bill becomes sentient. | Dev 6 |
| R5 | **Video screen synchronization** — keeping playback in sync across clients is a known hard problem | High | Medium | Use a reference timestamp from the server. Accept slight drift (< 500ms). Don't try to be Netflix. | Dev 7 |
| R6 | **Seasonal content scope creep** — "what if we also added a whole quest system" (we are, but still) | High | Medium | Timebox event design. First season ships with exactly 2 event types, no more. Fancy ideas go in the backlog. | Dev 8 |
| R7 | **Solo dev burnout (Sprints 3 & 5)** — single-assignee sprints are a bus factor of 1 | Medium | High | Pair programming sessions twice per sprint. Other devs available for rubber-ducking. Mandatory lunch breaks. | Scrum Master |
| R8 | **Visual scripting abuse** — players will build lag machines and call them "art" | Medium | Medium | Execution budget per script (max ops/frame). Scripts are sandboxed. Kill switch per parcel. | Dev 1 |

---

## Retrospective Template

Use this at the end of each sprint. Time-boxed to 45 minutes. Snacks are mandatory.

### What Went Well (Keep Doing)
| Item | Who Raised It |
|------|--------------|
|      |              |
|      |              |
|      |              |

### What Didn't Go Well (Stop Doing)
| Item | Who Raised It |
|------|--------------|
|      |              |
|      |              |
|      |              |

### What Could Be Improved (Start Doing)
| Item | Who Raised It | Action Item | Owner | Due |
|------|--------------|-------------|-------|-----|
|      |              |             |       |     |
|      |              |             |       |     |
|      |              |             |       |     |

### The One Thing
> If we could only fix ONE thing before the next sprint, it would be:
>
> _____________________________________________

### Sprint Happiness Score
Each team member rates 1–5. We track the trend. If it ever hits 1, we stop and talk.

| Team Member | Score | Comment (optional) |
|-------------|-------|--------------------|
|             |       |                    |

---

## Sprint Calendar Overview

```
Week 1–2   [====== Sprint 1: The Brain ======]  Visual Scripting
Week 3–4   [====== Sprint 2: Talk To Me =====]  Voice Chat
Week 5–6   [====== Sprint 3: Good Boy =======]  Pets & Companions
Week 7–8   [====== Sprint 4: Say Cheese =====]  Photography & Media
Week 9–10  [====== Sprint 5: Deck The Halls =]  Seasonal Content
```

---

*Last updated: 2026-03-10*
*Document owner: Product Management*
*If this document is out of date, that's a feature, not a bug.*
