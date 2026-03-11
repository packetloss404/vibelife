import { randomUUID } from "node:crypto";
import { getSession, listFriends } from "./store.js";

export type ActivityEntry = {
  id: string;
  accountId: string;
  displayName: string;
  action: string;
  details: string;
  regionId?: string;
  createdAt: string;
  likes: string[];
};

const MAX_FEED_SIZE = 1000;
const activityFeed: ActivityEntry[] = [];

export function postActivity(accountId: string, displayName: string, action: string, details: string, regionId?: string): ActivityEntry {
  const entry: ActivityEntry = {
    id: randomUUID(),
    accountId,
    displayName,
    action,
    details,
    regionId,
    createdAt: new Date().toISOString(),
    likes: [],
  };

  activityFeed.unshift(entry);

  // Cap at max size (FIFO)
  if (activityFeed.length > MAX_FEED_SIZE) {
    activityFeed.length = MAX_FEED_SIZE;
  }

  return entry;
}

export function getGlobalFeed(limit: number = 20, offset: number = 0): ActivityEntry[] {
  return activityFeed.slice(offset, offset + limit);
}

export async function getFriendsFeed(token: string, limit: number = 20): Promise<ActivityEntry[]> {
  const session = getSession(token);
  if (!session) return [];

  const friends = await listFriends(token);
  const friendIds = new Set(
    friends
      .filter((f) => f.status === "accepted")
      .map((f) => f.friendAccountId)
  );
  // Include own activities too
  friendIds.add(session.accountId);

  const result: ActivityEntry[] = [];
  for (const entry of activityFeed) {
    if (friendIds.has(entry.accountId)) {
      result.push(entry);
      if (result.length >= limit) break;
    }
  }

  return result;
}

export function likeActivity(token: string, activityId: string): ActivityEntry | undefined {
  const session = getSession(token);
  if (!session) return undefined;

  const entry = activityFeed.find((e) => e.id === activityId);
  if (!entry) return undefined;

  const index = entry.likes.indexOf(session.accountId);
  if (index >= 0) {
    // Toggle off
    entry.likes.splice(index, 1);
  } else {
    entry.likes.push(session.accountId);
  }

  return entry;
}

export function getActivityFeed(accountId: string, limit: number = 20): ActivityEntry[] {
  const result: ActivityEntry[] = [];
  for (const entry of activityFeed) {
    if (entry.accountId === accountId) {
      result.push(entry);
      if (result.length >= limit) break;
    }
  }
  return result;
}
