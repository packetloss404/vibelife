# System: Viewport & Resolution Fix

## Problem
When the player resizes the Godot window, the game content stays the same size. The 3D viewport and UI don't scale to fill the available space. Even in windowed mode, making the window larger just adds black space around the fixed-size content.

## Root Cause
The Godot project uses default viewport settings which don't enable stretch/scaling. UI nodes likely use absolute pixel positions rather than anchors.

## Fix

### project.godot Changes
```ini
[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/size/resizable=true
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
```

- `canvas_items` mode: UI scales with resolution, 3D viewport fills window
- `expand` aspect: allows window to be any aspect ratio, content expands to fill

### Scene Tree Anchor Changes (main.tscn)

**CanvasLayer/UI** — the root UI container:
- Should be a Control node with anchors FULL_RECT (0,0 to 1,1)

**Sidebar** (left panel):
- Anchor preset: LEFT_WIDE (left 0, right 250px, top 0, bottom 1.0)
- Use MarginContainer for padding

**TopBar** (top strip):
- Anchor preset: TOP_WIDE (top 0, bottom 40px, left 250px, right 1.0)

**BuildPanel** (bottom-left):
- Anchor preset: BOTTOM_LEFT
- Fixed width, anchored to bottom

**RightDock** (right panel — becomes tab container):
- Anchor preset: RIGHT_WIDE (right 1.0, left = 1.0 - 350px, top 40px, bottom 1.0)

**3D Viewport**:
- SubViewportContainer if used, or just rely on the main viewport
- Should automatically fill the remaining center area

### Testing Checklist
- [ ] 1280x720 windowed — UI fits, no overflow
- [ ] 1920x1080 windowed — UI scales, 3D area larger
- [ ] 2560x1440 windowed — no text too small, UI still accessible
- [ ] Resize by dragging window border — real-time resize, no black bars
- [ ] Fullscreen toggle — clean transition
- [ ] Ultra-wide (21:9) — content fills, no stretch distortion

## Backend Impact
None — this is purely a client-side display fix.

## Files Modified
- `native-client/godot/project.godot`
- `native-client/godot/scenes/main.tscn`
