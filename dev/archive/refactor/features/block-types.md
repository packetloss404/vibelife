# Feature: Block Types Expansion

**Sprint**: 1
**Status**: Not Started
**Priority**: Critical — must be done first in Sprint 1

## Summary

Expand from 12 block types to 60+ with full metadata: name, color, texture atlas coords (top/side/bottom), transparency, solidity, hardness, tool type, drop ID, and light emission level.

## Current State

`block_palette.gd` defines 12 blocks:
```
0:air, 1:stone, 2:dirt, 3:grass, 4:wood, 5:sand, 6:water, 7:ore_iron,
8:ore_gold, 9:ore_crystal, 10:leaves, 11:glass, 12:brick
```

Each block has: name, color, transparent (bool), hardness (float).

## Target State

### Block Registry (60+ blocks)

#### Natural Terrain (IDs 1-20)
| ID | Name | Color | Hardness | Tool | Drop | Light | Transparent | Solid |
|----|------|-------|----------|------|------|-------|-------------|-------|
| 0 | air | transparent | 0 | none | 0 | 0 | true | false |
| 1 | stone | #808080 | 1.5 | pickaxe | 4 (cobblestone) | 0 | false | true |
| 2 | dirt | #8B5A2B | 0.5 | shovel | 2 | 0 | false | true |
| 3 | grass_block | #5D9B2A top, #8B5A2B side | 0.6 | shovel | 2 (dirt) | 0 | false | true |
| 4 | cobblestone | #6B6B6B | 2.0 | pickaxe | 4 | 0 | false | true |
| 5 | sand | #D9C87C | 0.5 | shovel | 5 | 0 | false | true |
| 6 | gravel | #7A7572 | 0.6 | shovel | 6 | 0 | false | true |
| 7 | clay | #9EA4B0 | 0.6 | shovel | 7 | 0 | false | true |
| 8 | sandstone | #D4C48C | 0.8 | pickaxe | 8 | 0 | false | true |
| 9 | snow_block | #F0F0F0 | 0.2 | shovel | 9 | 0 | false | true |
| 10 | ice | #A0D0E8 | 0.5 | pickaxe | 0 (nothing, silk touch=self) | 0 | true | true |
| 11 | obsidian | #1A0A2E | 50.0 | diamond_pickaxe | 11 | 0 | false | true |
| 12 | bedrock | -1 (unbreakable) | none | 0 | 0 | false | true |
| 13 | netherrack | #6B2020 | 0.4 | pickaxe | 13 | 0 | false | true |
| 14 | end_stone | #D9D09A | 3.0 | pickaxe | 14 | 0 | false | true |
| 15 | soul_sand | #4A3828 | 0.5 | shovel | 15 | 0 | false | true |

#### Wood & Planks (IDs 20-35)
| ID | Name | Color | Hardness | Tool | Drop | Light |
|----|------|-------|----------|------|------|-------|
| 20 | oak_log | #6B5030 | 2.0 | axe | 20 | 0 |
| 21 | oak_planks | #B8945A | 2.0 | axe | 21 | 0 |
| 22 | birch_log | #D0C8B0 | 2.0 | axe | 22 | 0 |
| 23 | birch_planks | #C8B888 | 2.0 | axe | 23 | 0 |
| 24 | spruce_log | #3A2810 | 2.0 | axe | 24 | 0 |
| 25 | spruce_planks | #6B5838 | 2.0 | axe | 25 | 0 |
| 26 | jungle_log | #5A4020 | 2.0 | axe | 26 | 0 |
| 27 | jungle_planks | #A87840 | 2.0 | axe | 27 | 0 |

#### Stone Variants (IDs 36-43)
| ID | Name | Color | Hardness | Tool | Drop |
|----|------|-------|----------|------|------|
| 36 | granite | #9A6850 | 1.5 | pickaxe | 36 |
| 37 | diorite | #B0A8A0 | 1.5 | pickaxe | 37 |
| 38 | andesite | #888888 | 1.5 | pickaxe | 38 |
| 39 | smooth_stone | #A0A0A0 | 2.0 | pickaxe | 39 |
| 40 | stone_bricks | #787878 | 1.5 | pickaxe | 40 |
| 41 | mossy_stone_bricks | #687858 | 1.5 | pickaxe | 41 |
| 42 | cracked_stone_bricks | #707070 | 1.5 | pickaxe | 42 |

#### Ores (IDs 44-52)
| ID | Name | Color | Hardness | Tool | Drop | Min Tool Level |
|----|------|-------|----------|------|------|----------------|
| 44 | coal_ore | #303030 in stone | 3.0 | pickaxe | coal_item | wood |
| 45 | iron_ore | #C8A882 in stone | 3.0 | pickaxe | raw_iron_item | stone |
| 46 | gold_ore | #F0D848 in stone | 3.0 | pickaxe | raw_gold_item | iron |
| 47 | diamond_ore | #5CD8E8 in stone | 3.0 | pickaxe | diamond_item | iron |
| 48 | emerald_ore | #40C840 in stone | 3.0 | pickaxe | emerald_item | iron |
| 49 | crystal_ore | #9848E0 in stone | 3.0 | pickaxe | crystal_item | iron |
| 50 | redstone_ore | #D83020 in stone | 3.0 | pickaxe | redstone_item | iron |
| 51 | lapis_ore | #2848A8 in stone | 3.0 | pickaxe | lapis_item | stone |

#### Building Blocks (IDs 53-60)
| ID | Name | Color | Hardness | Tool | Drop | Light |
|----|------|-------|----------|------|------|-------|
| 53 | bricks | #964832 | 2.0 | pickaxe | 53 | 0 |
| 54 | nether_bricks | #301820 | 2.0 | pickaxe | 54 | 0 |
| 55 | quartz_block | #E8E0D0 | 0.8 | pickaxe | 55 | 0 |
| 56 | prismarine | #5A9880 | 1.5 | pickaxe | 56 | 0 |

#### Nature (IDs 61-75)
| ID | Name | Color | Hardness | Transparent | Solid | Light |
|----|------|-------|----------|-------------|-------|-------|
| 61 | oak_leaves | #4A8028 | 0.2 | true | false | 0 |
| 62 | birch_leaves | #68A040 | 0.2 | true | false | 0 |
| 63 | spruce_leaves | #2A5020 | 0.2 | true | false | 0 |
| 64 | jungle_leaves | #38A028 | 0.2 | true | false | 0 |
| 65 | tall_grass | #5D9B2A | 0.0 | true | false | 0 |
| 66 | flower_red | #E03030 | 0.0 | true | false | 0 |
| 67 | flower_yellow | #E0E030 | 0.0 | true | false | 0 |
| 68 | mushroom_red | #D03020 | 0.0 | true | false | 0 |
| 69 | mushroom_brown | #8B6840 | 0.0 | true | false | 0 |
| 70 | vines | #3A7828 | 0.2 | true | false | 0 |
| 71 | lily_pad | #287020 | 0.0 | true | false | 0 |
| 72 | cactus | #2A7828 | 0.4 | false | true | 0 |
| 73 | sugar_cane | #88C858 | 0.0 | true | false | 0 |

#### Fluids (IDs 76-77)
| ID | Name | Color | Transparent | Solid | Light |
|----|------|-------|-------------|-------|-------|
| 76 | water | #3060C0 a=0.6 | true | false | 0 |
| 77 | lava | #E05010 | false | false | 15 |

#### Functional (IDs 78-95)
| ID | Name | Color | Hardness | Tool | Light | Special |
|----|------|-------|----------|------|-------|---------|
| 78 | crafting_table | #8B6840 | 2.5 | axe | 0 | Opens 3x3 crafting |
| 79 | furnace | #707070 | 3.5 | pickaxe | 13 | Smelting GUI |
| 80 | chest | #8B6840 | 2.5 | axe | 0 | Storage GUI |
| 81 | torch | #E8D040 | 0.0 | any | 14 | Wall/floor mount |
| 82 | glass | #D0E0F0 a=0.3 | 0.3 | any | 0 | Breaks to nothing |
| 83 | door_oak | #B8945A | 3.0 | axe | 0 | Toggle open/close |
| 84 | ladder | #A08850 | 0.4 | axe | 0 | Climbable |
| 85 | fence_oak | #B8945A | 2.0 | axe | 0 | 1.5 block collision |
| 86 | gate_oak | #B8945A | 2.0 | axe | 0 | Toggle open/close |
| 87 | slab_stone | #808080 | 2.0 | pickaxe | 0 | Half-height block |
| 88 | stairs_stone | #808080 | 2.0 | pickaxe | 0 | Stair collision |
| 89 | trapdoor_oak | #B8945A | 3.0 | axe | 0 | Toggle open/close |
| 90 | glowstone | #E8D070 | 0.3 | any | 15 | Light source |
| 91 | jack_o_lantern | #E0A020 | 1.0 | axe | 14 | Light source |
| 92 | bookshelf | #8B6840 | 1.5 | axe | 0 | Decorative |
| 93 | tnt | #D03020 | 0.0 | any | 0 | Explosive |
| 94 | jukebox | #6B4030 | 2.0 | axe | 0 | Radio integration |
| 95 | claim_stake | #DAA520 | 5.0 | any | 0 | Parcel claiming |

### Data Structure

#### Server (`src/contracts.ts`)
```typescript
type BlockTypeContract = {
  id: number
  name: string
  color: string           // hex color (fallback when no texture)
  textureTop: number      // atlas index for top face
  textureSide: number     // atlas index for side faces
  textureBottom: number   // atlas index for bottom face
  transparent: boolean
  solid: boolean
  hardness: number        // -1 = unbreakable
  toolType: string        // "pickaxe" | "axe" | "shovel" | "none"
  minToolLevel: number    // 0=hand, 1=wood, 2=stone, 3=iron, 4=diamond
  dropId: number          // item/block ID dropped when broken
  dropCount: number       // how many items dropped
  lightLevel: number      // 0-15, light emitted
  stackSize: number       // max stack in inventory (default 64)
  animated: boolean       // has animation frames (water, lava)
  animFrames: number      // number of animation frames
}
```

#### Client (`block_palette.gd`)
```gdscript
func register_block(id: int, name: String, color: Color, transparent: bool,
    solid: bool, hardness: float, tool_type: String, drop_id: int,
    light_level: int, tex_top: int, tex_side: int, tex_bottom: int) -> void:
  block_types[id] = {
    "name": name, "color": color, "transparent": transparent,
    "solid": solid, "hardness": hardness, "tool_type": tool_type,
    "drop_id": drop_id, "light_level": light_level,
    "tex_top": tex_top, "tex_side": tex_side, "tex_bottom": tex_bottom
  }
```

## Implementation

1. Update `BlockTypeContract` in `contracts.ts`
2. Expand `block_palette.gd` `_init()` with all 60+ blocks
3. Update `sync_from_server()` to handle new fields
4. Update `voxel-service.ts` server-side block registry
5. Verify `is_solid()`, `is_transparent()`, `get_block_color()` work with new fields
6. Test rendering with vertex colors (textures come in Sprint 10)

## Notes

- Colors serve as fallback rendering until texture atlas is created in Sprint 10
- IDs are stable — never reassign an ID to a different block
- Leave gaps in ID ranges for future expansion
- Tool levels: 0=hand, 1=wood, 2=stone, 3=iron, 4=diamond
