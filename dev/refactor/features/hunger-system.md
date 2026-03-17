# Feature: Hunger System

**Sprint**: 4
**Status**: Not Started
**Priority**: Medium

## Summary

Add a 20-point hunger system. Hunger depletes from actions (walking, sprinting, mining, fighting). Food restores hunger. Starvation damage at 0 hunger. Health regeneration requires hunger > 17.

## Target State

### Server: `src/world/combat-service.ts` additions

```typescript
// Add to CombatStatsContract
type CombatStatsContract = {
  // ... existing fields (hp, maxHp, level, etc.)
  hunger: number         // 0-20
  saturation: number     // 0.0 to hunger value (hidden buffer)
  exhaustion: number     // Accumulates from actions, drains saturation then hunger
}

// Exhaustion costs
const EXHAUSTION_SPRINT = 0.1    // Per meter sprinted
const EXHAUSTION_JUMP = 0.05     // Per jump
const EXHAUSTION_ATTACK = 0.1    // Per attack
const EXHAUSTION_MINE = 0.005    // Per block broken
const EXHAUSTION_SWIM = 0.01     // Per meter swum
const EXHAUSTION_WALK = 0.0      // Walking is free

// When exhaustion >= 4.0:
//   If saturation > 0: saturation -= 1, exhaustion -= 4
//   Else: hunger -= 1, exhaustion -= 4

// Hunger effects:
//   hunger > 17: natural HP regen (0.5 HP per second)
//   hunger <= 6: cannot sprint
//   hunger == 0: starvation damage (0.5 HP per second)
```

### Client: HUD (`combat_hud.gd`)

```gdscript
# Hunger bar: 10 drumstick icons above hotbar (right side)
# Each drumstick = 2 hunger points
# Full drumstick: hunger >= (i+1)*2
# Half drumstick: hunger >= i*2 + 1
# Empty drumstick: hunger < i*2 + 1

func _draw_hunger_bar(hunger: int) -> void:
    for i in range(10):
        var threshold := (10 - i) * 2  # Right to left
        if hunger >= threshold:
            _set_drumstick_icon(i, "full")
        elif hunger >= threshold - 1:
            _set_drumstick_icon(i, "half")
        else:
            _set_drumstick_icon(i, "empty")

    # Shake drumsticks when hunger <= 6
    if hunger <= 6:
        _shake_hunger_icons()
```

### Eating Food

```gdscript
# Right-click with food item selected in hotbar
# Hold right-click for 1.6 seconds (eating animation)
# On complete: consume 1 food item, restore hunger + saturation

var eating := false
var eat_timer := 0.0
const EAT_TIME := 1.6

func _start_eating(food_item: Dictionary) -> void:
    eating = true
    eat_timer = 0.0
    # Play eating particle effect (food-colored)
    # Play crunch sound every 0.4 seconds

func _process_eating(delta: float) -> void:
    if not eating:
        return
    eat_timer += delta
    if eat_timer >= EAT_TIME:
        _complete_eating()

func _complete_eating() -> void:
    eating = false
    # Send eat command to server
    # Server: hunger += food.foodValue, saturation += food.saturation
    # Server: consume 1 item from inventory
    # Play burp sound (small chance)
```

## Files Modified

| File | Changes |
|------|---------|
| `src/world/combat-service.ts` | Add hunger, saturation, exhaustion tracking and tick |
| `src/contracts.ts` | Expand CombatStatsContract, add food item types |
| `native-client/godot/scripts/ui/combat_hud.gd` | Hunger drumstick display |
| `native-client/godot/scripts/main.gd` | Eating input handling |

## Acceptance Criteria

- [ ] 20 hunger points shown as 10 drumsticks
- [ ] Hunger depletes from sprinting, jumping, attacking, mining
- [ ] Eating food restores hunger (hold right-click 1.6s)
- [ ] Health regens when hunger > 17
- [ ] Cannot sprint when hunger <= 6
- [ ] Starvation damage at hunger 0
- [ ] Drumsticks shake when hunger <= 6
- [ ] Different foods restore different amounts
