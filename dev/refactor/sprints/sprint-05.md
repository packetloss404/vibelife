# Sprint 5: Mobs & AI

**Phase**: 2E
**Status**: Not Started
**Priority**: 6
**Depends on**: Sprint 1 (voxel world for pathfinding), Sprint 4 (combat to fight mobs)

## Goal

Replace abstract enemy shapes with blocky Minecraft-style mob models. Add hostile, passive, and neutral mob types with proper AI, spawning rules, loot tables, and daylight behavior.

## Features

| Feature | Doc | Status |
|---------|-----|--------|
| Mob Overhaul | [mob-overhaul.md](../features/mob-overhaul.md) | Not Started |

## Files Modified

### Server
| File | Changes |
|------|---------|
| `src/world/enemy-service.ts` | Expand mob types (zombie, skeleton, creeper, spider, enderman, cow, pig, sheep, chicken, wolf, iron_golem). Add spawning rules by light level and biome. Add daylight burning for undead. Improve pathfinding to A* on voxel grid. |
| `src/world/npc-service.ts` | Integrate passive mob NPCs (cow, pig, sheep, chicken) alongside existing NPC types |
| `src/world/pet-service.ts` | Wolf/cat/parrot taming integrates with existing pet system |
| `src/contracts.ts` | Expand `EnemyStateContract` variant to all mob types. Add passive/neutral behavior states. Add mob-specific loot tables. |

### Client
| File | Changes |
|------|---------|
| `native-client/godot/scripts/world/enemy_renderer.gd` | Blocky mob models built from quads. Per-mob mesh generators. Idle animations (head look, leg shuffle). Walking animation. Attack animation. Death animation (fall over, flash red, poof particles). |
| `native-client/godot/scripts/world/pet_manager.gd` | Render tamed mobs as blocky models matching their wild counterparts |

## Acceptance Criteria

- [ ] Zombie: slow melee, burns in daylight, drops rotten_flesh
- [ ] Skeleton: ranged bow, burns in daylight, drops bones + arrows
- [ ] Creeper: silent approach, explodes near player (destroys blocks), drops gunpowder
- [ ] Spider: fast, wall climb, neutral in day, drops string + spider_eye
- [ ] Enderman: teleports, aggro only when looked at, drops ender_pearl
- [ ] Cow: passive, drops leather + beef, milkable
- [ ] Pig: passive, drops porkchop
- [ ] Sheep: passive, drops wool, shearable, dye-able
- [ ] Chicken: passive, drops feathers + chicken, lays eggs
- [ ] Wolf: neutral, tamed with bones → becomes pet
- [ ] All mobs have blocky Minecraft-style models
- [ ] Idle, walk, attack, death animations
- [ ] Hostile mobs spawn when block light < 7
- [ ] Passive mobs spawn on grass in daylight
- [ ] A* pathfinding on voxel grid with jump support
- [ ] Mobs drop XP orbs on death

## Implementation Order

1. Define all mob types and stats in enemy-service.ts
2. Implement blocky mob model generators in enemy_renderer.gd
3. Add idle/walk/attack/death animations
4. Implement light-level-based spawning
5. Add daylight burning for undead
6. Implement A* pathfinding on voxel grid
7. Add creeper explosion (block destruction)
8. Integrate wolf taming with pet system
9. Add passive mob behaviors (cow, pig, sheep, chicken)
10. Add loot drops and XP orbs

## Technical Notes

- Mob models are procedural meshes (quads assembled into body parts)
- Each body part is a separate MeshInstance3D for animation pivoting
- Hostile mobs despawn at > 128 blocks from any player
- Passive mobs: max 10 per chunk, persist until killed
- Spawn cap: 70 hostile, 10 passive, per player within 128-block sphere
- Pathfinding: A* on block grid, nodes are walkable surfaces, edges include 1-block jumps
- Creeper explosion radius: 3 blocks, does NOT drop all broken blocks (only ~30%)
