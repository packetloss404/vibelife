# Sprint 8: UI Overhaul

**Phase**: 4A, 4B, 4C, 4D
**Status**: Not Started
**Priority**: 3
**Depends on**: Sprint 2 (first-person camera), Sprint 3 (inventory for hotbar)

## Goal

Strip out the current panel-heavy sidebar UI and replace with a minimal Minecraft HUD. Add an escape menu, title screen, and proper inventory screen. All existing feature panels (social, economy, achievements, etc.) become accessible through the escape menu as fullscreen overlays.

## Features

| Feature | Doc | Status |
|---------|-----|--------|
| Minecraft HUD | [minecraft-hud.md](../features/minecraft-hud.md) | Not Started |
| Escape Menu | [escape-menu.md](../features/escape-menu.md) | Not Started |
| Title Screen | [title-screen.md](../features/title-screen.md) | Not Started |
| Inventory Screen | [inventory-screen.md](../features/inventory-screen.md) | Not Started |

## Files Modified

### Client
| File | Changes |
|------|---------|
| `native-client/godot/scripts/main.gd` | Remove sidebar/topbar/rightdock from _ready, add Minecraft HUD elements, ESC menu state machine, title screen state |
| `native-client/godot/scenes/main.tscn` | Restructure CanvasLayer/UI: remove Sidebar, TopBar, RightDock, BuildPanel. Add HUD layer, Menu layer, Overlay layer |
| `native-client/godot/scripts/ui/panel_manager.gd` | Refactor: panels now open as fullscreen overlays from ESC menu instead of tabs in right dock |
| `native-client/godot/scripts/ui/combat_hud.gd` | Refactor to Minecraft-style hearts/hunger/armor/XP rendering with texture-based icons |
| All panel .gd files in `scripts/ui/panels/` | Adapt to fullscreen overlay style instead of right-dock tab style |

### New Files
| File | Purpose |
|------|---------|
| `native-client/godot/scripts/ui/minecraft_hud.gd` | Hotbar, crosshair, hearts, hunger, armor, XP bar, action bar text, held item name |
| `native-client/godot/scripts/ui/escape_menu.gd` | Pause menu: Back to Game, Settings, Social, Economy, Achievements, Disconnect |
| `native-client/godot/scripts/ui/title_screen.gd` | Main menu: panorama background, Multiplayer, Settings, Quit |
| `native-client/godot/scripts/ui/settings_screen.gd` | Video, Audio, Controls, Multiplayer, Accessibility settings |
| `native-client/godot/scripts/ui/debug_screen.gd` | F3 overlay: coords, facing, biome, light level, chunk, FPS, memory, entity count |

## Acceptance Criteria

### Minecraft HUD (always visible during gameplay)
- [ ] 9-slot hotbar centered at bottom with selected slot highlighted
- [ ] Crosshair: small white + at screen center
- [ ] Health: 10 hearts above hotbar-left (full, half, empty states)
- [ ] Hunger: 10 drumsticks above hotbar-right
- [ ] Armor bar above health when wearing armor
- [ ] XP bar: green bar below hotbar, level number centered
- [ ] Air bubbles above hunger when underwater
- [ ] Held item name fades below crosshair on slot change
- [ ] Chat messages bottom-left, fade after 10 seconds
- [ ] F3 debug screen toggle

### Escape Menu
- [ ] ESC opens centered pause menu
- [ ] "Back to Game" resumes
- [ ] "Settings" opens settings screen (video, audio, controls)
- [ ] Social/Economy/Achievements open as fullscreen overlays
- [ ] "Disconnect" returns to title screen

### Title Screen
- [ ] Panoramic rotating world background
- [ ] "VIBELIFE" title in blocky font
- [ ] Multiplayer → server browser (region list)
- [ ] Settings
- [ ] Quit

### Inventory Screen
- [ ] E key opens fullscreen overlay
- [ ] Player model preview (rotatable)
- [ ] 4 armor slots beside player
- [ ] 2x2 mini-crafting grid
- [ ] 36 inventory slots + 9 hotbar slots
- [ ] Drag-and-drop between all slots
- [ ] Shift-click quick-move
- [ ] Close on E or Escape

## Implementation Order

1. Create minecraft_hud.gd (hotbar, crosshair, basic bars)
2. Strip old UI from main.tscn (sidebar, topbar, rightdock)
3. Create title_screen.gd (entry point)
4. Create escape_menu.gd
5. Refactor panel_manager.gd for fullscreen overlays
6. Create settings_screen.gd
7. Create inventory_screen.gd
8. Add hearts/hunger/armor/XP textures to HUD
9. Add debug_screen.gd (F3)
10. Add chat fade-in/fade-out system
11. Wire all existing panels as ESC menu overlays

## Technical Notes

- Game states: TITLE, PLAYING, PAUSED, INVENTORY, OVERLAY
- During PLAYING: only HUD visible, mouse captured
- During PAUSED/INVENTORY/OVERLAY: mouse released, game continues (multiplayer)
- HUD elements use TextureRect for hearts/hunger icons (not just colored rectangles)
- Chat uses a VBoxContainer with timed Label children that fade out via Tween
- Debug screen: Label with monospace font, updated every frame
- All old panels still work — just displayed differently (fullscreen instead of tab)
