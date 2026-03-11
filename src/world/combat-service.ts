import { getSession, type Session } from "./store.js";
import { broadcastRegion, nextRegionSequence } from "./region.js";
import {
  persistence,
  type Parcel
} from "./_shared-state.js";

// ── Types ──────────────────────────────────────────────────────────────────

export type CombatStats = {
  accountId: string;
  level: number;
  hp: number;
  maxHp: number;
  mana: number;
  maxMana: number;
  strength: number;
  defense: number;
  xp: number;
  xpToNext: number;
  kills: number;
  deaths: number;
};

export type AttackStyle = "melee" | "magic";

export type AttackResult = {
  damage: number;
  critical: boolean;
  targetHp: number;
  targetMaxHp: number;
  killed: boolean;
  xpGained: number;
  leveledUp: boolean;
  newLevel: number;
};

// ── In-memory storage ──────────────────────────────────────────────────────

const combatStatsMap = new Map<string, CombatStats>();

// ── Level formulas ─────────────────────────────────────────────────────────

function calcMaxHp(level: number): number {
  return 100 + level * 20;
}

function calcMaxMana(level: number): number {
  return 50 + level * 10;
}

function calcStrength(level: number): number {
  return 10 + level * 2;
}

function calcDefense(level: number): number {
  return 5 + level * 2;
}

function calcXpToNext(level: number): number {
  return level * 100;
}

// ── Core functions ─────────────────────────────────────────────────────────

export function getOrCreateStats(accountId: string): CombatStats {
  let stats = combatStatsMap.get(accountId);

  if (!stats) {
    const level = 1;
    stats = {
      accountId,
      level,
      hp: calcMaxHp(level),
      maxHp: calcMaxHp(level),
      mana: calcMaxMana(level),
      maxMana: calcMaxMana(level),
      strength: calcStrength(level),
      defense: calcDefense(level),
      xp: 0,
      xpToNext: calcXpToNext(level),
      kills: 0,
      deaths: 0
    };
    combatStatsMap.set(accountId, stats);
  }

  return stats;
}

export function getCombatStats(token: string): CombatStats | undefined {
  const session = getSession(token);

  if (!session) {
    return undefined;
  }

  return getOrCreateStats(session.accountId);
}

export function computeDamage(
  attacker: CombatStats,
  defenderDefense: number,
  style: AttackStyle
): { damage: number; critical: boolean; manaCost: number } {
  let multiplier: number;
  let manaCost = 0;

  if (style === "magic") {
    multiplier = 1.5;
    manaCost = 20;
  } else {
    multiplier = 1.0;
  }

  let damage = Math.max(1, Math.floor(attacker.strength * multiplier - defenderDefense));

  const critical = Math.random() < 0.1;

  if (critical) {
    damage *= 2;
  }

  return { damage, critical, manaCost };
}

export function awardXp(accountId: string, amount: number): { leveledUp: boolean; newLevel: number } {
  const stats = getOrCreateStats(accountId);

  stats.xp += amount;

  let leveledUp = false;

  while (stats.xp >= stats.xpToNext && stats.level < 100) {
    stats.xp -= stats.xpToNext;
    stats.level += 1;
    stats.maxHp = calcMaxHp(stats.level);
    stats.maxMana = calcMaxMana(stats.level);
    stats.strength = calcStrength(stats.level);
    stats.defense = calcDefense(stats.level);
    stats.xpToNext = calcXpToNext(stats.level);
    stats.hp = stats.maxHp;
    stats.mana = stats.maxMana;
    leveledUp = true;
  }

  return { leveledUp, newLevel: stats.level };
}

export async function handlePlayerDeath(
  accountId: string,
  regionId: string
): Promise<{ respawnX: number; respawnY: number; respawnZ: number }> {
  const stats = getOrCreateStats(accountId);

  stats.deaths += 1;
  resetStatsOnDeath(accountId);

  // Deduct 5% currency as death penalty
  const balance = await persistence.getCurrencyBalance(accountId);
  const penalty = Math.floor(balance * 0.05);

  if (penalty > 0) {
    await persistence.addCurrency({
      fromAccountId: accountId,
      toAccountId: "system",
      amount: penalty,
      type: "death_penalty",
      description: "Death penalty: 5% currency deducted"
    });
  }

  // Find nearest parcel for respawn
  const parcels = await persistence.listParcels(regionId);
  let respawnX = 0;
  let respawnY = 0;
  let respawnZ = 0;

  if (parcels.length > 0) {
    const parcel = parcels[0];
    respawnX = (parcel.minX + parcel.maxX) / 2;
    respawnY = 0;
    respawnZ = (parcel.minZ + parcel.maxZ) / 2;
  }

  broadcastRegion(regionId, {
    type: "combat:death",
    sequence: nextRegionSequence(regionId),
    accountId,
    killedBy: "enemy",
    respawnX,
    respawnY,
    respawnZ
  });

  broadcastRegion(regionId, {
    type: "combat:respawn",
    sequence: nextRegionSequence(regionId),
    accountId,
    x: respawnX,
    y: respawnY,
    z: respawnZ
  });

  return { respawnX, respawnY, respawnZ };
}

export function regenTick(accountId: string): void {
  const stats = combatStatsMap.get(accountId);

  if (!stats) {
    return;
  }

  const hpRegen = Math.floor(stats.maxHp * 0.02);
  const manaRegen = Math.floor(stats.maxMana * 0.03);

  stats.hp = Math.min(stats.maxHp, stats.hp + hpRegen);
  stats.mana = Math.min(stats.maxMana, stats.mana + manaRegen);
}

export function getLeaderboard(limit: number): CombatStats[] {
  const allStats = Array.from(combatStatsMap.values());

  allStats.sort((a, b) => {
    if (b.level !== a.level) {
      return b.level - a.level;
    }

    return b.kills - a.kills;
  });

  return allStats.slice(0, limit);
}

export function resetStatsOnDeath(accountId: string): void {
  const stats = getOrCreateStats(accountId);

  stats.hp = stats.maxHp;
  stats.mana = stats.maxMana;
}
