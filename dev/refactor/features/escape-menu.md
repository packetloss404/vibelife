# Feature: Escape Menu

**Sprint**: 8
**Status**: Not Started
**Priority**: High

## Summary

Pressing ESC opens a centered pause-style menu. Access settings, social features, economy, achievements, and disconnect — all as fullscreen overlays instead of sidebar tabs.

## Target State

### Menu Layout

```
┌──────────────────────────┐
│                          │
│     Back to Game         │
│                          │
│     Settings             │
│                          │
│     Social & Friends     │
│                          │
│     Economy & Market     │
│                          │
│     Achievements         │
│                          │
│     Guild                │
│                          │
│     Disconnect           │
│                          │
└──────────────────────────┘
```

### Settings Screen Categories

**Video**: Render distance, graphics quality, smooth lighting, clouds on/off, particles (all/decreased/minimal), FOV slider, fullscreen toggle, VSync, max FPS (30/60/120/unlimited)

**Audio**: Master, Music, Blocks, Hostile Mobs, Players, Ambient, Weather — all 0-100% sliders

**Controls**: Mouse sensitivity, Invert Y toggle, key bindings list (scrollable, click to rebind)

**Multiplayer**: Chat visibility (shown/hidden/commands only), player names (shown/hidden), cape visibility

**Accessibility**: Text scale (1x-2x), high contrast toggle, reduced motion toggle

### Implementation

```gdscript
# escape_menu.gd
func _build_menu() -> void:
    var overlay := ColorRect.new()
    overlay.color = Color(0, 0, 0, 0.6)
    overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

    var panel := VBoxContainer.new()
    panel.set_anchors_preset(Control.PRESET_CENTER)

    _add_button("Back to Game", _close_menu)
    _add_button("Settings", _open_settings)
    _add_button("Social & Friends", _open_social_overlay)
    _add_button("Economy & Market", _open_economy_overlay)
    _add_button("Achievements", _open_achievements_overlay)
    _add_button("Guild", _open_guild_overlay)
    _add_button("Disconnect", _disconnect)
```

Existing panel classes (social_panel.gd, marketplace_panel.gd, etc.) are reused but displayed as fullscreen overlays instead of right-dock tabs.

## Files Created

| File | Purpose |
|------|---------|
| `escape_menu.gd` | Pause menu |
| `settings_screen.gd` | Settings categories |

## Files Modified

| File | Changes |
|------|---------|
| `main.gd` | ESC key handling, game state machine |
| `panel_manager.gd` | Fullscreen overlay mode |

## Acceptance Criteria

- [ ] ESC opens centered menu, releases mouse
- [ ] "Back to Game" resumes and re-captures mouse
- [ ] Settings: video, audio, controls, multiplayer, accessibility
- [ ] Social/Economy/Achievements open as fullscreen overlays
- [ ] "Disconnect" returns to title screen
- [ ] Game continues in background (multiplayer, mobs move)
