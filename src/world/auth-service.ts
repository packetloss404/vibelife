import { randomBytes, randomUUID, scryptSync, timingSafeEqual } from "node:crypto";
import {
  persistence,
  regions,
  sessions,
  avatarsByRegion,
  SESSION_TTL_MS,
  applyEquippedWearables,
  type Account,
  type InventoryItem,
  type Parcel,
  type AvatarAppearance,
  type Session,
  type AvatarState
} from "./_shared-state.js";
import type { AvatarPositionRecord } from "../data/persistence.js";

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
