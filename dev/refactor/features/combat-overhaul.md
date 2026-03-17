# Feature: Combat Overhaul

**Sprint**: 4
**Status**: Not Started
**Priority**: Medium

## Summary

Overhaul combat with attack cooldown, sweep attacks, critical hits, armor damage reduction, shields, fall damage, and death dropping inventory. Replace instant-click damage with Minecraft 1.9+ style combat.

## Current State

`combat-service.ts` has:
- Basic HP/mana system
- Simple damage formula: `strength * (1 + 0.05 * level) - target_defense * 0.5`
- XP and leveling
- Death broadcasts but no item drops

## Target State

### Attack Cooldown

```typescript
// Each weapon has an attack speed
// After swinging, damage scales from 20% to 100% as cooldown recharges
const ATTACK_SPEEDS: Record<string, number> = {
  hand: 4.0,    // 4 attacks/sec (0.25s cooldown)
  sword: 1.6,   // 1.6 attacks/sec (0.625s cooldown)
  axe: 0.8,     // 0.8 attacks/sec (1.25s cooldown)
  pickaxe: 1.2,
  shovel: 1.0,
}

function calculateDamage(attackerId: string, weaponId: number, cooldownProgress: number): number {
  const baseDamage = getWeaponDamage(weaponId) // 1 for hand, 4-7 for swords
  const damageMultiplier = 0.2 + 0.8 * cooldownProgress // 20% min, 100% max
  return baseDamage * damageMultiplier
}
```

### Critical Hits

```typescript
// Critical hit: player is falling (not on ground) when attacking
// 1.5x damage, star particle burst
function isCriticalHit(attackerState: { falling: boolean; sprintng: boolean }): boolean {
  return attackerState.falling && !attackerState.sprinting
}

// Sweep attack: fully charged sword attack hits nearby enemies too
// Sweep damage: 1 + floor(damage * 0.5) to each nearby mob within 3 blocks
function getSweepTargets(attackerPos: Vector3, targetPos: Vector3, allEntities: Entity[]): Entity[] {
  return allEntities.filter(e =>
    e.id !== target.id &&
    distance(e.pos, targetPos) < 3.0 &&
    distance(e.pos, attackerPos) < 5.0
  )
}
```

### Armor Reduction

```typescript
// Armor points from equipped armor (0-20)
// Each armor point = 4% damage reduction
// Total reduction = armorPoints * 4% (max 80%)

function applyArmorReduction(damage: number, armorPoints: number): number {
  const reduction = Math.min(armorPoints * 0.04, 0.8) // Max 80%
  return damage * (1 - reduction)
}

// Armor durability: each hit reduces durability of random armor piece
```

### Fall Damage

```typescript
// Tracked server-side or client-side with server validation
// Damage = max(0, fallDistance - 3) HP
// Jump from y=10 to y=0 = 10 - 3 = 7 HP damage

function calculateFallDamage(fallDistance: number): number {
  if (fallDistance <= 3) return 0
  return Math.floor(fallDistance - 3)
}
```

### Shield

```typescript
// Right-click to raise shield (offhand slot)
// Blocks 100% damage from the front (180° arc)
// 5-tick cooldown after blocking an attack
// Shield has durability, reduced by blocked damage
// Axe attacks disable shield for 5 seconds
```

### Death

```typescript
function handleDeath(accountId: string, killedBy: string): void {
  // Drop all inventory items at death position
  const items = dropAllItems(accountId, getAvatarPosition(accountId))
  broadcastToRegion(regionId, { type: "item:dropped", entities: items })

  // Drop XP orbs (capped at 7 levels worth)
  const xpToDrop = Math.min(stats.xp, stats.level * 7)
  broadcastToRegion(regionId, { type: "xp:dropped", amount: xpToDrop, position })

  // Reset stats
  stats.hp = stats.maxHp
  stats.hunger = 20
  stats.saturation = 5

  // Respawn at bed or world spawn after 5 seconds
  // Death message: "PlayerName was slain by Zombie"
  broadcastToRegion(regionId, { type: "combat:death", accountId, killedBy, message })
}
```

### Client: Combat HUD Changes

```gdscript
# Hearts: 10 hearts, each = 2 HP
# Flash red when taking damage
# Absorb hearts (golden, above red hearts) from golden apples
# Wither effect: hearts turn black
# Poison effect: hearts turn green

# Attack cooldown indicator:
# Small sword icon below crosshair fills up as cooldown recharges
# Only visible when cooldown < 100%
```

## Files Modified

| File | Changes |
|------|---------|
| `src/world/combat-service.ts` | Cooldown, crits, sweep, armor, fall damage, death drops |
| `src/contracts.ts` | Update CombatStatsContract, add attack events |
| `native-client/godot/scripts/ui/combat_hud.gd` | Hearts, cooldown indicator, damage flash |
| `native-client/godot/scripts/main.gd` | Fall damage tracking, attack cooldown timer |

## Acceptance Criteria

- [ ] Attack cooldown: 0.625s for swords, damage scales with charge
- [ ] Critical hit: 1.5x when falling + attacking, star particles
- [ ] Sweep attack: hits nearby mobs with fully charged sword
- [ ] Armor reduces damage (4% per armor point, max 80%)
- [ ] Fall damage: 1 HP per block beyond 3
- [ ] Death drops all inventory items at death position
- [ ] Death drops XP orbs
- [ ] Respawn at bed or world spawn after 5s delay
- [ ] Death message broadcast to region
- [ ] Hearts flash red on damage
- [ ] Cooldown indicator below crosshair
- [ ] Shield blocks frontal damage (right-click)
- [ ] Knockback on hit
