# Feature: Inventory Screen (E Key)

**Sprint**: 8
**Status**: Not Started
**Priority**: High — needed for inventory interaction

## Summary

Full-screen inventory overlay opened with E key. Shows player model preview, armor slots, 2x2 mini-crafting grid, main inventory grid, and hotbar. Full drag-and-drop support.

## Target State

### Layout

```
┌───────────────────────────────────────────────┐
│                                               │
│  ┌────────┐  ┌──┬──┐     ┌──┐                │
│  │        │  │  │  │  →  │  │  Output         │
│  │ Player │  ├──┼──┤     └──┘                 │
│  │ Model  │  │  │  │                          │
│  │        │  └──┴──┘  2x2 Crafting            │
│  │        │                                   │
│  │ [H][C] │  ← Armor slots                   │
│  │ [L][B] │                                   │
│  └────────┘                                   │
│                                               │
│  ┌──┬──┬──┬──┬──┬──┬──┬──┬──┐                │
│  │  │  │  │  │  │  │  │  │  │  Row 1          │
│  ├──┼──┼──┼──┼──┼──┼──┼──┼──┤                │
│  │  │  │  │  │  │  │  │  │  │  Row 2          │
│  ├──┼──┼──┼──┼──┼──┼──┼──┼──┤                │
│  │  │  │  │  │  │  │  │  │  │  Row 3          │
│  ├──┼──┼──┼──┼──┼──┼──┼──┼──┤                │
│  │▓▓│▓▓│▓▓│▓▓│▓▓│▓▓│▓▓│▓▓│▓▓│  Hotbar        │
│  └──┴──┴──┴──┴──┴──┴──┴──┴──┘                │
└───────────────────────────────────────────────┘
```

### Drag-and-Drop

```gdscript
var dragging: Dictionary = {}  # { itemId, count, source_slot }
var cursor_item: Control = null  # Visual following mouse

func _on_slot_left_click(slot_index: int) -> void:
    var slot_contents = inventory.slots[slot_index]

    if dragging.is_empty():
        if slot_contents != null:
            # Pick up entire stack
            dragging = slot_contents.duplicate()
            inventory.slots[slot_index] = null
            _create_cursor_item(dragging)
    else:
        if slot_contents == null:
            # Place stack
            inventory.slots[slot_index] = dragging.duplicate()
            dragging = {}
            _destroy_cursor_item()
        elif slot_contents.itemId == dragging.itemId:
            # Merge stacks
            var max_stack := _get_max_stack(dragging.itemId)
            var space := max_stack - slot_contents.count
            var to_add := min(dragging.count, space)
            slot_contents.count += to_add
            dragging.count -= to_add
            if dragging.count <= 0:
                dragging = {}
                _destroy_cursor_item()
        else:
            # Swap
            var temp = slot_contents.duplicate()
            inventory.slots[slot_index] = dragging.duplicate()
            dragging = temp
            _update_cursor_item(dragging)

    _sync_to_server()

func _on_slot_right_click(slot_index: int) -> void:
    # Place one item from dragging stack
    if dragging.is_empty():
        # Pick up half the stack
        pass
    else:
        # Place 1 item
        pass

func _on_slot_shift_click(slot_index: int) -> void:
    # Quick-move: hotbar ↔ main inventory
    var slot_contents = inventory.slots[slot_index]
    if slot_contents == null:
        return

    if slot_index < 9:
        # Move from hotbar to first available main slot
        _move_to_first_available(slot_index, 9, 36)
    else:
        # Move from main to first available hotbar slot
        _move_to_first_available(slot_index, 0, 9)
```

### Player Model Preview

```gdscript
# SubViewport with a copy of the player model
# Rotatable: click and drag to spin the model
# Shows equipped armor pieces on the model

func _build_player_preview() -> SubViewportContainer:
    var viewport_container := SubViewportContainer.new()
    viewport_container.custom_minimum_size = Vector2(120, 200)

    var viewport := SubViewport.new()
    viewport.size = Vector2i(120, 200)
    viewport.transparent_bg = true

    var camera := Camera3D.new()
    camera.position = Vector3(0, 1.0, 3.0)
    camera.look_at(Vector3(0, 0.9, 0))

    # Clone of player model with current equipment
    var preview_model := _build_player_model(current_appearance)
    viewport.add_child(preview_model)
    viewport.add_child(camera)

    viewport_container.add_child(viewport)
    return viewport_container
```

## Files Created

| File | Purpose |
|------|---------|
| `inventory_screen.gd` | Full inventory overlay |

## Files Modified

| File | Changes |
|------|---------|
| `main.gd` | E key toggle, mouse release/capture |

## Acceptance Criteria

- [ ] E opens fullscreen overlay
- [ ] Player model preview (rotatable)
- [ ] 4 armor slots beside player
- [ ] 2x2 mini-crafting grid with output
- [ ] 36 inventory slots (27 main + 9 hotbar)
- [ ] Hotbar row highlighted at bottom
- [ ] Left-click: pick up / place stack
- [ ] Right-click: pick up half / place one
- [ ] Shift-click: quick-move hotbar ↔ main
- [ ] Double-click: gather all matching items
- [ ] Drop outside window: throw item
- [ ] Close on E or Escape
- [ ] Cursor item follows mouse while dragging
