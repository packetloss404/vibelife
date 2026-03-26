# Feature: Existing Feature Integration

**Sprint**: 9
**Status**: Not Started
**Priority**: Medium — ensures nothing is lost in the refactor

## Summary

Adapt all existing VibeLife features to work within the new Minecraft aesthetic. No features are removed — they're re-skinned and re-accessed through in-world blocks, commands, or the ESC menu.

## Feature Mapping

### Pets → Blocky Tamed Mobs
- **Current**: Pet panel with summon/dismiss/tricks
- **New**: Tame wild mobs with items (wolf+bones, cat+fish)
- **Integration**: Tamed mob = pet from pet-service.ts. Same backend, different client presentation
- **Client**: pet_manager.gd renders pets as blocky mob models instead of abstract shapes
- **Access**: Interact with tamed mob for pet menu (tricks, accessories, stats)

### Radio → Jukebox Block
- **Current**: Radio panel in right dock
- **New**: Jukebox block (ID 94) placed in world
- **Integration**: Right-click jukebox → small station selector popup
- **Client**: radio_controller.gd triggers on jukebox interaction
- **Audio**: Plays in 3D positional radius around jukebox block

### Economy → Villager NPCs + Chest Shops
- **Current**: Economy panel with balance, transactions
- **New**: Villager NPCs at market stalls, player chest shops
- **Integration**:
  - Balance shown in inventory screen corner
  - Villager NPC right-click → trade GUI (like Minecraft)
  - Chest shop: sign above chest with "[item] [price]", click to buy/sell
- **Backend**: Same economy-service.ts, marketplace-service.ts

### Guilds → Guild Banners + Guild Chat
- **Current**: Guild panel in right dock
- **New**:
  - Guild management via ESC menu
  - Guild banner block (placeable, shows guild emblem)
  - /guild command for guild chat
  - Guild territory: area within guild banner range
- **Backend**: Same guild-service.ts

### Parcels → Claim Stakes
- **Current**: Parcel boundaries shown as wireframes
- **New**:
  - Claim stake block (ID 95): place to claim land
  - Particle borders at parcel boundaries (subtle)
  - Permission management via right-clicking claim stake
  - Parcel info shown in F3 debug screen
- **Backend**: Same parcel-service.ts

### Achievements → Advancement Toasts
- **Current**: Achievements panel in right dock
- **New**:
  - Toast notification: "Advancement Made! [Achievement Name]"
  - Achievement screen in ESC menu (same panel, fullscreen)
  - Chat broadcast: "PlayerName has earned [Achievement]!"
- **Backend**: Same achievement-service.ts

### Events → Boss Bar Notifications
- **Current**: Events panel in right dock
- **New**:
  - Active events shown as boss-bar-style notification at top of screen
  - Event details in ESC menu
  - Event chat messages in system color
- **Backend**: Same event-service.ts

### Seasonal → Seasonal Blocks & Weather
- **Current**: Seasonal panel in right dock
- **New**:
  - Seasonal blocks available in block palette (holiday blocks)
  - Snow in winter, flowers in spring
  - Seasonal mob variants (Santa zombie, etc.)
  - Seasonal shop via ESC menu
- **Backend**: Same seasonal-service.ts

### Homes → Bed Spawn + Commands
- **Current**: Home panel with doorbell, access control
- **New**:
  - Bed block: right-click to set spawn point
  - /sethome, /home commands
  - Doorbell: noteblock at door position
  - Home access control via right-clicking claim stake
- **Backend**: Same home-service.ts

### Storefronts → Chest Shops
- **Current**: Storefront panel in right dock
- **New**:
  - Chest + sign combination
  - Sign format: line 1 = "[Buy]" or "[Sell]", line 2 = item name, line 3 = price
  - Right-click chest to transact
  - Storefront management via ESC menu
- **Backend**: Same storefront-service.ts

### Photos → F2 Screenshot
- **Current**: Photos panel with gallery
- **New**:
  - F2 key takes screenshot (saved locally + uploaded)
  - Photo gallery in ESC menu
  - Map item: aerial view of explored area (future)
- **Backend**: Same photo-service.ts

### Build Mode → Creative Mode / Structure Blocks
- **Current**: Build panel with GLTF asset selection, gizmos
- **New**:
  - Normal block placement IS building (no separate mode needed)
  - Structure blocks for GLTF placement (operator/creative mode)
  - Creative mode: fly, unlimited blocks, instant break, no damage
- **Backend**: Same object-service.ts for GLTF objects

### Blueprints → Schematic System
- **Current**: Blueprint save/load
- **New**:
  - Select region of blocks → save as schematic
  - Paste schematic (creative/operator only)
  - Schematic sharing via marketplace
- **Backend**: Same blueprint-service.ts

### Voice → Proximity Voice
- **Current**: Voice panel, separate channels
- **New**:
  - Always-on proximity voice (volume fades with distance)
  - Mute button in ESC menu settings
  - Voice indicator above speaking players' heads
- **Backend**: Same voice-service.ts

### Social → ESC Menu + Commands
- **Current**: Social panel in right dock
- **New**:
  - Friend list in ESC menu
  - /friend add/remove/list commands
  - Online friends shown with green name tags
- **Backend**: Same social-service.ts

## Implementation Checklist

- [ ] Pets: blocky models, taming mechanic, pet menu on interact
- [ ] Radio: jukebox block, station selector popup
- [ ] Economy: balance in inventory, villager trade, chest shops
- [ ] Guilds: ESC menu, banners, /guild chat
- [ ] Parcels: claim stakes, particle borders, F3 info
- [ ] Achievements: toast popups, ESC menu screen
- [ ] Events: boss bar, ESC menu details
- [ ] Seasonal: seasonal blocks, weather effects
- [ ] Homes: bed spawn, /home command, noteblock doorbell
- [ ] Storefronts: chest + sign shops
- [ ] Photos: F2 screenshot, ESC gallery
- [ ] Build: block placement, structure blocks for GLTF
- [ ] Blueprints: schematic save/paste
- [ ] Voice: proximity, mute setting, indicator
- [ ] Social: ESC menu, /friend commands

## Key Principle

**No backend changes needed.** All services, routes, and contracts remain the same. Only client-side presentation changes: from panel tabs to in-world blocks, commands, and ESC overlays.
