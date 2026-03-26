# Sprint 9: Multiplayer Integration

**Phase**: 5A, 5B, 5C
**Status**: Not Started
**Priority**: 9
**Depends on**: Sprint 8 (new UI), Sprint 3 (inventory for trading)

## Goal

Adapt chat to Minecraft-style with fading messages and commands. Add player interaction radial menu. Ensure all existing features (pets, radio, economy, guilds, parcels, homes, achievements, events, seasonal, storefronts, photos, build mode, blueprints) are fully functional within the new Minecraft aesthetic.

## Features

| Feature | Doc | Status |
|---------|-----|--------|
| Chat Overhaul | [chat-overhaul.md](../features/chat-overhaul.md) | Not Started |
| Player Interactions | [player-interactions.md](../features/player-interactions.md) | Not Started |
| Feature Integration | [feature-integration.md](../features/feature-integration.md) | Not Started |

## Files Modified

### Client
| File | Changes |
|------|---------|
| `native-client/godot/scripts/ui/chat_controller.gd` | Fading messages, T to open input, / for commands, tab-complete, channel color prefixes |
| `native-client/godot/scripts/ui/context_menu.gd` | Radial menu on right-clicking players: trade, friend, whisper, inspect, party, guild invite |
| `native-client/godot/scripts/world/pet_manager.gd` | Blocky pet models, taming integration (wolf+bones, cat+fish) |
| `native-client/godot/scripts/audio/radio_controller.gd` | Jukebox block interaction instead of UI panel |
| `native-client/godot/scripts/ui/marketplace_manager.gd` | Chest shop blocks for player storefronts |
| `native-client/godot/scripts/world/parcel_manager.gd` | Claim stake blocks, particle boundary visualization |
| `native-client/godot/scripts/world/home_manager.gd` | /sethome, /home commands, bed respawn point |
| `native-client/godot/scripts/ui/achievement_manager.gd` | Toast: "Advancement Made!" style popups |
| `native-client/godot/scripts/ui/event_manager.gd` | Boss-bar style event notifications |
| `native-client/godot/scripts/world/seasonal_manager.gd` | Seasonal blocks, snow/flowers per season |
| `native-client/godot/scripts/build/build_controller.gd` | Structure blocks for GLTF placement, creative-mode fast building |
| `native-client/godot/scripts/build/blueprint_manager.gd` | Save/paste block regions |
| `native-client/godot/scripts/ui/camera_manager.gd` | F2 screenshot as "photo" |

## Acceptance Criteria

### Chat
- [ ] Messages appear bottom-left, fade after 10 seconds
- [ ] T opens chat input (full width at bottom)
- [ ] / opens chat with "/" pre-filled for commands
- [ ] Tab-complete player names
- [ ] Chat commands: /w, /r, /me, /home, /spawn, /guild, /party
- [ ] Channel color prefixes: [Global], [Local], [Guild], [Party], [Trade]
- [ ] Death/achievement/join messages in appropriate colors

### Player Interactions
- [ ] Right-click player → radial menu
- [ ] Trade, Friend, Whisper, Inspect, Party, Guild Invite, Report
- [ ] Voice fades with distance (proximity voice)

### Feature Integration
- [ ] Pets render as blocky models, taming with items works
- [ ] Jukebox block plays radio stations
- [ ] Economy: currency from mobs, villager NPCs for trading
- [ ] Guild banners placeable in world
- [ ] Parcels claimed with stake blocks, particle borders
- [ ] Achievements as "Advancement" toasts
- [ ] Events as boss-bar notifications
- [ ] Seasonal blocks and decorations
- [ ] Homes: /sethome, /home, bed respawn
- [ ] Storefronts: chest shop (sign + chest)
- [ ] Photos: F2 screenshot
- [ ] Build mode: structure blocks for GLTF placement
- [ ] Blueprints: save/paste block regions

## Implementation Order

1. Refactor chat system (fading messages, T to type, commands)
2. Implement radial player interaction menu
3. Convert pets to blocky models
4. Implement jukebox block
5. Add claim stake blocks for parcels
6. Convert achievements to toast notifications
7. Add chest shop mechanic
8. Wire all remaining features into new UI flow
9. Test all 15+ existing features end-to-end

## Technical Notes

- Chat messages are Label nodes in a VBoxContainer, each with a Timer that triggers fade Tween
- Radial menu: circular button layout around cursor position
- Jukebox: special block type, right-click opens small panel with station selector
- Claim stake: block type that triggers parcel claim API on placement
- Chest shop: sign block above chest, sign text parsed as "[item] [price]"
- All existing backend services and routes remain unchanged — only client presentation changes
