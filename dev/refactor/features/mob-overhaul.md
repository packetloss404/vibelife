# Feature: Mob Overhaul

**Sprint**: 5
**Status**: Not Started
**Priority**: Medium-High — populates the world

## Summary

Replace abstract enemy shapes with blocky Minecraft-style mob models. Add hostile (zombie, skeleton, creeper, spider, enderman), passive (cow, pig, sheep, chicken), and neutral (wolf, iron golem) mobs with proper AI, spawning rules, loot, and animations.

## Current State

`enemy-service.ts` has 5 enemy types: slime, skeleton, golem, shadow, drake. Basic AI states: idle, patrol, aggro, chase, attack, dead. 1-second AI tick.

`enemy_renderer.gd` renders enemies as colored boxes with basic movement.

## Target State

### Mob Types

#### Hostile (spawn in dark / at night)

| Mob | HP | Damage | Speed | Behavior | Drops | Model |
|-----|----|--------|-------|----------|-------|-------|
| Zombie | 20 | 2-4 | 0.8 | Chase player, melee, burns in sun | rotten_flesh(0-2), rare: iron_ingot, carrot, potato | Green humanoid, torn clothes |
| Skeleton | 20 | 2-5 | 1.0 | Keep distance, ranged bow | bone(0-2), arrow(0-2), rare: bow | White bones humanoid, holds bow |
| Creeper | 20 | explosion | 0.9 | Approach silently, hiss 1.5s, explode (r=3 blocks) | gunpowder(0-2) | Green cylinder with face, 4 legs |
| Spider | 16 | 2-3 | 1.3 | Fast melee, wall climb, neutral in day | string(0-2), spider_eye(0-1) | Wide flat body, 8 legs |
| Enderman | 40 | 4-7 | 1.5 | Teleports, ONLY aggro when player looks at face | ender_pearl(0-1) | Tall thin black body, purple eyes |

#### Passive (spawn on grass in daylight)

| Mob | HP | Speed | Behavior | Drops | Special |
|-----|----|-------|----------|-------|---------|
| Cow | 10 | 0.6 | Wander, flee when hit | leather(0-2), raw_beef(1-3) | Milk with bucket (right-click) |
| Pig | 10 | 0.6 | Wander, flee when hit | raw_porkchop(1-3) | Saddle ride (future) |
| Sheep | 8 | 0.6 | Wander, eat grass, flee | wool(1), raw_mutton(1-2) | Shear for 1-3 wool, dye-able |
| Chicken | 4 | 0.5 | Wander, flutter fall (no fall damage) | feather(0-2), raw_chicken(1) | Lay egg every 5-10 min |

#### Neutral

| Mob | HP | Damage | Behavior | Taming |
|-----|----|--------|----------|--------|
| Wolf | 8 (wild), 20 (tamed) | 2-4 | Pack behavior, attacks when hit | Bones (1-5 attempts), becomes pet |
| Iron Golem | 100 | 7-21 | Patrols village, attacks hostiles | Spawns naturally near villages |

### Blocky Models

Each mob built from box meshes like the player model:

```gdscript
func _build_zombie_model() -> Node3D:
    var root := Node3D.new()
    # Head: 0.5x0.5x0.5 (same as player, green tinted)
    # Body: 0.5x0.75x0.25 (green shirt, darker pants)
    # Arms: extended forward (zombie pose), 0.25x0.75x0.25
    # Legs: 0.25x0.75x0.25
    # Total: same proportions as player but green/brown colors
    return root

func _build_creeper_model() -> Node3D:
    var root := Node3D.new()
    # Head: 0.5x0.5x0.5 (with creeper face pattern on front)
    # Body: 0.375x0.75x0.375 (green, slightly narrower)
    # 4 Legs: 0.25x0.5x0.25 (no arms!)
    # No arms — creepers have 4 legs and a body/head
    return root

func _build_cow_model() -> Node3D:
    var root := Node3D.new()
    # Head: 0.5x0.5x0.375 (with horns as small boxes)
    # Body: 0.75x0.625x0.375 (horizontal, brown/white patches)
    # 4 Legs: 0.25x0.5x0.25 (underneath body)
    # Udder: small pink box underneath body (back)
    return root

func _build_spider_model() -> Node3D:
    var root := Node3D.new()
    # Head: 0.5x0.375x0.5
    # Body: 0.875x0.375x0.625 (wide, flat)
    # 8 Legs: 4 per side, angled outward, 0.125x0.5x0.125
    # Eyes: 2x4 grid of red dots on face
    return root
```

### AI Behaviors

```typescript
// Enhanced AI tick (runs every 1 second on server)

function tickMobAI(mob: MobState, players: AvatarState[], world: VoxelWorld): void {
  switch (mob.variant) {
    case "zombie":
    case "skeleton":
      // Burn in sunlight (sky light >= 12 and daytime)
      if (isInSunlight(mob, world) && isDay(world)) {
        mob.hp -= 1 // Fire damage
        mob.onFire = true
      }

      // Aggro: detect player within 16 blocks
      const target = findNearestPlayer(mob, players, 16)
      if (target) {
        mob.state = "chase"
        mob.targetId = target.accountId
        // A* pathfind toward target
        const path = pathfindVoxel(mob.pos, target.pos, world)
        moveAlongPath(mob, path, mob.speed)

        // Attack when within range
        if (distance(mob.pos, target.pos) < 1.5) {
          mob.state = "attack"
          if (mob.variant === "skeleton") {
            // Shoot arrow (projectile entity)
            shootArrow(mob, target)
          } else {
            // Melee hit
            dealDamage(target, mob.damage)
          }
        }
      } else {
        // Wander randomly
        mob.state = "patrol"
        randomWander(mob, world)
      }
      break

    case "creeper":
      const cTarget = findNearestPlayer(mob, players, 16)
      if (cTarget && distance(mob.pos, cTarget.pos) < 3) {
        mob.fuseTimer = (mob.fuseTimer || 0) + 1
        if (mob.fuseTimer >= 1.5) {
          // EXPLODE
          explode(mob.pos, 3, world) // Destroy blocks in radius
          dealAOEDamage(mob.pos, 3, players) // Damage nearby players
          mob.state = "dead"
        }
      } else {
        mob.fuseTimer = 0
        if (cTarget) {
          mob.state = "chase"
          moveToward(mob, cTarget.pos)
        } else {
          randomWander(mob, world)
        }
      }
      break

    case "cow":
    case "pig":
    case "sheep":
    case "chicken":
      // Passive: wander, flee when hit
      if (mob.recentlyHit) {
        mob.state = "flee"
        moveAwayFrom(mob, mob.lastHitBy, mob.speed * 1.5)
        if (mob.fleeTimer > 5) mob.recentlyHit = false
      } else {
        randomWander(mob, world)
      }
      break
  }
}
```

### Spawning Rules

```typescript
function spawnMobs(region: Region, world: VoxelWorld): void {
  for (const player of region.players) {
    const playerChunk = getChunkAt(player.pos)

    // Hostile: spawn in dark areas (light < 7)
    // Check random positions in 24-128 block radius
    for (let attempt = 0; attempt < 4; attempt++) {
      const pos = randomPosInRange(player.pos, 24, 128)
      const light = getBlockLight(pos, world)
      if (light < 7 && isSolidBelow(pos, world) && isAirAt(pos, world)) {
        const hostileCount = countHostilesNear(player.pos, 128)
        if (hostileCount < 70) {
          const variant = weightedRandom(["zombie", "skeleton", "spider", "creeper", "enderman"])
          spawnMob(variant, pos, region)
        }
      }
    }

    // Passive: spawn on grass in light
    const passiveCount = countPassivesNear(player.pos, 128)
    if (passiveCount < 10) {
      const pos = randomGrassBlock(player.pos, 32, world)
      if (pos && getBlockLight(pos, world) >= 9) {
        const variant = weightedRandom(["cow", "pig", "sheep", "chicken"])
        spawnMob(variant, pos, region)
      }
    }
  }
}

// Despawn: hostile mobs > 128 blocks from any player
// Passive mobs persist until killed
```

### A* Pathfinding on Voxel Grid

```typescript
function pathfindVoxel(from: Vec3, to: Vec3, world: VoxelWorld): Vec3[] {
  // Nodes: block positions that have solid below and air at feet+head level
  // Edges: adjacent walkable blocks (4 cardinal + 4 diagonal)
  // Jump edges: can step up 1 block if air above destination
  // Cost: 1 for cardinal, 1.414 for diagonal, 1.5 for jump
  // Heuristic: 3D Euclidean distance
  // Max iterations: 200 (give up if path too complex)
}
```

## Files Modified

| File | Changes |
|------|---------|
| `src/world/enemy-service.ts` | All new mob types, spawning rules, AI behaviors |
| `src/world/pet-service.ts` | Wolf taming integration |
| `src/contracts.ts` | Expand EnemyStateContract variants |
| `enemy_renderer.gd` | Blocky models for each mob, animations |

## Acceptance Criteria

- [ ] All 11 mob types implemented with unique behaviors
- [ ] Blocky models for each mob
- [ ] Idle, walk, attack, death animations
- [ ] Hostile mobs spawn in darkness (light < 7)
- [ ] Passive mobs spawn on grass
- [ ] Undead burn in sunlight
- [ ] Creeper explodes and destroys blocks
- [ ] Skeleton shoots arrows
- [ ] Spider climbs walls, neutral in day
- [ ] Enderman only aggro when looked at
- [ ] Wolf tameable with bones → becomes pet
- [ ] All mobs drop correct loot + XP
- [ ] A* pathfinding on voxel grid
- [ ] Mobs despawn at >128 blocks from players
