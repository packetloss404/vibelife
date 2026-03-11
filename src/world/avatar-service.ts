import {
  persistence,
  regions,
  sessions,
  avatarsByRegion,
  SESSION_TTL_MS,
  getSession,
  applyEquippedWearables,
  appendAuditLog,
  type AvatarAppearance,
  type AvatarState,
  type Session,
  type InventoryItem,
  type TeleportPoint
} from "./_shared-state.js";

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
