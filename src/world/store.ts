import { randomBytes, randomUUID, scryptSync, timingSafeEqual } from "node:crypto";
import {
  createPersistenceLayer,
  type AccountAuthRecord,
  type AccountRecord,
  type AvatarAppearanceRecord,
  type AvatarPositionRecord,
  type InventoryItemRecord,
  type ParcelRecord,
  type RegionObjectRecord,
  type RegionRecord,
  type TeleportLandingPointRecord,
  type FriendRecord,
  type GroupRecord,
  type GroupMemberRecord,
  type CurrencyTransactionRecord,
  type OfflineMessageRecord,
  type AvatarProfileRecord,
  type BanRecord,
  type RegionNoticeRecord,
  type RegionObjectPermissionRecord,
  type ObjectScriptRecord,
  type AssetRecord
} from "../data/persistence.js";

export type RegionSummary = RegionRecord;

export type Account = AccountRecord;

export type InventoryItem = InventoryItemRecord;
export type AvatarAppearance = AvatarAppearanceRecord;

export type Parcel = ParcelRecord;

export type RegionObject = RegionObjectRecord;

export type TeleportPoint = TeleportLandingPointRecord;
export type Friend = FriendRecord;
export type Group = GroupRecord;
export type GroupMember = GroupMemberRecord;
export type CurrencyTransaction = CurrencyTransactionRecord;
export type OfflineMessage = OfflineMessageRecord;
export type AvatarProfile = AvatarProfileRecord;
export type Ban = BanRecord;
export type RegionNotice = RegionNoticeRecord;
export type ObjectPermissions = RegionObjectPermissionRecord;
export type ObjectScript = ObjectScriptRecord;

export async function listObjectScripts(objectId: string): Promise<ObjectScript[]> {
  return persistence.listObjectScripts(objectId);
}

export async function createObjectScript(token: string, objectId: string, scriptName: string, scriptCode: string): Promise<ObjectScript | undefined> {
  const session = getSession(token);
  if (!session) return undefined;
  const objects = await persistence.listRegionObjects(session.regionId);
  const obj = objects.find((o) => o.id === objectId);
  if (!obj || obj.ownerAccountId !== session.accountId) return undefined;
  return persistence.createObjectScript({ objectId, scriptName, scriptCode, enabled: true });
}

export async function updateObjectScript(token: string, scriptId: string, scriptCode: string, enabled: boolean): Promise<ObjectScript | undefined> {
  const session = getSession(token);
  if (!session) return undefined;
  return persistence.updateObjectScript(scriptId, session.accountId, scriptCode, enabled);
}

export async function deleteObjectScript(token: string, scriptId: string): Promise<boolean> {
  const session = getSession(token);
  if (!session) return false;
  return persistence.deleteObjectScript(scriptId, session.accountId);
}

export type Asset = AssetRecord;

export async function listAssets(token: string): Promise<Asset[]> {
  const session = getSession(token);
  if (!session) return [];
  return persistence.listAssets(session.accountId);
}

export async function createAsset(token: string, name: string, description: string, assetType: string, url: string, thumbnailUrl: string | null, price: number): Promise<Asset | undefined> {
  const session = getSession(token);
  if (!session) return undefined;
  return persistence.createAsset({ accountId: session.accountId, name, description, assetType, url, thumbnailUrl, price });
}

export async function deleteAsset(token: string, assetId: string): Promise<boolean> {
  const session = getSession(token);
  if (!session) return false;
  return persistence.deleteAsset(assetId, session.accountId);
}

export type BuildPermission = {
  allowed: boolean;
  parcel: Parcel | null;
  reason?: string;
};

function applyEquippedWearables(appearance: AvatarAppearance, inventory: InventoryItem[]): AvatarAppearance {
  const outfit = inventory.find((item) => item.slot === "outfit" && item.equipped && item.appearanceKey)?.appearanceKey;
  const accessory = inventory.find((item) => item.slot === "accessory" && item.equipped && item.appearanceKey)?.appearanceKey;

  return {
    ...appearance,
    outfit: outfit ?? appearance.outfit,
    accessory: accessory ?? appearance.accessory
  };
}

export type Session = {
  token: string;
  accountId: string;
  avatarId: string;
  displayName: string;
  regionId: string;
  role: "resident" | "admin";
  expiresAt: number;
};

export type AvatarState = {
  avatarId: string;
  accountId: string;
  displayName: string;
  appearance: AvatarAppearance;
  x: number;
  y: number;
  z: number;
  updatedAt: string;
};

let persistence = await createPersistenceLayer();
let regions: RegionSummary[] = [];
const sessions = new Map<string, Session>();
const avatarsByRegion = new Map<string, Map<string, AvatarState>>();
const SESSION_TTL_MS = 1000 * 60 * 60 * 8;

export async function initializeWorldStore() {
  persistence = await createPersistenceLayer();
  regions = await persistence.listRegions();

  for (const region of regions) {
    if (!avatarsByRegion.has(region.id)) {
      avatarsByRegion.set(region.id, new Map());
    }
  }
}

export function listRegions(): RegionSummary[] {
  return regions;
}

export function getPersistenceMode() {
  return persistence.mode;
}

function getBootstrapAdminDisplayName() {
  return (process.env.ADMIN_DISPLAY_NAME ?? "Admin").trim().toLowerCase();
}

function getBootstrapAdminToken() {
  return (process.env.ADMIN_BOOTSTRAP_TOKEN ?? "").trim();
}

function makePasswordHash(password: string) {
  const salt = randomBytes(16).toString("hex");
  const hash = scryptSync(password, salt, 64).toString("hex");
  return `${salt}:${hash}`;
}

function verifyPassword(password: string, stored: string | null) {
  if (!stored || !stored.includes(":")) {
    return false;
  }

  const [salt, expected] = stored.split(":");
  const actual = scryptSync(password, salt, 64).toString("hex");
  return timingSafeEqual(Buffer.from(actual, "hex"), Buffer.from(expected, "hex"));
}

async function createSessionForAccount(account: Account, displayName: string, regionId?: string): Promise<{
  account: Account;
  inventory: InventoryItem[];
  parcels: Parcel[];
  appearance: AvatarAppearance;
  session: Session;
  avatar: AvatarState;
}> {
  const region = regions.find((entry) => entry.id === regionId) ?? regions[0];
  const inventory = await persistence.getInventory(account.id);
  const appearance = applyEquippedWearables(await persistence.getAvatarAppearance(account.id), inventory);
  const parcels = await persistence.listParcels(region.id);
  const savedPosition = await persistence.getAvatarPosition(account.id, region.id);
  const avatarId = randomUUID();
  const token = randomUUID();
  const spawn: AvatarPositionRecord = savedPosition ?? {
    accountId: account.id,
    regionId: region.id,
    x: Number((Math.random() * 48 - 24).toFixed(2)),
    y: 0,
    z: Number((Math.random() * 48 - 24).toFixed(2)),
    updatedAt: new Date().toISOString()
  };
  const avatar: AvatarState = {
    avatarId,
    accountId: account.id,
    displayName: account.displayName,
    appearance,
    x: spawn.x,
    y: spawn.y,
    z: spawn.z,
    updatedAt: new Date().toISOString()
  };

  const session: Session = {
    token,
    accountId: account.id,
    avatarId,
    displayName: displayName || account.displayName,
    regionId: region.id,
    role: account.role,
    expiresAt: Date.now() + SESSION_TTL_MS
  };

  sessions.set(token, session);
  avatarsByRegion.get(region.id)?.set(avatarId, avatar);
  await persistence.saveAvatarPosition({
    accountId: account.id,
    regionId: region.id,
    x: avatar.x,
    y: avatar.y,
    z: avatar.z,
    updatedAt: avatar.updatedAt
  });

  return { account, inventory, parcels, appearance, session, avatar };
}

export async function createGuestSession(displayName: string, regionId?: string): Promise<{
  account: Account;
  inventory: InventoryItem[];
  parcels: Parcel[];
  appearance: AvatarAppearance;
  session: Session;
  avatar: AvatarState;
}> {
  const { account } = await persistence.getOrCreateGuestAccount(displayName);
  return createSessionForAccount(account, displayName, regionId);
}

export async function registerSession(displayName: string, password: string, regionId?: string, adminBootstrapToken?: string) {
  const wantsAdmin = Boolean(adminBootstrapToken) && adminBootstrapToken === getBootstrapAdminToken() && getBootstrapAdminToken().length > 0;
  const result = await persistence.registerAccount(displayName, makePasswordHash(password), wantsAdmin ? "admin" : "resident");

  if (!result.isNew) {
    return { ok: false as const, reason: "display name already exists" };
  }

  return { ok: true as const, ...(await createSessionForAccount(result.account, displayName, regionId)) };
}

export async function loginSession(displayName: string, password: string, regionId?: string) {
  const account = await persistence.authenticateAccount(displayName);

  if (!account || !verifyPassword(password, account.passwordHash)) {
    return { ok: false as const, reason: "invalid credentials" };
  }

  return { ok: true as const, ...(await createSessionForAccount(account, displayName, regionId)) };
}

export function getSession(token: string): Session | undefined {
  const session = sessions.get(token);

  if (!session) {
    return undefined;
  }

  if (session.expiresAt < Date.now()) {
    sessions.delete(token);
    avatarsByRegion.get(session.regionId)?.delete(session.avatarId);
    return undefined;
  }

  session.expiresAt = Date.now() + SESSION_TTL_MS;
  sessions.set(token, session);
  return session;
}

export function getRegionPopulation(regionId: string): AvatarState[] {
  return [...(avatarsByRegion.get(regionId)?.values() ?? [])];
}

export async function moveAvatar(token: string, x: number, z: number, y = 0): Promise<AvatarState | undefined> {
  const session = getSession(token);

  if (!session) {
    return undefined;
  }

  const region = avatarsByRegion.get(session.regionId);
  const avatar = region?.get(session.avatarId);

  if (!region || !avatar) {
    return undefined;
  }

  const nextState: AvatarState = {
    ...avatar,
    x,
    y,
    z,
    updatedAt: new Date().toISOString()
  };

  region.set(session.avatarId, nextState);
  await persistence.saveAvatarPosition({
    accountId: session.accountId,
    regionId: session.regionId,
    x: nextState.x,
    y: nextState.y,
    z: nextState.z,
    updatedAt: nextState.updatedAt
  });
  return nextState;
}

export async function updateAvatarAppearance(token: string, updates: Omit<AvatarAppearance, "accountId" | "updatedAt">): Promise<AvatarState | undefined> {
  const session = getSession(token);

  if (!session) {
    return undefined;
  }

  const region = avatarsByRegion.get(session.regionId);
  const avatar = region?.get(session.avatarId);

  if (!region || !avatar) {
    return undefined;
  }

  const appearance = await persistence.saveAvatarAppearance({
    accountId: session.accountId,
    ...updates,
    updatedAt: new Date().toISOString()
  });

  const nextState: AvatarState = {
    ...avatar,
    appearance,
    updatedAt: new Date().toISOString()
  };

  region.set(session.avatarId, nextState);
  return nextState;
}

export async function equipInventoryItem(token: string, itemId: string): Promise<{ inventory: InventoryItem[]; avatar?: AvatarState }> {
  const session = getSession(token);

  if (!session) {
    return { inventory: [] };
  }

  const inventory = await persistence.equipInventoryItem(session.accountId, itemId);
  const baseAppearance = await persistence.getAvatarAppearance(session.accountId);
  const appearance = applyEquippedWearables(baseAppearance, inventory);
  await persistence.saveAvatarAppearance({ ...appearance, accountId: session.accountId, updatedAt: new Date().toISOString() });

  const region = avatarsByRegion.get(session.regionId);
  const avatar = region?.get(session.avatarId);

  if (!region || !avatar) {
    return { inventory };
  }

  const nextAvatar: AvatarState = {
    ...avatar,
    appearance,
    updatedAt: new Date().toISOString()
  };

  region.set(session.avatarId, nextAvatar);
  return { inventory, avatar: nextAvatar };
}

export async function listParcels(regionId: string): Promise<Parcel[]> {
  return persistence.listParcels(regionId);
}

function pointInParcel(parcel: Parcel, x: number, z: number) {
  return x >= parcel.minX && x <= parcel.maxX && z >= parcel.minZ && z <= parcel.maxZ;
}

async function getBuildPermission(session: Session, x: number, z: number): Promise<BuildPermission> {
  const parcels = await persistence.listParcels(session.regionId);
  const parcel = parcels.find((entry) => pointInParcel(entry, x, z)) ?? null;

  if (!parcel) {
    return {
      allowed: false,
      parcel: null,
      reason: "builds must be placed inside a parcel"
    };
  }

  if (parcel.tier === "public") {
    return { allowed: true, parcel };
  }

  if (parcel.ownerAccountId === session.accountId) {
    return { allowed: true, parcel };
  }

  if (parcel.collaboratorAccountIds.includes(session.accountId)) {
    return { allowed: true, parcel };
  }

  if (!parcel.ownerAccountId) {
    return {
      allowed: false,
      parcel,
      reason: "claim this parcel before building here"
    };
  }

  return {
    allowed: false,
    parcel,
    reason: `parcel owned by ${parcel.ownerDisplayName ?? "another resident"}`
  };
}

export async function claimParcel(token: string, parcelId: string): Promise<Parcel | undefined> {
  const session = getSession(token);

  if (!session) {
    return undefined;
  }

  return persistence.claimParcel(parcelId, session.accountId);
}

export async function releaseParcel(token: string, parcelId: string): Promise<Parcel | undefined> {
  const session = getSession(token);

  if (!session) {
    return undefined;
  }

  return persistence.releaseParcel(parcelId, session.accountId);
}

function isAdminSession(session: Session | undefined) {
  return session?.role === "admin";
}

export type AuditLog = {
  id: string;
  actorAccountId: string;
  actorDisplayName: string;
  action: string;
  targetType: string;
  targetId: string;
  regionId: string | null;
  details: string;
  createdAt: string;
};

export async function adminAssignParcel(token: string, parcelId: string, ownerAccountId: string | null): Promise<Parcel | undefined> {
  const session = getSession(token);

  if (!isAdminSession(session)) {
    return undefined;
  }

  return persistence.reassignParcel(parcelId, ownerAccountId);
}

export async function addParcelCollaborator(token: string, parcelId: string, collaboratorAccountId: string): Promise<Parcel | undefined> {
  const session = getSession(token);

  if (!session) {
    return undefined;
  }

  const parcel = (await persistence.listParcels(session.regionId)).find((entry) => entry.id === parcelId);

  if (!parcel) {
    return undefined;
  }

  if (parcel.ownerAccountId !== session.accountId && !isAdminSession(session)) {
    return undefined;
  }

  return persistence.addParcelCollaborator(parcelId, parcel.ownerAccountId ?? session.accountId, collaboratorAccountId);
}

export async function removeParcelCollaborator(token: string, parcelId: string, collaboratorAccountId: string): Promise<Parcel | undefined> {
  const session = getSession(token);

  if (!session) {
    return undefined;
  }

  const parcel = (await persistence.listParcels(session.regionId)).find((entry) => entry.id === parcelId);

  if (!parcel) {
    return undefined;
  }

  if (parcel.ownerAccountId !== session.accountId && !isAdminSession(session)) {
    return undefined;
  }

  return persistence.removeParcelCollaborator(parcelId, parcel.ownerAccountId ?? session.accountId, collaboratorAccountId);
}

export async function transferParcel(token: string, parcelId: string, ownerAccountId: string | null): Promise<Parcel | undefined> {
  const session = getSession(token);

  if (!session) {
    return undefined;
  }

  const parcel = (await persistence.listParcels(session.regionId)).find((entry) => entry.id === parcelId);

  if (!parcel) {
    return undefined;
  }

  if (parcel.ownerAccountId !== session.accountId && !isAdminSession(session)) {
    return undefined;
  }

  return persistence.reassignParcel(parcelId, ownerAccountId);
}

export async function adminDeleteRegionObject(token: string, objectId: string): Promise<boolean> {
  const session = getSession(token);

  if (!isAdminSession(session)) {
    return false;
  }

  return persistence.adminDeleteRegionObject(objectId);
}

export async function appendAuditLog(token: string, action: string, targetType: string, targetId: string, details: string, regionId: string | null) {
  const session = getSession(token);

  if (!session) {
    return;
  }

  await persistence.appendAuditLog({
    id: randomUUID(),
    actorAccountId: session.accountId,
    actorDisplayName: session.displayName,
    action,
    targetType,
    targetId,
    regionId,
    details,
    createdAt: new Date().toISOString()
  });
}

export async function listAuditLogs(token: string, limit = 50): Promise<AuditLog[] | undefined> {
  const session = getSession(token);

  if (!isAdminSession(session)) {
    return undefined;
  }

  return persistence.listAuditLogs(limit);
}

export async function listRegionObjects(regionId: string): Promise<RegionObject[]> {
  return persistence.listRegionObjects(regionId);
}

export async function createRegionObject(token: string, input: {
  asset: string;
  x: number;
  y: number;
  z: number;
  rotationY: number;
  scale: number;
}): Promise<{ object?: RegionObject; permission: BuildPermission }> {
  const session = getSession(token);

  if (!session) {
    return {
      permission: {
        allowed: false,
        parcel: null,
        reason: "invalid session"
      }
    };
  }

  const permission = await getBuildPermission(session, input.x, input.z);

  if (!permission.allowed) {
    return { permission };
  }

  return {
    object: await persistence.createRegionObject({
    id: randomUUID(),
    regionId: session.regionId,
    ownerAccountId: session.accountId,
    asset: input.asset,
    x: input.x,
    y: input.y,
    z: input.z,
    rotationY: input.rotationY,
    scale: input.scale,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString()
    }),
    permission
  };
}

export async function updateRegionObject(token: string, objectId: string, updates: {
  x: number;
  y: number;
  z: number;
  rotationY: number;
  scale: number;
}): Promise<{ object?: RegionObject; permission: BuildPermission }> {
  const session = getSession(token);

  if (!session) {
    return {
      permission: {
        allowed: false,
        parcel: null,
        reason: "invalid session"
      }
    };
  }

  const permission = await getBuildPermission(session, updates.x, updates.z);

  if (!permission.allowed) {
    return { permission };
  }

  return {
    object: await persistence.updateRegionObject(objectId, session.accountId, {
      ...updates,
      updatedAt: new Date().toISOString()
    }),
    permission
  };
}

export async function deleteRegionObject(token: string, objectId: string): Promise<boolean> {
  const session = getSession(token);

  if (!session) {
    return false;
  }

  return persistence.deleteRegionObject(objectId, session.accountId);
}

export function removeAvatar(token: string): { regionId: string; avatarId: string } | undefined {
  const session = sessions.get(token);

  if (!session) {
    return undefined;
  }

  sessions.delete(token);
  avatarsByRegion.get(session.regionId)?.delete(session.avatarId);

  return {
    regionId: session.regionId,
    avatarId: session.avatarId
  };
}

export async function teleportToRegion(token: string, targetRegionId: string, x: number, y: number, z: number): Promise<{ ok: boolean; session?: Session; avatar?: AvatarState; reason?: string }> {
  const session = getSession(token);
  if (!session) return { ok: false, reason: "invalid session" };

  const targetRegion = regions.find((r) => r.id === targetRegionId);
  if (!targetRegion) return { ok: false, reason: "region not found" };

  const ban = await persistence.getActiveBan(session.accountId);
  if (ban) return { ok: false, reason: `banned: ${ban.reason}` };

  const oldRegionId = session.regionId;
  avatarsByRegion.get(oldRegionId)?.delete(session.avatarId);

  const newRegionId = targetRegionId;
  if (!avatarsByRegion.has(newRegionId)) {
    avatarsByRegion.set(newRegionId, new Map());
  }

  const savedPosition = await persistence.getAvatarPosition(session.accountId, newRegionId);
  const spawnX = savedPosition?.x ?? x;
  const spawnY = savedPosition?.y ?? y;
  const spawnZ = savedPosition?.z ?? z;

  const avatar: AvatarState = {
    avatarId: session.avatarId,
    accountId: session.accountId,
    displayName: session.displayName,
    appearance: (await persistence.getAvatarAppearance(session.accountId)),
    x: spawnX,
    y: spawnY,
    z: spawnZ,
    updatedAt: new Date().toISOString()
  };

  avatarsByRegion.get(newRegionId)?.set(session.avatarId, avatar);

  const updatedSession: Session = {
    ...session,
    regionId: newRegionId,
    expiresAt: Date.now() + SESSION_TTL_MS
  };
  sessions.set(token, updatedSession);

  await persistence.saveAvatarPosition({
    accountId: session.accountId,
    regionId: newRegionId,
    x: spawnX,
    y: spawnY,
    z: spawnZ,
    updatedAt: new Date().toISOString()
  });

  const profile = await persistence.getAvatarProfile(session.accountId);
  if (profile) {
    await persistence.saveAvatarProfile({
      ...profile,
      worldVisits: profile.worldVisits + 1,
      updatedAt: new Date().toISOString()
    });
  } else {
    await persistence.saveAvatarProfile({
      accountId: session.accountId,
      bio: "",
      imageUrl: null,
      worldVisits: 1,
      totalTime: 0,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    });
  }

  await appendAuditLog(token, "avatar.teleport", "account", session.accountId, `teleported from ${oldRegionId} to ${newRegionId}`, newRegionId);

  return { ok: true, session: updatedSession, avatar };
}

export async function listTeleportPoints(token: string): Promise<TeleportPoint[]> {
  const session = getSession(token);
  if (!session) return [];
  return persistence.listTeleportPoints(session.accountId);
}

export async function createTeleportPoint(token: string, name: string, regionId: string, x: number, y: number, z: number, rotationY: number): Promise<TeleportPoint | undefined> {
  const session = getSession(token);
  if (!session) return undefined;
  return persistence.createTeleportPoint({ accountId: session.accountId, regionId, name, x, y, z, rotationY });
}

export async function deleteTeleportPoint(token: string, pointId: string): Promise<boolean> {
  const session = getSession(token);
  if (!session) return false;
  return persistence.deleteTeleportPoint(pointId, session.accountId);
}

export async function listFriends(token: string): Promise<Friend[]> {
  const session = getSession(token);
  if (!session) return [];
  return persistence.listFriends(session.accountId);
}

export async function addFriend(token: string, friendAccountId: string): Promise<Friend | undefined> {
  const session = getSession(token);
  if (!session) return undefined;
  if (session.accountId === friendAccountId) return undefined;
  const friendAccount = await persistence.authenticateAccount("");
  const accountResult = await persistence.getOrCreateGuestAccount("");
  const friendRecord = [...(await persistence.listFriends(session.accountId))].find((f) => f.friendAccountId === friendAccountId);
  if (friendRecord) return undefined;
  return persistence.addFriend({ accountId: session.accountId, friendAccountId, friendDisplayName: "Friend", status: "pending" });
}

export async function removeFriend(token: string, friendAccountId: string): Promise<boolean> {
  const session = getSession(token);
  if (!session) return false;
  return persistence.removeFriend(session.accountId, friendAccountId);
}

export async function blockAccount(token: string, blockedAccountId: string): Promise<Friend | undefined> {
  const session = getSession(token);
  if (!session) return undefined;
  return persistence.blockAccount(session.accountId, blockedAccountId);
}

export async function unblockAccount(token: string, blockedAccountId: string): Promise<boolean> {
  const session = getSession(token);
  if (!session) return false;
  return persistence.unblockAccount(session.accountId, blockedAccountId);
}

export async function listGroups(token: string): Promise<Group[]> {
  const session = getSession(token);
  if (!session) return [];
  return persistence.listGroups(session.accountId);
}

export async function createGroup(token: string, name: string, description: string): Promise<Group | undefined> {
  const session = getSession(token);
  if (!session) return undefined;
  return persistence.createGroup({ name, description, founderAccountId: session.accountId });
}

export async function getGroupMembers(token: string, groupId: string): Promise<GroupMember[]> {
  const session = getSession(token);
  if (!session) return [];
  return persistence.getGroupMembers(groupId);
}

export async function addGroupMember(token: string, groupId: string, memberAccountId: string, role: "member" | "officer" | "owner"): Promise<boolean> {
  const session = getSession(token);
  if (!session) return false;
  await persistence.addGroupMember({ groupId, accountId: memberAccountId, displayName: "Member", role, joinedAt: new Date().toISOString() });
  return true;
}

export async function removeGroupMember(token: string, groupId: string, memberAccountId: string): Promise<boolean> {
  const session = getSession(token);
  if (!session) return false;
  return persistence.removeGroupMember(groupId, memberAccountId);
}

export async function getCurrencyBalance(token: string): Promise<number> {
  const session = getSession(token);
  if (!session) return 0;
  return persistence.getCurrencyBalance(session.accountId);
}

export async function sendCurrency(token: string, toAccountId: string, amount: number, description: string): Promise<number | undefined> {
  const session = getSession(token);
  if (!session || amount <= 0) return undefined;
  const balance = await persistence.getCurrencyBalance(session.accountId);
  if (balance < amount) return undefined;
  return persistence.addCurrency({ fromAccountId: session.accountId, toAccountId, amount, type: "gift", description });
}

export async function listCurrencyTransactions(token: string, limit: number = 20): Promise<CurrencyTransaction[]> {
  const session = getSession(token);
  if (!session) return [];
  return persistence.listCurrencyTransactions(session.accountId, limit);
}

export async function sendOfflineMessage(token: string, toAccountId: string, message: string): Promise<OfflineMessage | undefined> {
  const session = getSession(token);
  if (!session) return undefined;
  return persistence.sendOfflineMessage({ fromAccountId: session.accountId, fromDisplayName: session.displayName, toAccountId, message, read: false });
}

export async function listOfflineMessages(token: string, limit: number = 50): Promise<OfflineMessage[]> {
  const session = getSession(token);
  if (!session) return [];
  return persistence.listOfflineMessages(session.accountId, limit);
}

export async function markMessageRead(token: string, messageId: string): Promise<boolean> {
  const session = getSession(token);
  if (!session) return false;
  return persistence.markOfflineMessageRead(messageId, session.accountId);
}

export async function getAvatarProfile(token: string): Promise<AvatarProfile | undefined> {
  const session = getSession(token);
  if (!session) return undefined;
  return persistence.getAvatarProfile(session.accountId);
}

export async function saveAvatarProfile(token: string, bio: string, imageUrl: string | null): Promise<AvatarProfile | undefined> {
  const session = getSession(token);
  if (!session) return undefined;
  const existing = await persistence.getAvatarProfile(session.accountId);
  if (existing) {
    return persistence.saveAvatarProfile({ ...existing, bio, imageUrl, updatedAt: new Date().toISOString() });
  }
  return persistence.saveAvatarProfile({ accountId: session.accountId, bio, imageUrl, worldVisits: 0, totalTime: 0, createdAt: new Date().toISOString(), updatedAt: new Date().toISOString() });
}

export async function banAccount(token: string, accountId: string, reason: string, expiresAt: string | null): Promise<Ban | undefined> {
  const session = getSession(token);
  if (!session || session.role !== "admin") return undefined;
  return persistence.banAccount({ accountId, bannedBy: session.accountId, reason, expiresAt });
}

export async function unbanAccount(token: string, accountId: string): Promise<boolean> {
  const session = getSession(token);
  if (!session || session.role !== "admin") return false;
  return persistence.unbanAccount(accountId);
}

export async function getActiveBan(token: string): Promise<Ban | undefined> {
  const session = getSession(token);
  if (!session) return undefined;
  return persistence.getActiveBan(session.accountId);
}

export async function listRegionNotices(token: string): Promise<RegionNotice[]> {
  const session = getSession(token);
  if (!session) return [];
  return persistence.listRegionNotices(session.regionId);
}

export async function createRegionNotice(token: string, message: string, parcelId: string | null = null): Promise<RegionNotice | undefined> {
  const session = getSession(token);
  if (!session) return undefined;
  return persistence.createRegionNotice({ regionId: session.regionId, parcelId, message, createdBy: session.accountId });
}

export async function deleteRegionNotice(token: string, noticeId: string): Promise<boolean> {
  const session = getSession(token);
  if (!session) return false;
  return persistence.deleteRegionNotice(noticeId, session.regionId);
}

export async function getObjectPermissions(objectId: string): Promise<ObjectPermissions | undefined> {
  return persistence.getObjectPermissions(objectId);
}

export async function saveObjectPermissions(token: string, objectId: string, allowCopy: boolean, allowModify: boolean, allowTransfer: boolean): Promise<boolean> {
  const session = getSession(token);
  if (!session) return false;
  const objects = await persistence.listRegionObjects("");
  const obj = objects.find((o) => o.id === objectId);
  if (!obj || obj.ownerAccountId !== session.accountId) return false;
  await persistence.saveObjectPermissions({ objectId, allowCopy, allowModify, allowTransfer });
  return true;
}
