// Enemy Service — Enemy AI for VibeLife voxel MMORPG
//
// INTEGRATION NOTES (do NOT auto-apply):
// - server.ts: import and call startEnemyTickLoop() after initializeWorldStore():
//     import { startEnemyTickLoop } from "./world/enemy-service.js";
//     startEnemyTickLoop();
//
// - store.ts: add re-exports if barrel-exporting:
//     export { ... } from "./enemy-service.js";

import { randomUUID } from "node:crypto";
import { getSession, getRegionPopulation, listRegions, type Session, type AvatarState } from "./store.js";
import { broadcastRegion, nextRegionSequence } from "./region.js";
import { getOrCreateStats, computeDamage, awardXp, type CombatStats, type AttackResult } from "./combat-service.js";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export type EnemyVariant = "slime" | "skeleton" | "golem" | "shadow" | "drake";

export type EnemyState = "idle" | "patrol" | "aggro" | "chase" | "attack" | "dead";

export type LootDrop = {
  itemName: string;
  chance: number;        // 0-1
  currencyMin: number;
  currencyMax: number;
};

export type EnemyInstance = {
  id: string;
  regionId: string;
  variant: EnemyVariant;
  level: number;
  hp: number;
  maxHp: number;
  defense: number;
  strength: number;
  x: number;
  y: number;
  z: number;
  state: EnemyState;
  targetAvatarId: string | null;
  spawnX: number;
  spawnZ: number;
  respawnAt: number | null;
  lootTable: LootDrop[];
};

// ---------------------------------------------------------------------------
// Enemy Definitions (base stats at level 1)
// ---------------------------------------------------------------------------

type EnemyDefinition = {
  hp: number;
  strength: number;
  defense: number;
  lootTable: LootDrop[];
};

const ENEMY_DEFS: Record<EnemyVariant, EnemyDefinition> = {
  slime: {
    hp: 50,
    strength: 5,
    defense: 2,
    lootTable: [
      { itemName: "currency", chance: 1.0, currencyMin: 5, currencyMax: 15 },
    ],
  },
  skeleton: {
    hp: 80,
    strength: 10,
    defense: 5,
    lootTable: [
      { itemName: "currency", chance: 1.0, currencyMin: 10, currencyMax: 25 },
      { itemName: "bone", chance: 0.3, currencyMin: 0, currencyMax: 0 },
    ],
  },
  golem: {
    hp: 200,
    strength: 15,
    defense: 15,
    lootTable: [
      { itemName: "currency", chance: 1.0, currencyMin: 20, currencyMax: 50 },
      { itemName: "stone_core", chance: 0.2, currencyMin: 0, currencyMax: 0 },
    ],
  },
  shadow: {
    hp: 100,
    strength: 20,
    defense: 3,
    lootTable: [
      { itemName: "currency", chance: 1.0, currencyMin: 15, currencyMax: 40 },
      { itemName: "shadow_essence", chance: 0.15, currencyMin: 0, currencyMax: 0 },
    ],
  },
  drake: {
    hp: 500,
    strength: 25,
    defense: 20,
    lootTable: [
      { itemName: "currency", chance: 1.0, currencyMin: 50, currencyMax: 150 },
      { itemName: "drake_scale", chance: 0.1, currencyMin: 0, currencyMax: 0 },
    ],
  },
};

const VARIANTS: EnemyVariant[] = ["slime", "skeleton", "golem", "shadow", "drake"];

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

const enemies = new Map<string, EnemyInstance>();
const regionEnemies = new Map<string, Set<string>>();

/** Tracks last attack timestamp per enemy (for 1.5s cooldown). */
const lastAttackTime = new Map<string, number>();

// ---------------------------------------------------------------------------
// Spawning
// ---------------------------------------------------------------------------

export function spawnEnemy(
  regionId: string,
  variant: EnemyVariant,
  level: number,
  x: number,
  z: number,
): EnemyInstance {
  const def = ENEMY_DEFS[variant];
  const hpScaled = Math.floor(def.hp * (1 + (level - 1) * 0.25));
  const strScaled = Math.floor(def.strength * (1 + (level - 1) * 0.2));
  const defScaled = Math.floor(def.defense * (1 + (level - 1) * 0.2));

  const enemy: EnemyInstance = {
    id: randomUUID(),
    regionId,
    variant,
    level,
    hp: hpScaled,
    maxHp: hpScaled,
    defense: defScaled,
    strength: strScaled,
    x,
    y: 0,
    z,
    state: "idle",
    targetAvatarId: null,
    spawnX: x,
    spawnZ: z,
    respawnAt: null,
    lootTable: def.lootTable.map((l) => ({ ...l })),
  };

  enemies.set(enemy.id, enemy);

  let regionSet = regionEnemies.get(regionId);
  if (!regionSet) {
    regionSet = new Set();
    regionEnemies.set(regionId, regionSet);
  }
  regionSet.add(enemy.id);

  return enemy;
}

export function initRegionEnemies(regionId: string): EnemyInstance[] {
  const count = 3 + Math.floor(Math.random() * 3); // 3-5
  const spawned: EnemyInstance[] = [];

  for (let i = 0; i < count; i++) {
    const variant = VARIANTS[Math.floor(Math.random() * VARIANTS.length)];
    const level = 1 + Math.floor(Math.random() * 5);

    // Spawn at edges to avoid parcel areas: x/z between -25 and -15 or 15 and 25
    const edgeX = randomEdge();
    const edgeZ = randomEdge();

    spawned.push(spawnEnemy(regionId, variant, level, edgeX, edgeZ));
  }

  return spawned;
}

function randomEdge(): number {
  // Returns a value in [-25, -15] or [15, 25]
  const offset = 15 + Math.random() * 10; // 15-25
  return Math.random() < 0.5 ? -offset : offset;
}

export function getEnemiesInRegion(regionId: string): EnemyInstance[] {
  const ids = regionEnemies.get(regionId);
  if (!ids) return [];

  const result: EnemyInstance[] = [];
  for (const id of ids) {
    const enemy = enemies.get(id);
    if (enemy && enemy.state !== "dead") {
      result.push(enemy);
    }
  }
  return result;
}

export function getEnemy(enemyId: string): EnemyInstance | undefined {
  return enemies.get(enemyId);
}

// ---------------------------------------------------------------------------
// AI Tick
// ---------------------------------------------------------------------------

function distXZ(ax: number, az: number, bx: number, bz: number): number {
  const dx = ax - bx;
  const dz = az - bz;
  return Math.sqrt(dx * dx + dz * dz);
}

function findNearestPlayer(enemy: EnemyInstance, population: AvatarState[]): AvatarState | null {
  let nearest: AvatarState | null = null;
  let nearestDist = Infinity;

  for (const avatar of population) {
    const d = distXZ(enemy.x, enemy.z, avatar.x, avatar.z);
    if (d < nearestDist) {
      nearestDist = d;
      nearest = avatar;
    }
  }

  return nearest;
}

function findTarget(enemy: EnemyInstance, population: AvatarState[]): AvatarState | null {
  if (enemy.targetAvatarId) {
    const target = population.find((a) => a.avatarId === enemy.targetAvatarId);
    if (target) return target;
    // Target left region, clear
    enemy.targetAvatarId = null;
  }
  return null;
}

function moveToward(enemy: EnemyInstance, tx: number, tz: number, speed: number): void {
  const d = distXZ(enemy.x, enemy.z, tx, tz);
  if (d <= speed) {
    enemy.x = tx;
    enemy.z = tz;
    return;
  }
  const ratio = speed / d;
  enemy.x += (tx - enemy.x) * ratio;
  enemy.z += (tz - enemy.z) * ratio;
}

function tickEnemy(enemy: EnemyInstance, population: AvatarState[], now: number): boolean {
  // Returns true if enemy moved (needs broadcast)
  if (enemy.state === "dead") {
    if (enemy.respawnAt && now >= enemy.respawnAt) {
      // Respawn
      const def = ENEMY_DEFS[enemy.variant];
      const hpScaled = Math.floor(def.hp * (1 + (enemy.level - 1) * 0.25));
      enemy.hp = hpScaled;
      enemy.maxHp = hpScaled;
      enemy.x = enemy.spawnX;
      enemy.y = 0;
      enemy.z = enemy.spawnZ;
      enemy.state = "idle";
      enemy.targetAvatarId = null;
      enemy.respawnAt = null;

      broadcastRegion(enemy.regionId, {
        type: "enemy:spawned",
        sequence: nextRegionSequence(enemy.regionId),
        enemy: serializeEnemy(enemy),
      } as unknown as import("../contracts.js").RegionEvent);
    }
    return false;
  }

  switch (enemy.state) {
    case "idle": {
      if (Math.random() < 0.2) {
        enemy.state = "patrol";
      }
      // Check aggro
      const nearest = findNearestPlayer(enemy, population);
      if (nearest && distXZ(enemy.x, enemy.z, nearest.x, nearest.z) <= 8) {
        enemy.state = "aggro";
        enemy.targetAvatarId = nearest.avatarId;
      }
      return false;
    }

    case "patrol": {
      // Random walk within 5 units of spawn
      const angle = Math.random() * Math.PI * 2;
      const dist = Math.random() * 2;
      let nx = enemy.x + Math.cos(angle) * dist;
      let nz = enemy.z + Math.sin(angle) * dist;

      // Clamp to within 5 units of spawn
      const spawnDist = distXZ(nx, nz, enemy.spawnX, enemy.spawnZ);
      if (spawnDist > 5) {
        const ratio = 5 / spawnDist;
        nx = enemy.spawnX + (nx - enemy.spawnX) * ratio;
        nz = enemy.spawnZ + (nz - enemy.spawnZ) * ratio;
      }

      enemy.x = nx;
      enemy.z = nz;

      // 10% chance to go back idle
      if (Math.random() < 0.1) {
        enemy.state = "idle";
      }

      // Check aggro range
      const nearestP = findNearestPlayer(enemy, population);
      if (nearestP && distXZ(enemy.x, enemy.z, nearestP.x, nearestP.z) <= 8) {
        enemy.state = "aggro";
        enemy.targetAvatarId = nearestP.avatarId;
      }

      return true;
    }

    case "aggro":
    case "chase": {
      enemy.state = "chase";
      const target = findTarget(enemy, population);
      if (!target) {
        enemy.state = "idle";
        enemy.targetAvatarId = null;
        return false;
      }

      const targetDist = distXZ(enemy.x, enemy.z, target.x, target.z);

      // If target too far from spawn, reset
      if (targetDist > 15) {
        enemy.state = "idle";
        enemy.targetAvatarId = null;
        moveToward(enemy, enemy.spawnX, enemy.spawnZ, 2);
        return true;
      }

      if (targetDist <= 3) {
        enemy.state = "attack";
        return false;
      }

      // Move toward target at 2 units/tick
      moveToward(enemy, target.x, target.z, 2);
      return true;
    }

    case "attack": {
      const target = findTarget(enemy, population);
      if (!target) {
        enemy.state = "idle";
        enemy.targetAvatarId = null;
        return false;
      }

      const targetDist = distXZ(enemy.x, enemy.z, target.x, target.z);

      // If target too far, reset
      if (targetDist > 15) {
        enemy.state = "idle";
        enemy.targetAvatarId = null;
        return false;
      }

      // If out of melee range, chase
      if (targetDist > 3) {
        enemy.state = "chase";
        moveToward(enemy, target.x, target.z, 2);
        return true;
      }

      // Check 1.5s cooldown
      const lastAtk = lastAttackTime.get(enemy.id) ?? 0;
      if (now - lastAtk < 1500) {
        return false;
      }

      lastAttackTime.set(enemy.id, now);

      // Deal damage to target player
      const playerStats = getOrCreateStats(target.accountId);
      const { damage, critical } = computeDamage(
        { ...playerStats, strength: enemy.strength } as CombatStats,
        playerStats.defense,
        "melee",
      );
      playerStats.hp = Math.max(0, playerStats.hp - damage);

      broadcastRegion(enemy.regionId, {
        type: "combat:damage",
        sequence: nextRegionSequence(enemy.regionId),
        attackerId: enemy.id,
        targetId: target.avatarId,
        damage,
        critical,
        targetHp: playerStats.hp,
        targetMaxHp: playerStats.maxHp,
        attackStyle: "melee",
      } as unknown as import("../contracts.js").RegionEvent);

      return false;
    }

    default:
      return false;
  }
}

export function enemyTick(): void {
  const now = Date.now();
  const allRegions = listRegions();

  for (const region of allRegions) {
    const population = getRegionPopulation(region.id);
    if (population.length === 0) continue;

    const ids = regionEnemies.get(region.id);
    if (!ids || ids.size === 0) continue;

    const movedEnemies: EnemyInstance[] = [];

    for (const enemyId of ids) {
      const enemy = enemies.get(enemyId);
      if (!enemy) continue;

      const moved = tickEnemy(enemy, population, now);
      if (moved) {
        movedEnemies.push(enemy);
      }
    }

    // Batch broadcast moved enemies
    if (movedEnemies.length > 0) {
      broadcastRegion(region.id, {
        type: "enemy:moved",
        sequence: nextRegionSequence(region.id),
        enemies: movedEnemies.map((e) => ({
          id: e.id, x: e.x, y: e.y, z: e.z, state: e.state as string, hp: e.hp
        })),
      } as unknown as import("../contracts.js").RegionEvent);
    }
  }
}

// ---------------------------------------------------------------------------
// Combat Interaction
// ---------------------------------------------------------------------------

export function attackEnemy(
  token: string,
  enemyId: string,
  style: string,
): AttackResult | { error: string } {
  const session = getSession(token);
  if (!session) return { error: "invalid_session" };

  const enemy = enemies.get(enemyId);
  if (!enemy) return { error: "enemy_not_found" };
  if (enemy.state === "dead") return { error: "enemy_dead" };
  if (enemy.regionId !== session.regionId) return { error: "wrong_region" };

  // Validate range: player must be within 5 units
  const population = getRegionPopulation(session.regionId);
  const playerAvatar = population.find((a) => a.avatarId === session.avatarId);
  if (!playerAvatar) return { error: "avatar_not_found" };

  const dist = distXZ(playerAvatar.x, playerAvatar.z, enemy.x, enemy.z);
  if (dist > 5) return { error: "out_of_range" };

  // Compute damage
  const attackerStats = getOrCreateStats(session.accountId);
  const attackStyle = (style === "melee" || style === "magic" ? style : "melee") as "melee" | "magic";
  const { damage, critical, manaCost } = computeDamage(attackerStats, enemy.defense, attackStyle);

  // Check mana for magic attacks
  if (attackStyle === "magic" && attackerStats.mana < manaCost) {
    return { error: "not_enough_mana" };
  }

  if (manaCost > 0) {
    attackerStats.mana -= manaCost;
  }

  // Apply damage
  enemy.hp = Math.max(0, enemy.hp - damage);
  const killed = enemy.hp <= 0;

  let xpGained = 0;
  let leveledUp = false;
  let newLevel = attackerStats.level;
  let loot: { currency: number; items: string[] } | null = null;

  if (killed) {
    enemy.state = "dead";
    enemy.targetAvatarId = null;
    enemy.respawnAt = Date.now() + 30_000; // 30s respawn

    // Award XP
    xpGained = enemy.level * 20;
    const xpResult = awardXp(session.accountId, xpGained);
    leveledUp = xpResult.leveledUp;
    newLevel = xpResult.newLevel;

    // Roll loot
    loot = rollLoot(enemy);

    // Broadcast death
    broadcastRegion(enemy.regionId, {
      type: "enemy:despawned",
      sequence: nextRegionSequence(enemy.regionId),
      enemyId: enemy.id,
    } as unknown as import("../contracts.js").RegionEvent);

    // Broadcast loot to killer
    if (loot) {
      broadcastRegion(enemy.regionId, {
        type: "combat:loot",
        sequence: nextRegionSequence(enemy.regionId),
        accountId: session.accountId,
        enemyId: enemy.id,
        currency: loot.currency,
        items: loot.items,
      } as unknown as import("../contracts.js").RegionEvent);
    }

    attackerStats.kills += 1;
  } else {
    // Enemy aggros attacker if not already targeting someone
    if (!enemy.targetAvatarId) {
      enemy.targetAvatarId = session.avatarId;
      enemy.state = "chase";
    }
  }

  return {
    damage,
    critical,
    targetHp: enemy.hp,
    targetMaxHp: enemy.maxHp,
    killed,
    xpGained,
    leveledUp,
    newLevel,
  };
}

export function rollLoot(enemy: EnemyInstance): { currency: number; items: string[] } {
  let currency = 0;
  const items: string[] = [];

  for (const drop of enemy.lootTable) {
    if (drop.itemName === "currency") {
      // Currency is guaranteed (chance = 1.0)
      currency = drop.currencyMin + Math.floor(Math.random() * (drop.currencyMax - drop.currencyMin + 1));
    } else {
      // Roll item based on chance
      if (Math.random() < drop.chance) {
        items.push(drop.itemName);
      }
    }
  }

  return { currency, items };
}

// ---------------------------------------------------------------------------
// Tick Loop
// ---------------------------------------------------------------------------

export function startEnemyTickLoop(): ReturnType<typeof setInterval> {
  return setInterval(enemyTick, 1000);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

type SerializedEnemy = {
  id: string;
  regionId: string;
  variant: string;
  level: number;
  hp: number;
  maxHp: number;
  x: number;
  y: number;
  z: number;
  state: string;
};

function serializeEnemy(enemy: EnemyInstance): SerializedEnemy {
  return {
    id: enemy.id,
    regionId: enemy.regionId,
    variant: enemy.variant,
    level: enemy.level,
    hp: enemy.hp,
    maxHp: enemy.maxHp,
    x: enemy.x,
    y: enemy.y,
    z: enemy.z,
    state: enemy.state,
  };
}
