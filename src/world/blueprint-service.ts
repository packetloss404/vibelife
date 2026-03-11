import { randomUUID } from "node:crypto";
import {
  persistence,
  getSession,
  getBuildPermission,
  type RegionObject
} from "./_shared-state.js";

export type Blueprint = {
  id: string;
  name: string;
  creatorAccountId: string;
  creatorDisplayName: string;
  objects: Array<{ asset: string; x: number; y: number; z: number; rotationY: number; scale: number }>;
  createdAt: string;
};

const blueprints = new Map<string, Blueprint>();

export async function createBlueprint(token: string, name: string, objectIds: string[]): Promise<Blueprint | undefined> {
  const session = getSession(token);
  if (!session) return undefined;

  const regionObjects = await persistence.listRegionObjects(session.regionId);
  const selected = regionObjects.filter((o) => objectIds.includes(o.id));
  if (selected.length === 0) return undefined;

  let cx = 0, cy = 0, cz = 0;
  for (const obj of selected) {
    cx += obj.x;
    cy += obj.y;
    cz += obj.z;
  }
  cx /= selected.length;
  cy /= selected.length;
  cz /= selected.length;

  const blueprintObjects = selected.map((obj) => ({
    asset: obj.asset,
    x: obj.x - cx,
    y: obj.y - cy,
    z: obj.z - cz,
    rotationY: obj.rotationY,
    scale: obj.scale
  }));

  const blueprint: Blueprint = {
    id: randomUUID(),
    name: name.slice(0, 64) || "Untitled",
    creatorAccountId: session.accountId,
    creatorDisplayName: session.displayName,
    objects: blueprintObjects,
    createdAt: new Date().toISOString()
  };

  blueprints.set(blueprint.id, blueprint);
  return blueprint;
}

export function listBlueprints(token: string): Blueprint[] {
  const session = getSession(token);
  if (!session) return [];
  return [...blueprints.values()].filter((b) => b.creatorAccountId === session.accountId);
}

export function getBlueprint(blueprintId: string): Blueprint | undefined {
  return blueprints.get(blueprintId);
}

export function deleteBlueprint(token: string, blueprintId: string): boolean {
  const session = getSession(token);
  if (!session) return false;
  const blueprint = blueprints.get(blueprintId);
  if (!blueprint || blueprint.creatorAccountId !== session.accountId) return false;
  blueprints.delete(blueprintId);
  return true;
}

export async function placeBlueprint(token: string, blueprintId: string, regionId: string, x: number, z: number): Promise<RegionObject[]> {
  const session = getSession(token);
  if (!session) return [];
  const blueprint = blueprints.get(blueprintId);
  if (!blueprint) return [];

  const created: RegionObject[] = [];
  for (const entry of blueprint.objects) {
    const ox = x + entry.x;
    const oz = z + entry.z;
    const permission = await getBuildPermission(session, ox, oz);
    if (!permission.allowed) continue;

    const obj = await persistence.createRegionObject({
      id: randomUUID(),
      regionId,
      ownerAccountId: session.accountId,
      asset: entry.asset,
      x: ox,
      y: entry.y,
      z: oz,
      rotationY: entry.rotationY,
      scale: entry.scale,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    });
    created.push(obj);
  }
  return created;
}

export async function groupMoveObjects(token: string, objectIds: string[], deltaX: number, deltaY: number, deltaZ: number): Promise<RegionObject[]> {
  const session = getSession(token);
  if (!session) return [];

  const regionObjects = await persistence.listRegionObjects(session.regionId);
  const updated: RegionObject[] = [];

  for (const id of objectIds) {
    const obj = regionObjects.find((o) => o.id === id);
    if (!obj || obj.ownerAccountId !== session.accountId) continue;

    const nx = obj.x + deltaX;
    const ny = obj.y + deltaY;
    const nz = obj.z + deltaZ;
    const permission = await getBuildPermission(session, nx, nz);
    if (!permission.allowed) continue;

    const result = await persistence.updateRegionObject(id, session.accountId, {
      x: nx, y: ny, z: nz,
      rotationY: obj.rotationY,
      scale: obj.scale,
      updatedAt: new Date().toISOString()
    });
    if (result) updated.push(result);
  }
  return updated;
}

export async function groupDeleteObjects(token: string, objectIds: string[]): Promise<string[]> {
  const session = getSession(token);
  if (!session) return [];

  const deleted: string[] = [];
  for (const id of objectIds) {
    const ok = await persistence.deleteRegionObject(id, session.accountId);
    if (ok) deleted.push(id);
  }
  return deleted;
}

export async function duplicateObjects(token: string, regionId: string, objectIds: string[], offsetX: number, offsetZ: number): Promise<RegionObject[]> {
  const session = getSession(token);
  if (!session) return [];

  const regionObjects = await persistence.listRegionObjects(regionId);
  const created: RegionObject[] = [];

  for (const id of objectIds) {
    const obj = regionObjects.find((o) => o.id === id);
    if (!obj) continue;

    const nx = obj.x + offsetX;
    const nz = obj.z + offsetZ;
    const permission = await getBuildPermission(session, nx, nz);
    if (!permission.allowed) continue;

    const newObj = await persistence.createRegionObject({
      id: randomUUID(),
      regionId,
      ownerAccountId: session.accountId,
      asset: obj.asset,
      x: nx, y: obj.y, z: nz,
      rotationY: obj.rotationY,
      scale: obj.scale,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    });
    created.push(newObj);
  }
  return created;
}
