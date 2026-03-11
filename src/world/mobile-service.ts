// =============================================================================
// Mobile Companion Service — Feature 16
// =============================================================================
// Integration notes (DO NOT modify server.ts or store.ts directly):
//
// server.ts — add these lines:
//   import mobileRoutes from "./routes/mobile.js";
//   await app.register(mobileRoutes);
//
// store.ts — add these exports:
//   export { getSession, listRegions, getRegionPopulation, listFriends,
//     listOfflineMessages, listGroups, getCurrencyBalance,
//     listCurrencyTransactions, listTeleportPoints, getAvatarProfile,
//     listRegionObjects, listParcels, teleportToRegion, sendOfflineMessage,
//     markMessageRead, sendCurrency, equipInventoryItem, listAssets } from "./store.js";
//   (most already exported — only mobile-service imports are needed)
// =============================================================================

import { randomUUID } from "node:crypto";
import {
  getSession,
  listRegions,
  getRegionPopulation,
  listFriends,
  listOfflineMessages,
  listGroups,
  getCurrencyBalance,
  listCurrencyTransactions,
  listTeleportPoints,
  getAvatarProfile,
  listRegionObjects,
  listParcels,
  teleportToRegion,
  sendOfflineMessage,
  markMessageRead,
  sendCurrency,
  equipInventoryItem,
  listAssets,
  type Session,
  type AvatarState,
  type Friend,
  type OfflineMessage,
  type Group,
  type CurrencyTransaction,
  type TeleportPoint,
  type AvatarProfile,
  type RegionObject,
  type Parcel,
  type InventoryItem,
  type RegionSummary,
  type Asset
} from "./store.js";

// ---------------------------------------------------------------------------
// Mobile-specific contract types
// ---------------------------------------------------------------------------

export type MobileDevicePlatform = "ios" | "android" | "unknown";

export type MobileSessionInfo = {
  sessionId: string;
  token: string;
  accountId: string;
  displayName: string;
  regionId: string;
  platform: MobileDevicePlatform;
  pushToken: string | null;
  lastActiveAt: string;
  createdAt: string;
};

export type PushNotificationToken = {
  accountId: string;
  platform: MobileDevicePlatform;
  pushToken: string;
  registeredAt: string;
};

export type NotificationPreferences = {
  accountId: string;
  friendOnline: boolean;
  friendMessage: boolean;
  groupInvite: boolean;
  currencyReceived: boolean;
  regionEvent: boolean;
  systemAlert: boolean;
  quietHoursStart: string | null;  // HH:MM format or null
  quietHoursEnd: string | null;
  updatedAt: string;
};

export type MobileNotification = {
  id: string;
  accountId: string;
  type: "friend_online" | "friend_message" | "group_invite" | "currency_received" | "region_event" | "system";
  title: string;
  body: string;
  data: Record<string, string>;
  read: boolean;
  createdAt: string;
};

export type MobileFeedItem = {
  id: string;
  type: "friend_activity" | "region_update" | "marketplace_listing" | "system_announcement";
  title: string;
  body: string;
  thumbnailUrl: string | null;
  actionUrl: string | null;
  createdAt: string;
};

export type QuickTeleportTarget = {
  id: string;
  name: string;
  regionId: string;
  regionName: string;
  x: number;
  y: number;
  z: number;
  type: "saved" | "friend" | "popular";
};

export type MobileWorldSnapshot = {
  regionId: string;
  regionName: string;
  population: number;
  avatarCount: number;
  objectCount: number;
  parcels: Parcel[];
  friendsInRegion: string[];
};

export type MobileDashboard = {
  displayName: string;
  regionId: string;
  regionName: string;
  onlineFriends: number;
  unreadMessages: number;
  currencyBalance: number;
  notifications: MobileNotification[];
  quickTeleports: QuickTeleportTarget[];
};

export type MobileInventoryItem = {
  id: string;
  name: string;
  slot: string;
  equipped: boolean;
  thumbnailUrl: string | null;
  appearanceKey: string | null;
};

export type MobileMarketplaceListing = {
  id: string;
  name: string;
  description: string;
  assetType: string;
  price: number;
  thumbnailUrl: string | null;
  creatorAccountId: string;
  createdAt: string;
};

// ---------------------------------------------------------------------------
// In-memory stores for mobile-specific data
// ---------------------------------------------------------------------------

const mobileSessions = new Map<string, MobileSessionInfo>();
const pushTokens = new Map<string, PushNotificationToken>();
const notificationPrefs = new Map<string, NotificationPreferences>();
const notifications = new Map<string, MobileNotification[]>();

// ---------------------------------------------------------------------------
// Session management
// ---------------------------------------------------------------------------

export function createMobileSession(
  token: string,
  platform: MobileDevicePlatform = "unknown"
): MobileSessionInfo | undefined {
  const session = getSession(token);
  if (!session) return undefined;

  // Check if there is already a mobile session for this token
  const existing = mobileSessions.get(token);
  if (existing) {
    existing.lastActiveAt = new Date().toISOString();
    existing.platform = platform;
    mobileSessions.set(token, existing);
    return existing;
  }

  const mobileSession: MobileSessionInfo = {
    sessionId: randomUUID(),
    token,
    accountId: session.accountId,
    displayName: session.displayName,
    regionId: session.regionId,
    platform,
    pushToken: pushTokens.get(session.accountId)?.pushToken ?? null,
    lastActiveAt: new Date().toISOString(),
    createdAt: new Date().toISOString()
  };

  mobileSessions.set(token, mobileSession);
  return mobileSession;
}

export function getMobileSession(token: string): MobileSessionInfo | undefined {
  const mobileSession = mobileSessions.get(token);
  if (!mobileSession) return undefined;

  // Ensure the underlying session is still valid
  const session = getSession(token);
  if (!session) {
    mobileSessions.delete(token);
    return undefined;
  }

  // Keep region in sync
  mobileSession.regionId = session.regionId;
  mobileSession.lastActiveAt = new Date().toISOString();
  return mobileSession;
}

export function destroyMobileSession(token: string): boolean {
  return mobileSessions.delete(token);
}

// ---------------------------------------------------------------------------
// Push notification token management
// ---------------------------------------------------------------------------

export function registerPushToken(
  token: string,
  platform: MobileDevicePlatform,
  pushToken: string
): PushNotificationToken | undefined {
  const session = getSession(token);
  if (!session) return undefined;

  const record: PushNotificationToken = {
    accountId: session.accountId,
    platform,
    pushToken,
    registeredAt: new Date().toISOString()
  };

  pushTokens.set(session.accountId, record);

  // Update mobile session if it exists
  const mobileSession = mobileSessions.get(token);
  if (mobileSession) {
    mobileSession.pushToken = pushToken;
  }

  return record;
}

export function unregisterPushToken(token: string): boolean {
  const session = getSession(token);
  if (!session) return false;

  pushTokens.delete(session.accountId);

  const mobileSession = mobileSessions.get(token);
  if (mobileSession) {
    mobileSession.pushToken = null;
  }

  return true;
}

// ---------------------------------------------------------------------------
// Notification preferences
// ---------------------------------------------------------------------------

export function getNotificationPreferences(token: string): NotificationPreferences | undefined {
  const session = getSession(token);
  if (!session) return undefined;

  const existing = notificationPrefs.get(session.accountId);
  if (existing) return existing;

  // Return defaults
  const defaults: NotificationPreferences = {
    accountId: session.accountId,
    friendOnline: true,
    friendMessage: true,
    groupInvite: true,
    currencyReceived: true,
    regionEvent: true,
    systemAlert: true,
    quietHoursStart: null,
    quietHoursEnd: null,
    updatedAt: new Date().toISOString()
  };

  notificationPrefs.set(session.accountId, defaults);
  return defaults;
}

export function updateNotificationPreferences(
  token: string,
  updates: Partial<Omit<NotificationPreferences, "accountId" | "updatedAt">>
): NotificationPreferences | undefined {
  const session = getSession(token);
  if (!session) return undefined;

  const current = getNotificationPreferences(token);
  if (!current) return undefined;

  const updated: NotificationPreferences = {
    ...current,
    ...updates,
    accountId: session.accountId,
    updatedAt: new Date().toISOString()
  };

  notificationPrefs.set(session.accountId, updated);
  return updated;
}

// ---------------------------------------------------------------------------
// Notifications
// ---------------------------------------------------------------------------

export function pushNotification(
  accountId: string,
  type: MobileNotification["type"],
  title: string,
  body: string,
  data: Record<string, string> = {}
): MobileNotification {
  const notification: MobileNotification = {
    id: randomUUID(),
    accountId,
    type,
    title,
    body,
    data,
    read: false,
    createdAt: new Date().toISOString()
  };

  const existing = notifications.get(accountId) ?? [];
  // Keep the last 200 notifications per account
  existing.unshift(notification);
  if (existing.length > 200) existing.length = 200;
  notifications.set(accountId, existing);

  return notification;
}

export function listNotifications(
  token: string,
  limit = 50,
  unreadOnly = false
): MobileNotification[] {
  const session = getSession(token);
  if (!session) return [];

  const all = notifications.get(session.accountId) ?? [];
  const filtered = unreadOnly ? all.filter((n) => !n.read) : all;
  return filtered.slice(0, Math.min(limit, 100));
}

export function markNotificationRead(token: string, notificationId: string): boolean {
  const session = getSession(token);
  if (!session) return false;

  const list = notifications.get(session.accountId);
  if (!list) return false;

  const notification = list.find((n) => n.id === notificationId);
  if (!notification) return false;

  notification.read = true;
  return true;
}

export function markAllNotificationsRead(token: string): number {
  const session = getSession(token);
  if (!session) return 0;

  const list = notifications.get(session.accountId);
  if (!list) return 0;

  let count = 0;
  for (const n of list) {
    if (!n.read) {
      n.read = true;
      count++;
    }
  }
  return count;
}

export function getUnreadNotificationCount(token: string): number {
  const session = getSession(token);
  if (!session) return 0;

  const list = notifications.get(session.accountId) ?? [];
  return list.filter((n) => !n.read).length;
}

// ---------------------------------------------------------------------------
// Mobile-optimized data endpoints
// ---------------------------------------------------------------------------

export async function getMobileDashboard(token: string): Promise<MobileDashboard | undefined> {
  const session = getSession(token);
  if (!session) return undefined;

  const friends = await listFriends(token);
  const messages = await listOfflineMessages(token, 100);
  const balance = await getCurrencyBalance(token);
  const notifs = listNotifications(token, 10);
  const teleportPoints = await listTeleportPoints(token);

  const regions = listRegions();
  const currentRegion = regions.find((r) => r.id === session.regionId);

  // Count online friends by checking region populations
  let onlineFriends = 0;
  const friendAccountIds = new Set(friends.map((f) => f.friendAccountId));
  for (const region of regions) {
    const pop = getRegionPopulation(region.id);
    for (const avatar of pop) {
      if (friendAccountIds.has(avatar.accountId)) {
        onlineFriends++;
      }
    }
  }

  const unreadMessages = messages.filter((m) => !m.read).length;

  // Build quick teleport targets
  const quickTeleports: QuickTeleportTarget[] = [];

  // Add saved teleport points
  for (const point of teleportPoints.slice(0, 5)) {
    const region = regions.find((r) => r.id === point.regionId);
    quickTeleports.push({
      id: point.id,
      name: point.name,
      regionId: point.regionId,
      regionName: region?.name ?? point.regionId,
      x: point.x,
      y: point.y,
      z: point.z,
      type: "saved"
    });
  }

  // Add popular regions (top 3 by population)
  const regionsByPop = regions
    .map((r) => ({ region: r, pop: getRegionPopulation(r.id).length }))
    .sort((a, b) => b.pop - a.pop)
    .slice(0, 3);

  for (const entry of regionsByPop) {
    if (!quickTeleports.some((qt) => qt.regionId === entry.region.id)) {
      quickTeleports.push({
        id: `popular-${entry.region.id}`,
        name: entry.region.name,
        regionId: entry.region.id,
        regionName: entry.region.name,
        x: 0,
        y: 0,
        z: 0,
        type: "popular"
      });
    }
  }

  return {
    displayName: session.displayName,
    regionId: session.regionId,
    regionName: currentRegion?.name ?? session.regionId,
    onlineFriends,
    unreadMessages,
    currencyBalance: balance,
    notifications: notifs,
    quickTeleports
  };
}

export async function getMobileWorldSnapshot(token: string): Promise<MobileWorldSnapshot | undefined> {
  const session = getSession(token);
  if (!session) return undefined;

  const regions = listRegions();
  const currentRegion = regions.find((r) => r.id === session.regionId);
  const population = getRegionPopulation(session.regionId);
  const objects = await listRegionObjects(session.regionId);
  const parcels = await listParcels(session.regionId);
  const friends = await listFriends(token);

  const friendAccountIds = new Set(friends.map((f) => f.friendAccountId));
  const friendsInRegion = population
    .filter((a) => friendAccountIds.has(a.accountId))
    .map((a) => a.displayName);

  return {
    regionId: session.regionId,
    regionName: currentRegion?.name ?? session.regionId,
    population: population.length,
    avatarCount: population.length,
    objectCount: objects.length,
    parcels,
    friendsInRegion
  };
}

export async function getMobileFriendsList(token: string): Promise<{
  friends: Friend[];
  onlineStatuses: Record<string, { online: boolean; regionId: string | null; regionName: string | null }>;
} | undefined> {
  const session = getSession(token);
  if (!session) return undefined;

  const friends = await listFriends(token);
  const regions = listRegions();

  // Build online status map
  const onlineStatuses: Record<string, { online: boolean; regionId: string | null; regionName: string | null }> = {};

  for (const friend of friends) {
    let found = false;
    for (const region of regions) {
      const pop = getRegionPopulation(region.id);
      if (pop.some((a) => a.accountId === friend.friendAccountId)) {
        onlineStatuses[friend.friendAccountId] = {
          online: true,
          regionId: region.id,
          regionName: region.name
        };
        found = true;
        break;
      }
    }
    if (!found) {
      onlineStatuses[friend.friendAccountId] = {
        online: false,
        regionId: null,
        regionName: null
      };
    }
  }

  return { friends, onlineStatuses };
}

export async function getMobileInventory(token: string): Promise<MobileInventoryItem[] | undefined> {
  const session = getSession(token);
  if (!session) return undefined;

  // Use equipInventoryItem's session check pattern - we need to get inventory via a different path
  // We can trigger a no-op equip to get inventory, but that's wasteful.
  // Instead, access the session and return what we know.
  // The inventory is returned at login time and cached client-side.
  // For the mobile endpoint we provide a lightweight refresh.
  // Since we don't have direct inventory access without persistence,
  // we return the equip result which gives us the inventory list.
  const result = await equipInventoryItem(token, "__noop__");
  const items: MobileInventoryItem[] = result.inventory.map((item) => ({
    id: item.id,
    name: item.name,
    slot: item.slot ?? "",
    equipped: item.equipped,
    thumbnailUrl: null,
    appearanceKey: item.appearanceKey ?? null
  }));

  return items;
}

export async function getMobileMarketplace(token: string, limit = 50): Promise<MobileMarketplaceListing[]> {
  const session = getSession(token);
  if (!session) return [];

  const assets = await listAssets(token);

  return assets
    .filter((a) => a.price > 0)
    .slice(0, Math.min(limit, 100))
    .map((asset) => ({
      id: asset.id,
      name: asset.name,
      description: asset.description,
      assetType: asset.assetType,
      price: asset.price,
      thumbnailUrl: asset.thumbnailUrl,
      creatorAccountId: asset.accountId,
      createdAt: asset.createdAt
    }));
}

export async function getMobileRegionList(token: string): Promise<{
  regions: Array<{
    id: string;
    name: string;
    population: number;
    friendsHere: number;
  }>;
} | undefined> {
  const session = getSession(token);
  if (!session) return undefined;

  const friends = await listFriends(token);
  const friendAccountIds = new Set(friends.map((f) => f.friendAccountId));
  const regions = listRegions();

  const result = regions.map((region) => {
    const pop = getRegionPopulation(region.id);
    const friendsHere = pop.filter((a) => friendAccountIds.has(a.accountId)).length;
    return {
      id: region.id,
      name: region.name,
      population: pop.length,
      friendsHere
    };
  });

  return { regions: result };
}

// ---------------------------------------------------------------------------
// Quick actions
// ---------------------------------------------------------------------------

export async function quickTeleport(
  token: string,
  regionId: string,
  x = 0,
  y = 0,
  z = 0
): Promise<{ ok: boolean; regionId?: string; reason?: string }> {
  const result = await teleportToRegion(token, regionId, x, y, z);
  if (!result.ok) {
    return { ok: false, reason: result.reason };
  }

  // Update mobile session
  const mobileSession = mobileSessions.get(token);
  if (mobileSession) {
    mobileSession.regionId = regionId;
    mobileSession.lastActiveAt = new Date().toISOString();
  }

  return { ok: true, regionId };
}

export async function quickMessage(
  token: string,
  toAccountId: string,
  message: string
): Promise<{ ok: boolean; reason?: string }> {
  const sent = await sendOfflineMessage(token, toAccountId, message.slice(0, 1000));
  if (!sent) {
    return { ok: false, reason: "failed to send message" };
  }

  // Generate a notification for the recipient
  const session = getSession(token);
  if (session) {
    pushNotification(
      toAccountId,
      "friend_message",
      `Message from ${session.displayName}`,
      message.slice(0, 100),
      { fromAccountId: session.accountId, fromDisplayName: session.displayName }
    );
  }

  return { ok: true };
}

export async function quickSendCurrency(
  token: string,
  toAccountId: string,
  amount: number,
  description = "mobile gift"
): Promise<{ ok: boolean; balance?: number; reason?: string }> {
  const newBalance = await sendCurrency(token, toAccountId, amount, description);
  if (newBalance === undefined) {
    return { ok: false, reason: "insufficient funds or invalid recipient" };
  }

  // Notify recipient
  const session = getSession(token);
  if (session) {
    pushNotification(
      toAccountId,
      "currency_received",
      `${session.displayName} sent you ${amount} coins`,
      description,
      { fromAccountId: session.accountId, amount: String(amount) }
    );
  }

  return { ok: true, balance: newBalance };
}

// ---------------------------------------------------------------------------
// Activity feed generation
// ---------------------------------------------------------------------------

export async function getMobileFeed(token: string, limit = 30): Promise<MobileFeedItem[]> {
  const session = getSession(token);
  if (!session) return [];

  const feed: MobileFeedItem[] = [];
  const now = new Date();

  // Add friend activity items
  const friends = await listFriends(token);
  const friendAccountIds = new Set(friends.map((f) => f.friendAccountId));
  const regions = listRegions();

  for (const region of regions) {
    const pop = getRegionPopulation(region.id);
    for (const avatar of pop) {
      if (friendAccountIds.has(avatar.accountId)) {
        feed.push({
          id: `friend-online-${avatar.accountId}`,
          type: "friend_activity",
          title: `${avatar.displayName} is online`,
          body: `Currently in ${region.name}`,
          thumbnailUrl: null,
          actionUrl: `/teleport/${region.id}`,
          createdAt: avatar.updatedAt
        });
      }
    }
  }

  // Add recent region activity
  for (const region of regions) {
    const pop = getRegionPopulation(region.id);
    if (pop.length > 0) {
      feed.push({
        id: `region-activity-${region.id}`,
        type: "region_update",
        title: region.name,
        body: `${pop.length} resident${pop.length !== 1 ? "s" : ""} online`,
        thumbnailUrl: null,
        actionUrl: `/teleport/${region.id}`,
        createdAt: now.toISOString()
      });
    }
  }

  // Add marketplace listings
  const assets = await listAssets(token);
  for (const asset of assets.filter((a) => a.price > 0).slice(0, 5)) {
    feed.push({
      id: `market-${asset.id}`,
      type: "marketplace_listing",
      title: asset.name,
      body: `${asset.price} coins - ${asset.description || asset.assetType}`,
      thumbnailUrl: asset.thumbnailUrl,
      actionUrl: `/marketplace/${asset.id}`,
      createdAt: asset.createdAt
    });
  }

  // Sort by date descending
  feed.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
  return feed.slice(0, Math.min(limit, 100));
}

// ---------------------------------------------------------------------------
// Lightweight state sync (for simplified 3D view)
// ---------------------------------------------------------------------------

export type MobileLightweightSync = {
  regionId: string;
  sequence: number;
  avatars: Array<{
    avatarId: string;
    displayName: string;
    x: number;
    y: number;
    z: number;
    isFriend: boolean;
  }>;
  objectCount: number;
  parcelCount: number;
};

export async function getLightweightSync(token: string): Promise<MobileLightweightSync | undefined> {
  const session = getSession(token);
  if (!session) return undefined;

  const friends = await listFriends(token);
  const friendAccountIds = new Set(friends.map((f) => f.friendAccountId));
  const population = getRegionPopulation(session.regionId);
  const objects = await listRegionObjects(session.regionId);
  const parcels = await listParcels(session.regionId);

  return {
    regionId: session.regionId,
    sequence: Date.now(),
    avatars: population.map((a) => ({
      avatarId: a.avatarId,
      displayName: a.displayName,
      x: a.x,
      y: a.y,
      z: a.z,
      isFriend: friendAccountIds.has(a.accountId)
    })),
    objectCount: objects.length,
    parcelCount: parcels.length
  };
}
