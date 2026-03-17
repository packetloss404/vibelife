# Feature: Minecraft HUD

**Sprint**: 8
**Status**: Not Started
**Priority**: High — defines the Minecraft feel

## Summary

Replace the current panel-heavy UI with a minimal Minecraft HUD. Always visible during gameplay: hotbar, crosshair, hearts, hunger, armor, XP bar, fading chat. No sidebars, no panels, no docks during active play.

## Current State

Main UI has: TopBar, Sidebar (login/settings), RightDock (tabbed panels), BuildPanel, BottomBar with chat. All visible simultaneously during gameplay. Looks like an admin dashboard, not a game.

## Target State

### HUD Layout (during gameplay)

```
┌─────────────────────────────────────────────────┐
│                                                 │
│                                                 │
│                                                 │
│    Chat messages          F3 debug (toggle)     │
│    fade after 10s                               │
│                                                 │
│                                                 │
│                       +                         │  ← Crosshair
│                  [held item name]               │
│                                                 │
│                                                 │
│                                                 │
│  ♥♥♥♥♥♥♥♥♥♥              🍗🍗🍗🍗🍗🍗🍗🍗🍗🍗  │  ← Hearts / Hunger
│  🛡🛡🛡🛡🛡               (armor if wearing)    │  ← Armor
│  ┌──┬──┬──┬──┬──┬──┬──┬──┬──┐                   │
│  │1 │2 │3 │4 │5 │6 │7 │8 │9 │    Level: 5      │  ← Hotbar + XP
│  └──┴──┴──┴──┴──┴──┴──┴──┴──┘                   │
│  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░                    │  ← XP Bar
└─────────────────────────────────────────────────┘
```

### Implementation (`minecraft_hud.gd`)

```gdscript
class_name MinecraftHUD
extends RefCounted

var main: Node3D
var hud_root: Control
var hotbar_container: HBoxContainer
var crosshair: Control
var hearts_container: HBoxContainer
var hunger_container: HBoxContainer
var armor_container: HBoxContainer
var xp_bar: ProgressBar
var xp_level_label: Label
var held_item_label: Label
var chat_container: VBoxContainer
var debug_overlay: Label

func init(main_node: Node3D) -> void:
    main = main_node
    hud_root = Control.new()
    hud_root.name = "MinecraftHUD"
    hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
    hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE

    _build_crosshair()
    _build_hotbar()
    _build_hearts()
    _build_hunger()
    _build_armor()
    _build_xp_bar()
    _build_held_item_label()
    _build_chat_display()
    _build_debug_overlay()

func _build_crosshair() -> void:
    # White + at exact center, 20x20px
    # Two ColorRects forming a cross
    # mouse_filter = IGNORE on all elements

func _build_hotbar() -> void:
    # 9 slots, centered bottom, each 44x44px with 2px gap
    # Dark background with lighter border for selected slot
    # Each slot shows: item colored square + count label (bottom-right)

func _build_hearts() -> void:
    # 10 TextureRect or ColorRect hearts
    # Positioned above hotbar, left-aligned
    # States: full (red), half (half-red), empty (dark outline)
    # Flash when taking damage
    # Hardcore: different texture (not applicable unless mode added)

func _build_hunger() -> void:
    # 10 TextureRect drumsticks
    # Above hotbar, right-aligned (mirror of hearts)
    # States: full, half, empty
    # Shake animation when hunger <= 6

func _build_armor() -> void:
    # Above hearts, only visible when wearing armor
    # 10 shield icons showing armor points (each = 2 points)

func _build_xp_bar() -> void:
    # Green progress bar spanning full hotbar width
    # Just below hotbar
    # Level number centered on bar in small green text

func _build_held_item_label() -> void:
    # Text below crosshair
    # Shows item name when switching hotbar slots
    # Fades out after 2 seconds (Tween alpha)

func _build_chat_display() -> void:
    # Bottom-left corner, above hearts
    # VBoxContainer of Label nodes
    # Each message fades after 10 seconds
    # Max 10 visible messages
    # Semi-transparent black background while messages visible

func _build_debug_overlay() -> void:
    # F3 toggle
    # Top-left: version, FPS, position, facing, biome, light level
    # Top-right: Java-style memory info (adapted for Godot)
    # Monospace font, semi-transparent background
```

### Removing Old UI

```gdscript
# In main.gd _ready():
# REMOVE: TopBar, Sidebar, RightDock, BuildPanel, BottomBar
# These become accessible ONLY through ESC menu

# KEEP: ToastManager (overlay notifications)

# Old UI elements hidden by default:
# sidebar_panel.visible = false
# right_dock.visible = false
# build_panel.visible = false
# top_bar.visible = false
# bottom_bar.visible = false
```

### Action Bar Text

System messages that appear briefly above the hotbar:

```gdscript
func show_action_text(text: String, duration: float = 2.0) -> void:
    action_label.text = text
    action_label.modulate.a = 1.0
    # Tween fade out after duration
```

Used for: "You can't place blocks here", "Inventory full", "Not enough hunger to sprint"

## Files Created

| File | Purpose |
|------|---------|
| `minecraft_hud.gd` | Full HUD implementation |

## Files Modified

| File | Changes |
|------|---------|
| `main.gd` | Replace old UI init with MinecraftHUD, hide old panels |
| `main.tscn` | Remove/hide Sidebar, TopBar, RightDock, BottomBar |

## Acceptance Criteria

- [ ] Hotbar: 9 slots centered bottom, selected highlighted
- [ ] Crosshair: white + at screen center
- [ ] Hearts: 10, above hotbar-left, half-heart granularity
- [ ] Hunger: 10 drumsticks, above hotbar-right
- [ ] Armor: shows when wearing armor
- [ ] XP bar: green bar below hotbar with level number
- [ ] Held item name fades below crosshair
- [ ] Chat: bottom-left, messages fade after 10s
- [ ] F3 debug: coords, FPS, biome, light level
- [ ] No panels/sidebars visible during gameplay
- [ ] Action bar text for system messages
- [ ] All old UI hidden until ESC menu opens
