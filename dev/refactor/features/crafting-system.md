# Feature: Crafting System

**Sprint**: 4
**Status**: Not Started
**Priority**: Medium — depth of gameplay

## Summary

Add a 3x3 crafting grid with shaped and shapeless recipes, a recipe book, and furnace smelting. 2x2 mini-crafting in the inventory screen. 100+ recipes covering all block and item transformations.

## Current State

No crafting system exists.

## Target State

### Server: `src/world/crafting-service.ts`

```typescript
type CraftingRecipeContract = {
  id: string
  type: "shaped" | "shapeless"
  pattern?: string[]     // 1-3 strings, each 1-3 chars (shaped only)
  key?: Record<string, number>  // char → itemId mapping (shaped only)
  ingredients?: number[] // itemIds in any arrangement (shapeless only)
  result: { itemId: number; count: number }
  requiresCraftingTable: boolean  // true if 3x3, false if fits in 2x2
}

// Recipe registry
const recipes: CraftingRecipeContract[] = [
  // Planks from logs
  { id: "oak_planks", type: "shapeless", ingredients: [20], result: { itemId: 21, count: 4 }, requiresCraftingTable: false },

  // Crafting table
  { id: "crafting_table", type: "shaped", pattern: ["PP", "PP"], key: { P: 21 }, result: { itemId: 78, count: 1 }, requiresCraftingTable: false },

  // Sticks
  { id: "sticks", type: "shaped", pattern: ["P", "P"], key: { P: 21 }, result: { itemId: 450, count: 4 }, requiresCraftingTable: false },

  // Wooden pickaxe
  { id: "wooden_pickaxe", type: "shaped", pattern: ["PPP", " S ", " S "], key: { P: 21, S: 450 }, result: { itemId: 256, count: 1 }, requiresCraftingTable: true },

  // ... 100+ more recipes
]

function findMatchingRecipe(grid: (number | null)[][], gridSize: number): CraftingRecipeContract | null {
  for (const recipe of recipes) {
    if (recipe.type === "shaped") {
      if (matchesShaped(grid, gridSize, recipe)) return recipe
    } else {
      if (matchesShapeless(grid, gridSize, recipe)) return recipe
    }
  }
  return null
}
```

### Furnace Smelting

```typescript
type SmeltingRecipeContract = {
  inputItemId: number
  outputItemId: number
  xpReward: number
  cookTime: number  // seconds (default 10)
}

const smeltingRecipes: SmeltingRecipeContract[] = [
  { inputItemId: 401, outputItemId: 460, xpReward: 0.7, cookTime: 10 }, // raw_iron → iron_ingot
  { inputItemId: 402, outputItemId: 461, xpReward: 1.0, cookTime: 10 }, // raw_gold → gold_ingot
  { inputItemId: 300, outputItemId: 301, xpReward: 0.35, cookTime: 10 }, // raw_beef → cooked_beef
  { inputItemId: 1, outputItemId: 39, xpReward: 0.1, cookTime: 10 },    // stone → smooth_stone
  // ...
]

// Furnace state per block position
type FurnaceState = {
  inputSlot: ItemStackContract | null
  fuelSlot: ItemStackContract | null
  outputSlot: ItemStackContract | null
  burnTimeRemaining: number  // seconds of fuel left
  cookProgress: number       // 0.0 to 1.0
}
```

### Client: Crafting Panel (`crafting_panel.gd`)

```gdscript
# Opened by right-clicking a crafting table block
var grid_slots: Array = []  # 3x3 or 2x2 array of slot controls
var output_slot: Control
var grid_size := 3  # 3 for crafting table, 2 for inventory mini-craft

func _build_crafting_ui(size: int) -> Control:
    grid_size = size
    var container := PanelContainer.new()

    # Grid
    var grid := GridContainer.new()
    grid.columns = size
    for i in range(size * size):
        var slot := _create_craft_slot(i)
        grid.add_child(slot)
        grid_slots.append(slot)

    # Arrow
    var arrow := Label.new()
    arrow.text = "→"

    # Output slot
    output_slot = _create_output_slot()

    # Check recipe on any slot change
    # Show preview in output slot

func _check_recipe() -> void:
    var grid_contents: Array = []
    for row in range(grid_size):
        var row_items: Array = []
        for col in range(grid_size):
            var slot_index := row * grid_size + col
            row_items.append(_get_slot_item_id(slot_index))
        grid_contents.append(row_items)

    # Send to server for recipe matching
    # Or: client-side recipe matching for instant preview
    var recipe = _find_matching_recipe(grid_contents)
    if recipe != null:
        _show_output_preview(recipe.result)
    else:
        _clear_output_preview()

func _on_output_clicked() -> void:
    # Craft: consume ingredients, produce result
    # Shift-click: craft as many as possible
    pass
```

### Client: Furnace Panel (`furnace_panel.gd`)

```gdscript
# Opened by right-clicking a furnace block
var input_slot: Control
var fuel_slot: Control
var output_slot: Control
var burn_progress_bar: ProgressBar  # Fuel remaining
var cook_progress_bar: ProgressBar  # Smelting progress

func _build_furnace_ui() -> Control:
    # Input slot (top)
    # Fuel slot (bottom-left) — accepts coal, wood, lava bucket
    # Fire icon with burn progress
    # Arrow with cook progress
    # Output slot (right)
    pass

func _update_furnace_state(state: Dictionary) -> void:
    burn_progress_bar.value = state.burn_time_remaining / state.max_burn_time
    cook_progress_bar.value = state.cook_progress
```

### Fuel Values

| Item | Burn Time (seconds) | Items Smelted |
|------|-------------------|---------------|
| Coal | 80 | 8 |
| Wood planks | 15 | 1.5 |
| Wood log | 15 | 1.5 |
| Sticks | 5 | 0.5 |
| Lava bucket | 1000 | 100 |
| Coal block | 800 | 80 |

## Files Modified/Created

| File | Type |
|------|------|
| `src/world/crafting-service.ts` | New |
| `src/routes/crafting.ts` | New |
| `src/contracts.ts` | Modified (add crafting types) |
| `native-client/godot/scripts/ui/crafting_panel.gd` | New |
| `native-client/godot/scripts/ui/furnace_panel.gd` | New |

## Acceptance Criteria

- [ ] 3x3 crafting grid at crafting table
- [ ] 2x2 mini-crafting in inventory
- [ ] Shaped recipes match pattern
- [ ] Shapeless recipes match any arrangement
- [ ] Output preview before clicking
- [ ] Shift-click crafts max stack
- [ ] Furnace: input + fuel → output in 10 seconds
- [ ] Fuel burns down, progress shown
- [ ] 100+ recipes defined
- [ ] Recipe book shows discovered recipes
