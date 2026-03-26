# Feature: Inventory System

**Sprint**: 3
**Status**: Not Started
**Priority**: High — required for core gameplay loop

## Summary

Create a 36-slot inventory with 9-slot hotbar, armor slots, and offhand. Server-side persistence per account. Client-side hotbar always visible. E key opens full inventory overlay with drag-and-drop.

## Current State

No inventory system exists. Players have no items. Block placement uses `selected_block_type` integer directly.

## Target State

### Data Model

#### Server (`src/contracts.ts`)
```typescript
type ItemTypeContract = {
  id: number
  name: string
  displayName: string
  category: "block" | "tool" | "weapon" | "armor" | "food" | "material" | "special"
  maxStack: number       // 64 for blocks, 1 for tools, 16 for some items
  blockId?: number       // If this item places a block, which block ID
  toolType?: string      // "pickaxe" | "axe" | "shovel" | "sword" | "hoe"
  toolLevel?: number     // 0=wood, 1=stone, 2=iron, 3=diamond
  toolSpeed?: number     // Mining speed multiplier
  durability?: number    // Max durability (tools/armor)
  damage?: number        // Melee damage (weapons)
  armorPoints?: number   // Defense value (armor)
  armorSlot?: "helmet" | "chestplate" | "leggings" | "boots"
  foodValue?: number     // Hunger points restored
  saturation?: number    // Saturation restored
}

type ItemStackContract = {
  itemId: number
  count: number
  durability?: number    // Current durability (if applicable)
  metadata?: Record<string, unknown>  // Custom data (enchantments, etc.)
}

type InventoryContract = {
  accountId: string
  slots: (ItemStackContract | null)[]  // 45 slots total
  // Indices: 0-8 = hotbar, 9-35 = main inventory
  // 36 = helmet, 37 = chestplate, 38 = leggings, 39 = boots
  // 40 = offhand
}
```

#### Server (`src/world/inventory-service.ts`)
```typescript
// Core operations
function getInventory(accountId: string): InventoryContract
function setSlot(accountId: string, slot: number, stack: ItemStackContract | null): void
function swapSlots(accountId: string, from: number, to: number): void
function addItem(accountId: string, itemId: number, count: number): { added: number; overflow: number }
function removeItem(accountId: string, itemId: number, count: number): boolean
function getHeldItem(accountId: string, selectedSlot: number): ItemStackContract | null

// Stacking logic
function tryStack(existing: ItemStackContract, adding: ItemStackContract): { stacked: ItemStackContract; remainder: ItemStackContract | null }

// Drop all items on death
function dropAllItems(accountId: string, worldPos: { x: number; y: number; z: number }): DroppedItemEntity[]
```

#### WebSocket Events/Commands
```typescript
// Add to RegionEvent union:
| { type: "inventory:update"; accountId: string; inventory: InventoryContract }
| { type: "item:dropped"; entity: DroppedItemEntity }
| { type: "item:pickup"; accountId: string; entityId: string; itemId: number; count: number }

// Add to RegionCommand union:
| { type: "drop_item"; slot: number; count: number }
| { type: "swap_slots"; from: number; to: number }
| { type: "select_slot"; slot: number }
```

### Client: Hotbar HUD (`hotbar_hud.gd`)

Always visible at bottom center of screen:

```gdscript
var hotbar_slots: Array[Control] = []
var selected_slot := 0
const SLOT_SIZE := 40
const SLOT_PADDING := 2
const HOTBAR_SLOTS := 9

func _build_hotbar() -> void:
    var container := HBoxContainer.new()
    container.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
    container.position.y = -SLOT_SIZE - 10

    for i in range(HOTBAR_SLOTS):
        var slot := _create_slot_ui(i)
        container.add_child(slot)
        hotbar_slots.append(slot)

    _highlight_selected(selected_slot)

func _create_slot_ui(index: int) -> Panel:
    var panel := Panel.new()
    panel.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
    # Show item icon (colored square representing block/item)
    # Show count label in bottom-right corner
    return panel

func _on_number_key(key: int) -> void:
    selected_slot = key - 1  # Keys 1-9 → slots 0-8
    _highlight_selected(selected_slot)

func _on_scroll(direction: int) -> void:
    selected_slot = (selected_slot + direction) % HOTBAR_SLOTS
    if selected_slot < 0:
        selected_slot += HOTBAR_SLOTS
    _highlight_selected(selected_slot)
```

### Client: Inventory Screen (`inventory_screen.gd`)

Opened with E key:

```gdscript
var is_open := false
var dragging_stack: ItemStackContract = null
var drag_from_slot := -1

func toggle() -> void:
    is_open = not is_open
    if is_open:
        _build_inventory_ui()
        main.release_mouse()
    else:
        _close_inventory_ui()
        main.capture_mouse()

func _build_inventory_ui() -> void:
    # Fullscreen semi-transparent overlay
    var overlay := ColorRect.new()
    overlay.color = Color(0, 0, 0, 0.5)
    overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

    # Center panel
    var panel := PanelContainer.new()
    panel.set_anchors_preset(Control.PRESET_CENTER)
    panel.custom_minimum_size = Vector2(500, 400)

    # Player preview (left side) - 3D viewport with player model
    # Armor slots (next to player)
    # 2x2 crafting grid (top right of player area)
    # Main inventory grid: 4 rows x 9 columns (bottom)
    # Hotbar row highlighted at bottom

func _on_slot_click(slot_index: int, button: int) -> void:
    if button == MOUSE_BUTTON_LEFT:
        if dragging_stack == null:
            # Pick up stack from slot
            dragging_stack = inventory.slots[slot_index]
            inventory.slots[slot_index] = null
            drag_from_slot = slot_index
        else:
            # Place stack in slot (or swap)
            var existing = inventory.slots[slot_index]
            if existing == null:
                inventory.slots[slot_index] = dragging_stack
                dragging_stack = null
            elif existing.itemId == dragging_stack.itemId:
                # Stack merge
                _try_merge_stacks(slot_index)
            else:
                # Swap
                inventory.slots[slot_index] = dragging_stack
                dragging_stack = existing
            _send_swap_to_server(drag_from_slot, slot_index)

    elif button == MOUSE_BUTTON_RIGHT:
        # Place one item from dragging stack
        pass
```

### Client: Item Entity (`item_entity.gd`)

Dropped items in the world:

```gdscript
class_name ItemEntity
extends Node3D

var item_id: int
var count: int
var entity_id: String
var bob_timer := 0.0
var spin_speed := 2.0
var pickup_delay := 0.5  # Can't pickup for 0.5s after drop

func _init(id: String, item: int, cnt: int, pos: Vector3) -> void:
    entity_id = id
    item_id = item
    count = cnt
    position = pos

    # Create small block mesh
    var mesh_inst := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = Vector3(0.25, 0.25, 0.25)
    mesh_inst.mesh = box
    # Color from block palette or item color
    add_child(mesh_inst)

func _process(delta: float) -> void:
    # Spin
    rotate_y(spin_speed * delta)

    # Bob up and down
    bob_timer += delta * 3.0
    position.y += sin(bob_timer) * 0.005

    # Pickup check (done by voxel_manager or main.gd)

func can_pickup() -> bool:
    return pickup_delay <= 0.0
```

### Item Types (initial set)

#### Blocks (same ID as block, category="block")
Every placeable block is also an item. Item ID = Block ID. Max stack 64.

#### Tools
| Item ID | Name | Tool Type | Level | Speed | Durability | Damage |
|---------|------|-----------|-------|-------|------------|--------|
| 256 | wooden_pickaxe | pickaxe | 0 | 2 | 59 | 2 |
| 257 | stone_pickaxe | pickaxe | 1 | 4 | 131 | 3 |
| 258 | iron_pickaxe | pickaxe | 2 | 6 | 250 | 4 |
| 259 | diamond_pickaxe | pickaxe | 3 | 8 | 1561 | 5 |
| 260-263 | wooden/stone/iron/diamond_axe | axe | 0-3 | 2-8 | varied | 3-9 |
| 264-267 | wooden/stone/iron/diamond_shovel | shovel | 0-3 | 2-8 | varied | 1-4 |
| 268-271 | wooden/stone/iron/diamond_sword | sword | 0-3 | - | varied | 4-7 |

#### Food
| Item ID | Name | Hunger | Saturation |
|---------|------|--------|------------|
| 300 | raw_beef | 3 | 1.8 |
| 301 | cooked_beef | 8 | 12.8 |
| 302 | raw_porkchop | 3 | 1.8 |
| 303 | cooked_porkchop | 8 | 12.8 |
| 304 | bread | 5 | 6.0 |
| 305 | apple | 4 | 2.4 |
| 306 | golden_apple | 4 | 9.6 |
| 307 | raw_chicken | 2 | 1.2 |
| 308 | cooked_chicken | 6 | 7.2 |

#### Materials
| Item ID | Name | Max Stack | Dropped By |
|---------|------|-----------|------------|
| 400 | coal | 64 | coal_ore |
| 401 | raw_iron | 64 | iron_ore |
| 402 | raw_gold | 64 | gold_ore |
| 403 | diamond | 64 | diamond_ore |
| 404 | emerald | 64 | emerald_ore |
| 405 | string | 64 | spider |
| 406 | bone | 64 | skeleton |
| 407 | gunpowder | 64 | creeper |
| 408 | rotten_flesh | 64 | zombie |
| 409 | feather | 64 | chicken |
| 410 | leather | 64 | cow |
| 411 | ender_pearl | 16 | enderman |
| 412 | arrow | 64 | skeleton |

## Files Modified/Created

| File | Type | Changes |
|------|------|---------|
| `src/world/inventory-service.ts` | New | Full inventory service |
| `src/routes/inventory.ts` | New | REST endpoints |
| `src/contracts.ts` | Modified | Add all inventory types, events, commands |
| `src/server.ts` | Modified | Register routes, handle WS commands |
| `native-client/godot/scripts/ui/hotbar_hud.gd` | New | Always-visible hotbar |
| `native-client/godot/scripts/ui/inventory_screen.gd` | New | Full inventory overlay |
| `native-client/godot/scripts/world/item_entity.gd` | New | Dropped item entities |
| `native-client/godot/scripts/main.gd` | Modified | E key, number keys, scroll, Q drop |
| `native-client/godot/scripts/world/voxel_manager.gd` | Modified | Place from hotbar, drops on break |

## Acceptance Criteria

- [ ] 45-slot inventory (9 hotbar + 27 main + 4 armor + 1 offhand)
- [ ] Hotbar always visible with item icons and counts
- [ ] Number keys 1-9 select hotbar slots
- [ ] Scroll wheel cycles selection
- [ ] E key opens inventory overlay
- [ ] Drag-and-drop between all slots
- [ ] Items stack to max (64 for blocks, 1 for tools)
- [ ] Shift-click quick-moves between hotbar and main
- [ ] Q drops selected item as world entity
- [ ] Item entities spin and bob in the world
- [ ] Walking over item entity picks it up
- [ ] Inventory persists server-side
- [ ] Breaking blocks creates item drops
- [ ] Placing blocks consumes from hotbar
