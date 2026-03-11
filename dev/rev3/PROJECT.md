# Rev3: GUI Completeness Sprint

## Mission
Get every backend feature exposed in the Godot client GUI. Currently ~10% coverage across 100+ endpoints. Target: 100%.

## Team
- 6 Documentation/Sprint Planners
- 6 Senior Game Developers

## Viewport Fix (Pre-Sprint)
The Godot client does not scale when the window is resized. The game renders at a fixed resolution inside the viewport and doesn't expand to fill the window. This must be fixed in Sprint 1 as the foundation for all new UI panels.

**Root Cause:** The project likely uses a fixed viewport stretch mode or the UI nodes use absolute positioning instead of anchors/containers.

**Fix Required:**
- Set project stretch mode to `canvas_items` (or `viewport` with expand)
- Set stretch aspect to `expand` or `keep_width`
- Ensure all UI panels use anchor presets (FULL_RECT, TOP_RIGHT, etc.)
- Use MarginContainer/VBoxContainer/HBoxContainer for responsive layout
- Test at multiple resolutions (1280x720, 1920x1080, 2560x1440)

## 10-Week Sprint Schedule

| Sprint | Week | Focus | Systems | Coverage Target |
|--------|------|-------|---------|-----------------|
| 1 | 1 | Foundation | Viewport fix, panel framework, tab system, WS event router | Framework |
| 2 | 2 | Social & Presence | Friends, blocking, profiles, presence, offline messages | Social 100% |
| 3 | 3 | Economy & Currency | Balance HUD, send dialog, transaction history | Economy 100% |
| 4 | 4 | Marketplace & Trading | Browse, buy, sell, auctions, bids, trade offers | Marketplace 100% |
| 5 | 5 | Guilds & Group Chat | Guild panel, treasury, roles, alliances, group chat | Guilds 100% |
| 6 | 6 | Achievements & Events | Progress, challenges, leaderboards, titles, event calendar | Achievements 100%, Events 100% |
| 7 | 7 | Pets & Homes | Pet panel, adoption, interactions, home management, ratings | Pets 100%, Homes 100% |
| 8 | 8 | Photography & Media | Camera mode, filters, gallery, likes, media objects | Photos 100%, Media 100% |
| 9 | 9 | Radio, Seasonal, Voice | Station picker, seasonal items, voice indicators | Radio 100%, Seasonal 100%, Voice 100% |
| 10 | 10 | Creator, Storefronts, Admin, Polish | Creator dashboard, storefront browser, admin panel, WS completeness | Everything 100% |

## Architecture Decisions

### Panel System
All new UI lives in a tabbed panel system on the right side, replacing the current hard-coded RightDock. Tabs:
- Chat (existing)
- Inventory (existing)
- Social
- Economy
- Marketplace
- Guild
- Achievements
- Events
- Pets
- Photos
- Home
- Radio
- Seasonal
- Voice
- Creator (if creator account)
- Admin (if admin role)

### UI Pattern
Every panel follows the same pattern:
1. A `.gd` script extending `Control` (not RefCounted) that builds its own UI in `_ready()`
2. Calls backend REST endpoints via HTTPRequest nodes
3. Listens for WS events routed from session_coordinator
4. Updates display reactively

### WS Event Router
Session coordinator gets a signal-based event router so panels can subscribe to specific event types without modifying session_coordinator.gd directly.

## File Organization
```
dev/rev3/
  PROJECT.md          <- This file
  sprint-01.md        <- Foundation sprint
  sprint-02.md        <- Social sprint
  ...
  sprint-10.md        <- Final polish sprint
  systems/
    viewport-fix.md
    panel-framework.md
    social.md
    economy.md
    marketplace.md
    guilds.md
    achievements.md
    events.md
    pets.md
    photography.md
    homes.md
    radio.md
    seasonal.md
    voice.md
    creator-tools.md
    storefronts.md
    admin.md
```

## Success Criteria
- Every backend endpoint has a corresponding GUI action
- Every WS event type (43/43) is handled by the client
- Window resizing works at all resolutions
- All panels are accessible via tabs
- No feature requires typing commands — everything is clickable
