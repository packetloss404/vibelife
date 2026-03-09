import { randomUUID } from "node:crypto";
import {
  createPersistenceLayer,
  type AccountRecord,
  type AvatarPositionRecord,
  type InventoryItemRecord,
  type ParcelRecord,
  type RegionObjectRecord,
  type RegionRecord
} from "../data/persistence.js";

export type RegionSummary = RegionRecord;

export type Account = AccountRecord;

export type InventoryItem = InventoryItemRecord;

export type Parcel = ParcelRecord;

export type RegionObject = RegionObjectRecord;

export type Session = {
  token: string;
  accountId: string;
  avatarId: string;
  displayName: string;
  regionId: string;
};

export type AvatarState = {
  avatarId: string;
  accountId: string;
  displayName: string;
  x: number;
  y: number;
  z: number;
  updatedAt: string;
};

let persistence = await createPersistenceLayer();
let regions: RegionSummary[] = [];
const sessions = new Map<string, Session>();
const avatarsByRegion = new Map<string, Map<string, AvatarState>>();

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

export async function createGuestSession(displayName: string, regionId?: string): Promise<{
  account: Account;
  inventory: InventoryItem[];
  parcels: Parcel[];
  session: Session;
  avatar: AvatarState;
}> {
  const region = regions.find((entry) => entry.id === regionId) ?? regions[0];
  const { account } = await persistence.getOrCreateGuestAccount(displayName);
  const inventory = await persistence.getInventory(account.id);
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
    displayName,
    x: spawn.x,
    y: spawn.y,
    z: spawn.z,
    updatedAt: new Date().toISOString()
  };

  const session: Session = {
    token,
    accountId: account.id,
    avatarId,
    displayName,
    regionId: region.id
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

  return { account, inventory, parcels, session, avatar };
}

export function getSession(token: string): Session | undefined {
  return sessions.get(token);
}

export function getRegionPopulation(regionId: string): AvatarState[] {
  return [...(avatarsByRegion.get(regionId)?.values() ?? [])];
}

export async function moveAvatar(token: string, x: number, z: number, y = 0): Promise<AvatarState | undefined> {
  const session = sessions.get(token);

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

export async function listParcels(regionId: string): Promise<Parcel[]> {
  return persistence.listParcels(regionId);
}

export async function claimParcel(token: string, parcelId: string): Promise<Parcel | undefined> {
  const session = sessions.get(token);

  if (!session) {
    return undefined;
  }

  return persistence.claimParcel(parcelId, session.accountId);
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
}): Promise<RegionObject | undefined> {
  const session = sessions.get(token);

  if (!session) {
    return undefined;
  }

  return persistence.createRegionObject({
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
  });
}

export async function updateRegionObject(token: string, objectId: string, updates: {
  x: number;
  y: number;
  z: number;
  rotationY: number;
  scale: number;
}): Promise<RegionObject | undefined> {
  const session = sessions.get(token);

  if (!session) {
    return undefined;
  }

  return persistence.updateRegionObject(objectId, session.accountId, {
    ...updates,
    updatedAt: new Date().toISOString()
  });
}

export async function deleteRegionObject(token: string, objectId: string): Promise<boolean> {
  const session = sessions.get(token);

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
