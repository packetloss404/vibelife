import { randomUUID } from "node:crypto";
import { getSession, type Session } from "./store.js";

// ── Types ──────────────────────────────────────────────────────────────────

export type GuildEnhancements = {
  groupId: string;
  treasury: number;
  emblemColor: string;
  emblemIcon: string;
  bannerText: string;
  ownedParcelIds: string[];
  alliances: string[];
};

export type TreasuryTransaction = {
  id: string;
  groupId: string;
  accountId: string;
  displayName: string;
  amount: number;
  type: "deposit" | "withdraw";
  createdAt: string;
};

export type AllianceProposal = {
  id: string;
  fromGroupId: string;
  toGroupId: string;
  status: "pending" | "accepted";
  createdAt: string;
};

// ── In-memory stores ───────────────────────────────────────────────────────

const guildEnhancements = new Map<string, GuildEnhancements>();
const treasuryHistory = new Map<string, TreasuryTransaction[]>();
const allianceProposals = new Map<string, AllianceProposal>();

// We import lazily from store to avoid circular-import issues; helpers wrap
// the persistence calls that already exist.

import {
  getGroupMembers as storeGetGroupMembers,
  listGroups as storeListGroups,
  listParcels as storeListParcels,
  getCurrencyBalance as storeGetCurrencyBalance,
  sendCurrency as storeSendCurrency,
} from "./store.js";

// ── Helpers ────────────────────────────────────────────────────────────────

function getOrCreateEnhancements(groupId: string): GuildEnhancements {
  let e = guildEnhancements.get(groupId);
  if (!e) {
    e = {
      groupId,
      treasury: 0,
      emblemColor: "#ffffff",
      emblemIcon: "default",
      bannerText: "",
      ownedParcelIds: [],
      alliances: [],
    };
    guildEnhancements.set(groupId, e);
  }
  return e;
}

function getTreasuryLog(groupId: string): TreasuryTransaction[] {
  let log = treasuryHistory.get(groupId);
  if (!log) {
    log = [];
    treasuryHistory.set(groupId, log);
  }
  return log;
}

async function getMemberRole(
  token: string,
  groupId: string
): Promise<"owner" | "officer" | "member" | null> {
  const session = getSession(token);
  if (!session) return null;
  const members = await storeGetGroupMembers(token, groupId);
  const me = members.find((m) => m.accountId === session.accountId);
  return (me?.role as "owner" | "officer" | "member") ?? null;
}

function isOfficerOrOwner(role: string | null): boolean {
  return role === "officer" || role === "owner";
}

// ── Public API ─────────────────────────────────────────────────────────────

export async function getGuildDetails(
  groupId: string
): Promise<GuildEnhancements> {
  return getOrCreateEnhancements(groupId);
}

export async function setGroupParcel(
  token: string,
  groupId: string,
  parcelId: string
): Promise<{ ok: boolean; reason?: string }> {
  const role = await getMemberRole(token, groupId);
  if (!isOfficerOrOwner(role))
    return { ok: false, reason: "must be officer or owner" };

  const session = getSession(token)!;
  // Check the caller owns the parcel in the current region
  const parcels = await storeListParcels(session.regionId);
  const parcel = parcels.find((p) => p.id === parcelId);
  if (!parcel || parcel.ownerAccountId !== session.accountId)
    return { ok: false, reason: "you must own the parcel to assign it" };

  const e = getOrCreateEnhancements(groupId);
  if (!e.ownedParcelIds.includes(parcelId)) {
    e.ownedParcelIds.push(parcelId);
  }
  return { ok: true };
}

export async function removeGroupParcel(
  token: string,
  groupId: string,
  parcelId: string
): Promise<{ ok: boolean; reason?: string }> {
  const role = await getMemberRole(token, groupId);
  if (!isOfficerOrOwner(role))
    return { ok: false, reason: "must be officer or owner" };

  const e = getOrCreateEnhancements(groupId);
  e.ownedParcelIds = e.ownedParcelIds.filter((id) => id !== parcelId);
  return { ok: true };
}

export async function listGroupParcels(groupId: string): Promise<string[]> {
  return getOrCreateEnhancements(groupId).ownedParcelIds;
}

export async function depositToTreasury(
  token: string,
  groupId: string,
  amount: number
): Promise<{ ok: boolean; treasury?: number; reason?: string }> {
  const session = getSession(token);
  if (!session) return { ok: false, reason: "invalid session" };
  if (amount <= 0) return { ok: false, reason: "amount must be positive" };

  const role = await getMemberRole(token, groupId);
  if (!role) return { ok: false, reason: "not a group member" };

  const balance = await storeGetCurrencyBalance(token);
  if (balance < amount) return { ok: false, reason: "insufficient funds" };

  // Deduct from personal balance via a currency send to a system account
  const newBalance = await storeSendCurrency(token, "system-treasury", amount, `guild treasury deposit: ${groupId}`);
  if (newBalance === undefined)
    return { ok: false, reason: "currency transfer failed" };

  const e = getOrCreateEnhancements(groupId);
  e.treasury += amount;

  const log = getTreasuryLog(groupId);
  log.push({
    id: randomUUID(),
    groupId,
    accountId: session.accountId,
    displayName: session.displayName,
    amount,
    type: "deposit",
    createdAt: new Date().toISOString(),
  });

  return { ok: true, treasury: e.treasury };
}

export async function withdrawFromTreasury(
  token: string,
  groupId: string,
  amount: number
): Promise<{ ok: boolean; treasury?: number; reason?: string }> {
  const session = getSession(token);
  if (!session) return { ok: false, reason: "invalid session" };
  if (amount <= 0) return { ok: false, reason: "amount must be positive" };

  const role = await getMemberRole(token, groupId);
  if (!isOfficerOrOwner(role))
    return { ok: false, reason: "must be officer or owner" };

  const e = getOrCreateEnhancements(groupId);
  if (e.treasury < amount)
    return { ok: false, reason: "insufficient treasury funds" };

  e.treasury -= amount;

  const log = getTreasuryLog(groupId);
  log.push({
    id: randomUUID(),
    groupId,
    accountId: session.accountId,
    displayName: session.displayName,
    amount,
    type: "withdraw",
    createdAt: new Date().toISOString(),
  });

  return { ok: true, treasury: e.treasury };
}

export async function getTreasuryBalance(groupId: string): Promise<number> {
  return getOrCreateEnhancements(groupId).treasury;
}

export async function getTreasuryHistory(
  groupId: string
): Promise<TreasuryTransaction[]> {
  return getTreasuryLog(groupId);
}

export async function setMemberRole(
  token: string,
  groupId: string,
  targetAccountId: string,
  role: "member" | "officer" | "owner"
): Promise<{ ok: boolean; reason?: string }> {
  const callerRole = await getMemberRole(token, groupId);
  if (!callerRole) return { ok: false, reason: "not a group member" };

  // Owner can promote to officer or owner; officer can only set member
  if (role === "officer" || role === "owner") {
    if (callerRole !== "owner")
      return { ok: false, reason: "only owners can promote to officer/owner" };
  }
  if (role === "member") {
    if (!isOfficerOrOwner(callerRole))
      return { ok: false, reason: "must be officer or owner to set member role" };
  }

  // Use the persistence layer to update via store's getGroupMembers + direct update
  const members = await storeGetGroupMembers(token, groupId);
  const target = members.find((m) => m.accountId === targetAccountId);
  if (!target) return { ok: false, reason: "target is not a group member" };

  // Mutate in place (in-memory persistence) — the member role is already
  // stored by addGroupMember; we update it by modifying the record.
  (target as { role: string }).role = role;

  return { ok: true };
}

export async function setGroupEmblem(
  token: string,
  groupId: string,
  color: string,
  icon: string
): Promise<{ ok: boolean; reason?: string }> {
  const role = await getMemberRole(token, groupId);
  if (!isOfficerOrOwner(role))
    return { ok: false, reason: "must be officer or owner" };

  const e = getOrCreateEnhancements(groupId);
  e.emblemColor = color;
  e.emblemIcon = icon;
  return { ok: true };
}

export async function setBannerText(
  token: string,
  groupId: string,
  text: string
): Promise<{ ok: boolean; reason?: string }> {
  const role = await getMemberRole(token, groupId);
  if (!isOfficerOrOwner(role))
    return { ok: false, reason: "must be officer or owner" };

  const e = getOrCreateEnhancements(groupId);
  e.bannerText = text.slice(0, 200);
  return { ok: true };
}

export async function createAlliance(
  token: string,
  groupId: string,
  targetGroupId: string
): Promise<{ ok: boolean; reason?: string }> {
  const role = await getMemberRole(token, groupId);
  if (!isOfficerOrOwner(role))
    return { ok: false, reason: "must be officer or owner" };

  if (groupId === targetGroupId)
    return { ok: false, reason: "cannot ally with self" };

  const existing = [...allianceProposals.values()].find(
    (p) =>
      (p.fromGroupId === groupId && p.toGroupId === targetGroupId) ||
      (p.fromGroupId === targetGroupId && p.toGroupId === groupId)
  );
  if (existing) return { ok: false, reason: "alliance proposal already exists" };

  const proposal: AllianceProposal = {
    id: randomUUID(),
    fromGroupId: groupId,
    toGroupId: targetGroupId,
    status: "pending",
    createdAt: new Date().toISOString(),
  };
  allianceProposals.set(proposal.id, proposal);

  return { ok: true };
}

export async function acceptAlliance(
  token: string,
  groupId: string,
  fromGroupId: string
): Promise<{ ok: boolean; reason?: string }> {
  const role = await getMemberRole(token, groupId);
  if (!isOfficerOrOwner(role))
    return { ok: false, reason: "must be officer or owner" };

  const proposal = [...allianceProposals.values()].find(
    (p) =>
      p.fromGroupId === fromGroupId &&
      p.toGroupId === groupId &&
      p.status === "pending"
  );
  if (!proposal) return { ok: false, reason: "no pending alliance proposal found" };

  proposal.status = "accepted";

  const e1 = getOrCreateEnhancements(groupId);
  const e2 = getOrCreateEnhancements(fromGroupId);
  if (!e1.alliances.includes(fromGroupId)) e1.alliances.push(fromGroupId);
  if (!e2.alliances.includes(groupId)) e2.alliances.push(groupId);

  return { ok: true };
}

export async function removeAlliance(
  token: string,
  groupId: string,
  targetGroupId: string
): Promise<{ ok: boolean; reason?: string }> {
  const role = await getMemberRole(token, groupId);
  if (!isOfficerOrOwner(role))
    return { ok: false, reason: "must be officer or owner" };

  const e1 = getOrCreateEnhancements(groupId);
  const e2 = getOrCreateEnhancements(targetGroupId);
  e1.alliances = e1.alliances.filter((id) => id !== targetGroupId);
  e2.alliances = e2.alliances.filter((id) => id !== groupId);

  // Remove any accepted proposals between them
  for (const [id, p] of allianceProposals) {
    if (
      (p.fromGroupId === groupId && p.toGroupId === targetGroupId) ||
      (p.fromGroupId === targetGroupId && p.toGroupId === groupId)
    ) {
      allianceProposals.delete(id);
    }
  }

  return { ok: true };
}

export async function listAlliances(groupId: string): Promise<string[]> {
  return getOrCreateEnhancements(groupId).alliances;
}

/**
 * Check whether a session has build permission on a group-owned parcel.
 * Returns true if the parcel is group-owned and the session user is
 * an officer or owner in that group.
 */
export async function hasGroupBuildPermission(
  token: string,
  parcelId: string
): Promise<boolean> {
  const session = getSession(token);
  if (!session) return false;

  for (const [groupId, e] of guildEnhancements) {
    if (e.ownedParcelIds.includes(parcelId)) {
      const members = await storeGetGroupMembers(token, groupId);
      const me = members.find((m) => m.accountId === session.accountId);
      if (me && isOfficerOrOwner(me.role)) return true;
    }
  }

  return false;
}
