import { getSession, listFriends, type Session } from "./store.js";

export type PresenceStatus = "online" | "busy" | "away" | "invisible" | "offline";

export type PlayerPresence = {
  accountId: string;
  displayName: string;
  status: PresenceStatus;
  customMessage: string;
  regionId: string | null;
  lastActivity: string;
};

const presenceMap = new Map<string, PlayerPresence>();

const AWAY_TIMEOUT_MS = 10 * 60 * 1000; // 10 minutes

export function setPresenceOnLogin(accountId: string, displayName: string, regionId: string): void {
  presenceMap.set(accountId, {
    accountId,
    displayName,
    status: "online",
    customMessage: "",
    regionId,
    lastActivity: new Date().toISOString(),
  });
}

export function setPresenceOnDisconnect(accountId: string): void {
  const existing = presenceMap.get(accountId);
  if (existing) {
    existing.status = "offline";
    existing.regionId = null;
    existing.lastActivity = new Date().toISOString();
  }
}

export function setPresenceStatus(token: string, status: PresenceStatus, customMessage?: string): PlayerPresence | undefined {
  const session = getSession(token);
  if (!session) return undefined;

  const existing = presenceMap.get(session.accountId);
  if (!existing) return undefined;

  existing.status = status;
  if (customMessage !== undefined) {
    existing.customMessage = customMessage;
  }
  existing.lastActivity = new Date().toISOString();
  return existing;
}

export function getPresence(accountId: string): PlayerPresence | undefined {
  const entry = presenceMap.get(accountId);
  if (!entry) return undefined;
  // If invisible, report as offline to non-self queries
  if (entry.status === "invisible") {
    return { ...entry, status: "offline", regionId: null };
  }
  return entry;
}

export function getPresenceRaw(accountId: string): PlayerPresence | undefined {
  return presenceMap.get(accountId);
}

export async function getFriendsPresence(token: string): Promise<PlayerPresence[]> {
  const session = getSession(token);
  if (!session) return [];

  const friends = await listFriends(token);
  const result: PlayerPresence[] = [];

  for (const friend of friends) {
    if (friend.status !== "accepted") continue;
    const presence = getPresence(friend.friendAccountId);
    if (presence) {
      result.push(presence);
    }
  }

  return result;
}

export function updateLastActivity(accountId: string): void {
  const existing = presenceMap.get(accountId);
  if (existing) {
    existing.lastActivity = new Date().toISOString();
    // If they were auto-away, bring them back online
    if (existing.status === "away") {
      existing.status = "online";
    }
  }
}

export function updatePresenceRegion(accountId: string, regionId: string): void {
  const existing = presenceMap.get(accountId);
  if (existing) {
    existing.regionId = regionId;
    existing.lastActivity = new Date().toISOString();
  }
}

export function autoDetectAway(accountId: string): void {
  const existing = presenceMap.get(accountId);
  if (!existing || existing.status !== "online") return;

  const lastActivity = new Date(existing.lastActivity).getTime();
  if (Date.now() - lastActivity > AWAY_TIMEOUT_MS) {
    existing.status = "away";
  }
}

// Run auto-away detection periodically for all online players
setInterval(() => {
  for (const [accountId] of presenceMap) {
    autoDetectAway(accountId);
  }
}, 60_000); // check every minute
