import { randomUUID } from "node:crypto";
import type { ObjectGroupContract } from "../contracts.js";
import {
  persistence,
  getSession,
  getBuildPermission,
  objectGroups,
  type RegionObject,
  type BuildPermission,
  type ObjectPermissions,
  type ObjectScript
} from "./_shared-state.js";

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

export async function getObjectPermissions(objectId: string): Promise<ObjectPermissions | undefined> {
  return persistence.getObjectPermissions(objectId);
}

export async function saveObjectPermissions(token: string, objectId: string, allowCopy: boolean, allowModify: boolean, allowTransfer: boolean): Promise<boolean> {
  const session = getSession(token);
  if (!session) return false;
  const objects = await persistence.listRegionObjects(session.regionId);
  const obj = objects.find((o) => o.id === objectId);
  if (!obj || obj.ownerAccountId !== session.accountId) return false;
  await persistence.saveObjectPermissions({ objectId, allowCopy, allowModify, allowTransfer });
  return true;
}

export async function handleGroupObjects(token: string, objectIds: string[], groupName: string): Promise<ObjectGroupContract | undefined> {
  const session = getSession(token);
  if (!session) return undefined;

  const regionObjects = await persistence.listRegionObjects(session.regionId);
  const ownedIds = objectIds.filter((id) => {
    const obj = regionObjects.find((o) => o.id === id);
    return obj && obj.ownerAccountId === session.accountId;
  });

  if (ownedIds.length === 0) return undefined;

  const group: ObjectGroupContract = {
    id: randomUUID(),
    name: groupName,
    objectIds: ownedIds,
    ownerId: session.accountId
  };

  objectGroups.set(group.id, group);
  return group;
}

export function handleUngroupObjects(token: string, groupId: string): boolean {
  const session = getSession(token);
  if (!session) return false;

  const group = objectGroups.get(groupId);
  if (!group || group.ownerId !== session.accountId) return false;

  objectGroups.delete(groupId);
  return true;
}

export async function handleDuplicateGroup(token: string, groupId: string, offset: { x: number; y: number; z: number }): Promise<RegionObject[] | undefined> {
  const session = getSession(token);
  if (!session) return undefined;

  const group = objectGroups.get(groupId);
  if (!group || group.ownerId !== session.accountId) return undefined;

  const regionObjects = await persistence.listRegionObjects(session.regionId);
  const duplicated: RegionObject[] = [];

  for (const objectId of group.objectIds) {
    const original = regionObjects.find((o) => o.id === objectId);
    if (!original) continue;

    const newObj = await persistence.createRegionObject({
      id: randomUUID(),
      regionId: session.regionId,
      ownerAccountId: session.accountId,
      asset: original.asset,
      x: original.x + offset.x,
      y: original.y + offset.y,
      z: original.z + offset.z,
      rotationY: original.rotationY,
      scale: original.scale,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    });

    duplicated.push(newObj);
  }

  if (duplicated.length > 0) {
    const newGroup: ObjectGroupContract = {
      id: randomUUID(),
      name: group.name + " (copy)",
      objectIds: duplicated.map((o) => o.id),
      ownerId: session.accountId
    };
    objectGroups.set(newGroup.id, newGroup);
  }

  return duplicated;
}

export function snapPositionToGrid(x: number, y: number, z: number, gridSize: number): { x: number; y: number; z: number } {
  return {
    x: Math.round(x / gridSize) * gridSize,
    y: Math.round(y / gridSize) * gridSize,
    z: Math.round(z / gridSize) * gridSize
  };
}

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
