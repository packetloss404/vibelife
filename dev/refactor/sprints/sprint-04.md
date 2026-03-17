# Sprint 4: Crafting & Combat

**Phase**: 2C, 2D
**Status**: Not Started
**Priority**: 7
**Depends on**: Sprint 3 (inventory to hold items), Sprint 5 (mobs to fight)

## Goal

Add a 3x3 crafting grid with recipe system and furnace smelting. Overhaul combat with hunger, cooldowns, armor, critical hits, and fall damage.

## Features

| Feature | Doc | Status |
|---------|-----|--------|
| Crafting System | [crafting-system.md](../features/crafting-system.md) | Not Started |
| Hunger System | [hunger-system.md](../features/hunger-system.md) | Not Started |
| Combat Overhaul | [combat-overhaul.md](../features/combat-overhaul.md) | Not Started |

## Files Modified

### Server
| File | Changes |
|------|---------|
| `src/world/combat-service.ts` | Add hunger, armor reduction, fall damage, attack cooldown, critical hits, sweep attacks, death drops inventory |
| `src/contracts.ts` | Add `CraftingRecipeContract`, expand `CombatStatsContract` with hunger/armor, add food types to `ItemTypeContract` |
| `src/world/store.ts` | Export crafting service |
| `src/server.ts` | Register crafting routes, handle crafting commands |

### Client
| File | Changes |
|------|---------|
| `native-client/godot/scripts/ui/combat_hud.gd` | Hearts display (half-heart granularity), hunger drumsticks, armor bar, XP bar |
| `native-client/godot/scripts/main.gd` | Fall damage detection, hunger depletion on actions, food eating on right-click |

### New Files
| File | Purpose |
|------|---------|
| `src/world/crafting-service.ts` | Recipe registry, crafting validation, furnace smelting tick |
| `src/routes/crafting.ts` | REST endpoints for crafting |
| `native-client/godot/scripts/ui/crafting_panel.gd` | 3x3 crafting grid UI, recipe preview, shift-click craft |
| `native-client/godot/scripts/ui/furnace_panel.gd` | Furnace GUI: input, fuel, output, progress bars |

## Acceptance Criteria

- [ ] 3x3 crafting grid accessible from inventory and crafting table blocks
- [ ] 2x2 mini-crafting in inventory screen
- [ ] Shaped and shapeless recipes both work
- [ ] Output preview shows before clicking
- [ ] Shift-click crafts max stack
- [ ] Furnace block: input + fuel → output over 10 seconds
- [ ] 100+ recipes defined
- [ ] 20 hunger points displayed as 10 drumsticks
- [ ] Hunger depletes from walking, sprinting, mining, fighting
- [ ] Eating food restores hunger (right-click food in hand)
- [ ] Starvation damage at 0 hunger
- [ ] Health regens when hunger > 17
- [ ] Sprint requires hunger > 6
- [ ] Fall damage: 1 HP per block beyond 3 blocks fallen
- [ ] Attack cooldown: 1.6s for swords
- [ ] Critical hit: 1.5x damage when falling + attacking
- [ ] Armor reduces damage based on armor points
- [ ] Death drops all inventory items at death location

## Implementation Order

1. Add hunger to combat-service.ts and CombatStatsContract
2. Implement hunger HUD (drumsticks) in combat_hud.gd
3. Add hunger depletion logic (server-side tick)
4. Implement food eating
5. Add fall damage detection
6. Refactor melee combat with cooldown and crits
7. Add armor damage reduction
8. Create crafting-service.ts with recipe registry
9. Implement crafting_panel.gd UI
10. Implement furnace_panel.gd UI
11. Add death → drop inventory logic
12. Define 100+ recipes
