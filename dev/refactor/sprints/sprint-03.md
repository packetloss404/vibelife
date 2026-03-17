# Sprint 3: Mining & Inventory

**Phase**: 2A, 2B
**Status**: Not Started
**Priority**: 4
**Depends on**: Sprint 1 (blocks to mine), Sprint 2 (first-person to aim)

## Goal

Implement hold-to-mine block breaking with crack overlay and item drops. Create a 36-slot inventory system with hotbar, armor slots, and drag-and-drop.

## Features

| Feature | Doc | Status |
|---------|-----|--------|
| Block Breaking | [block-breaking.md](../features/block-breaking.md) | Not Started |
| Inventory System | [inventory-system.md](../features/inventory-system.md) | Not Started |

## Files Modified

### Server
| File | Changes |
|------|---------|
| `src/world/voxel-service.ts` | Block drop logic (stone→cobblestone, ore→raw material), break validation with tool speed |
| `src/contracts.ts` | Add `InventoryContract`, `ItemStackContract`, `ItemTypeContract`. Add inventory events/commands to unions |
| `src/world/store.ts` | Export inventory service |
| `src/server.ts` | Register inventory routes, handle inventory commands in WS |

### Client
| File | Changes |
|------|---------|
| `native-client/godot/scripts/world/voxel_manager.gd` | Hold-to-mine timer, crack overlay stages, break particles, drop entity spawning |
| `native-client/godot/scripts/main.gd` | Hotbar rendering, number key slot selection, scroll wheel cycling, E key inventory toggle, Q to drop |

### New Files
| File | Purpose |
|------|---------|
| `src/world/inventory-service.ts` | Server-side inventory storage, slot operations, stacking logic |
| `src/routes/inventory.ts` | REST endpoints for inventory CRUD |
| `native-client/godot/scripts/ui/inventory_screen.gd` | Full inventory UI overlay with drag-and-drop |
| `native-client/godot/scripts/ui/hotbar_hud.gd` | Always-visible 9-slot hotbar at bottom of screen |
| `native-client/godot/scripts/world/item_entity.gd` | Dropped item entity (spinning block, bobbing, pickup on proximity) |

## Acceptance Criteria

- [ ] Hold left-click to mine blocks (not instant)
- [ ] Break time varies by block hardness and tool type
- [ ] 10-stage crack overlay appears on block being mined
- [ ] Particles burst on block break (block-colored)
- [ ] Broken block spawns a spinning item entity
- [ ] Walking over item entity picks it up into inventory
- [ ] 36-slot inventory (4 rows of 9)
- [ ] 9-slot hotbar always visible at bottom
- [ ] Number keys 1-9 select hotbar slot
- [ ] Scroll wheel cycles hotbar selection
- [ ] Selected hotbar item shown in first-person hand
- [ ] E key opens inventory screen
- [ ] Drag-and-drop between inventory slots
- [ ] Items stack to 64 (tools don't stack)
- [ ] Q key drops selected item as entity
- [ ] Shift-click quick-moves items between hotbar and inventory
- [ ] Inventory persists server-side per account

## Implementation Order

1. Create inventory-service.ts and inventory.ts routes
2. Add inventory types to contracts.ts
3. Implement hotbar_hud.gd (always visible)
4. Implement hold-to-mine in voxel_manager.gd
5. Add crack overlay rendering
6. Implement item_entity.gd (dropped items)
7. Implement inventory_screen.gd (E key overlay)
8. Add drag-and-drop logic
9. Connect to server (persist inventory)
10. Add tool speed modifiers

## Technical Notes

- Inventory is a fixed-size array of 45 slots: 0-8 hotbar, 9-35 main, 36-39 armor, 40 offhand
- ItemStack: { itemId: int, count: int, durability?: int, metadata?: Dictionary }
- Item entities use a small MeshInstance3D with slow rotation and sin-wave vertical bob
- Pickup radius: 1.5 blocks from player center
- Crack overlay: 10 semi-transparent textures overlaid on the block face being mined
- Break progress resets if player looks away or moves too far
