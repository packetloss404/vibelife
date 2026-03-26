# Feature: Title Screen

**Sprint**: 8
**Status**: Not Started
**Priority**: Medium

## Summary

Main menu with panoramic world background, "VIBELIFE" title, multiplayer server browser, settings, and profile selection.

## Target State

### Layout

```
┌─────────────────────────────────────────┐
│         [panoramic world view]          │
│                                         │
│            V I B E L I F E              │
│        A Community-Owned World          │
│                                         │
│          ┌─────────────────┐            │
│          │   Multiplayer   │            │
│          └─────────────────┘            │
│          ┌─────────────────┐            │
│          │    Settings     │            │
│          └─────────────────┘            │
│          ┌─────────────────┐            │
│          │      Quit       │            │
│          └─────────────────┘            │
│                                         │
│  Profile: Steve  [Change]    v0.1.0     │
└─────────────────────────────────────────┘
```

### Panorama Background

```gdscript
# Slowly rotating camera looking at a pre-rendered or live-generated world
# Option A: 6 pre-rendered panorama images (cubemap)
# Option B: Live render of chunk (0,0) area with slow camera orbit

func _setup_panorama() -> void:
    # Camera orbits at y=80, distance=50, slow rotation
    panorama_camera.position = Vector3(50, 80, 0)
    panorama_angle = 0.0

func _process_panorama(delta: float) -> void:
    panorama_angle += delta * 0.1  # Very slow rotation
    panorama_camera.position = Vector3(
        cos(panorama_angle) * 50, 80, sin(panorama_angle) * 50
    )
    panorama_camera.look_at(Vector3(0, 64, 0))
```

### Server Browser (Multiplayer)

```gdscript
# Shows list of available regions from server
# Each entry: region name, player count, description
# "Direct Connect" option for custom server URL

func _build_server_browser() -> void:
    # Backend URL input (saved from profile)
    # "Refresh" button → GET /api/regions
    # List of regions with Join button each
    # Display name input
    # Auth mode select (guest/register/login)
```

This replaces the current Sidebar login flow with a proper server browser.

## Files Created

| File | Purpose |
|------|---------|
| `title_screen.gd` | Main menu, server browser |

## Files Modified

| File | Changes |
|------|---------|
| `main.gd` | Start in TITLE state, transition to PLAYING on join |

## Acceptance Criteria

- [ ] Game starts on title screen (not in-world)
- [ ] Panoramic rotating background
- [ ] "VIBELIFE" title with subtitle
- [ ] Multiplayer → server browser with region list
- [ ] Settings accessible from title
- [ ] Profile/display name selection
- [ ] Version number in corner
- [ ] Quit button
