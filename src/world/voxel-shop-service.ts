import { randomUUID } from "node:crypto";
import { getSession, type Session } from "./store.js";
import { registerCustomBlock, setBlock, type BlockType } from "./voxel-service.js";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export type CustomBlockRegistration = {
  id: number;
  name: string;
  color: string;
  transparent: boolean;
  hardness: number;
  creatorAccountId: string;
  price: number;
  createdAt: string;
};

export type VoxelBlueprint = {
  id: string;
  name: string;
  creatorAccountId: string;
  creatorDisplayName: string;
  blocks: Array<{ x: number; y: number; z: number; blockTypeId: number }>;
  width: number;
  height: number;
  depth: number;
  createdAt: string;
};

// ---------------------------------------------------------------------------
// In-memory storage
// ---------------------------------------------------------------------------

const customBlocks: Map<number, CustomBlockRegistration> = new Map();
const blueprints: Map<string, VoxelBlueprint> = new Map();

/** Blueprints listed for sale, keyed by blueprint id, value is price. */
const blueprintsForSale: Map<string, number> = new Map();

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function requireSession(token: string): Session {
  const session = getSession(token);
  if (!session) {
    throw new Error("Invalid or expired session");
  }
  return session;
}

function nextCustomBlockId(): number {
  let maxId = 127;
  for (const id of customBlocks.keys()) {
    if (id > maxId) {
      maxId = id;
    }
  }
  return maxId + 1;
}

// ---------------------------------------------------------------------------
// Custom Block functions
// ---------------------------------------------------------------------------

export function registerCustomBlockType(
  token: string,
  name: string,
  color: string,
  transparent: boolean,
  hardness: number,
  price: number,
): CustomBlockRegistration {
  const session = requireSession(token);
  const id = nextCustomBlockId();

  // Register in the core voxel-service palette
  registerCustomBlock(id, name, color, transparent, hardness);

  const registration: CustomBlockRegistration = {
    id,
    name,
    color,
    transparent,
    hardness,
    creatorAccountId: session.accountId,
    price,
    createdAt: new Date().toISOString(),
  };

  customBlocks.set(id, registration);
  return registration;
}

export function listCustomBlocks(): CustomBlockRegistration[] {
  return [...customBlocks.values()];
}

export function getCustomBlock(blockId: number): CustomBlockRegistration | undefined {
  return customBlocks.get(blockId);
}

// ---------------------------------------------------------------------------
// Blueprint functions
// ---------------------------------------------------------------------------

export function saveBlueprint(
  token: string,
  name: string,
  blocks: Array<{ x: number; y: number; z: number; blockTypeId: number }>,
): VoxelBlueprint {
  const session = requireSession(token);

  if (blocks.length === 0) {
    throw new Error("Blueprint must contain at least one block");
  }

  // Calculate bounding box dimensions
  let minX = Infinity;
  let minY = Infinity;
  let minZ = Infinity;
  let maxX = -Infinity;
  let maxY = -Infinity;
  let maxZ = -Infinity;

  for (const block of blocks) {
    if (block.x < minX) minX = block.x;
    if (block.y < minY) minY = block.y;
    if (block.z < minZ) minZ = block.z;
    if (block.x > maxX) maxX = block.x;
    if (block.y > maxY) maxY = block.y;
    if (block.z > maxZ) maxZ = block.z;
  }

  const blueprint: VoxelBlueprint = {
    id: randomUUID(),
    name,
    creatorAccountId: session.accountId,
    creatorDisplayName: session.displayName,
    blocks: blocks.map((b) => ({ ...b })),
    width: maxX - minX + 1,
    height: maxY - minY + 1,
    depth: maxZ - minZ + 1,
    createdAt: new Date().toISOString(),
  };

  blueprints.set(blueprint.id, blueprint);
  return blueprint;
}

export function getBlueprint(blueprintId: string): VoxelBlueprint | undefined {
  return blueprints.get(blueprintId);
}

export function listBlueprints(accountId?: string): VoxelBlueprint[] {
  const all = [...blueprints.values()];
  if (accountId) {
    return all.filter((bp) => bp.creatorAccountId === accountId);
  }
  return all;
}

export function deleteBlueprint(token: string, blueprintId: string): boolean {
  const session = requireSession(token);
  const blueprint = blueprints.get(blueprintId);

  if (!blueprint) {
    throw new Error("Blueprint not found");
  }
  if (blueprint.creatorAccountId !== session.accountId) {
    throw new Error("You can only delete your own blueprints");
  }

  blueprintsForSale.delete(blueprintId);
  return blueprints.delete(blueprintId);
}

export function placeBlueprint(
  token: string,
  blueprintId: string,
  regionId: string,
  baseX: number,
  baseY: number,
  baseZ: number,
): number {
  requireSession(token);
  const blueprint = blueprints.get(blueprintId);

  if (!blueprint) {
    throw new Error("Blueprint not found");
  }

  let placed = 0;
  for (const block of blueprint.blocks) {
    setBlock(regionId, baseX + block.x, baseY + block.y, baseZ + block.z, block.blockTypeId);
    placed++;
  }

  return placed;
}

// ---------------------------------------------------------------------------
// Marketplace integration helpers
// ---------------------------------------------------------------------------

export function listBlueprintsForSale(): Array<VoxelBlueprint & { price: number }> {
  const results: Array<VoxelBlueprint & { price: number }> = [];
  for (const [id, price] of blueprintsForSale) {
    const blueprint = blueprints.get(id);
    if (blueprint) {
      results.push({ ...blueprint, price });
    }
  }
  return results;
}

export function markBlueprintForSale(
  token: string,
  blueprintId: string,
  price: number,
): void {
  const session = requireSession(token);
  const blueprint = blueprints.get(blueprintId);

  if (!blueprint) {
    throw new Error("Blueprint not found");
  }
  if (blueprint.creatorAccountId !== session.accountId) {
    throw new Error("You can only list your own blueprints for sale");
  }
  if (price < 0) {
    throw new Error("Price must be non-negative");
  }

  blueprintsForSale.set(blueprintId, price);
}
