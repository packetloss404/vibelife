import { randomUUID } from "node:crypto";

// ── Types ──────────────────────────────────────────────────────────────────────

export type BlockType = {
  id: number;
  name: string;
  color: string;
  transparent: boolean;
  hardness: number;
};

export type ChunkData = {
  regionId: string;
  chunkX: number;
  chunkZ: number;
  palette: BlockType[];
  blocks: Uint8Array; // 16 * 64 * 16 = 16384
};

export type VoxelPermission = {
  accountId: string;
  regionId: string;
  canPlace: boolean;
  canBreak: boolean;
  canEditCustomBlocks: boolean;
};

// ── Block palette ──────────────────────────────────────────────────────────────

const blockPalette = new Map<number, BlockType>();

const defaultBlocks: BlockType[] = [
  { id: 0,  name: "air",         color: "#00000000", transparent: true,  hardness: 0   },
  { id: 1,  name: "stone",       color: "#808080",   transparent: false, hardness: 4   },
  { id: 2,  name: "dirt",        color: "#8B4513",   transparent: false, hardness: 1   },
  { id: 3,  name: "grass",       color: "#228B22",   transparent: false, hardness: 1   },
  { id: 4,  name: "wood",        color: "#A0522D",   transparent: false, hardness: 2   },
  { id: 5,  name: "sand",        color: "#F4A460",   transparent: false, hardness: 0.5 },
  { id: 6,  name: "water",       color: "#4169E1",   transparent: true,  hardness: 0   },
  { id: 7,  name: "ore_iron",    color: "#A9A9A9",   transparent: false, hardness: 5   },
  { id: 8,  name: "ore_gold",    color: "#FFD700",   transparent: false, hardness: 5   },
  { id: 9,  name: "ore_crystal", color: "#E0B0FF",   transparent: false, hardness: 6   },
  { id: 10, name: "leaves",      color: "#32CD32",   transparent: true,  hardness: 0.3 },
  { id: 11, name: "glass",       color: "#ADD8E6",   transparent: true,  hardness: 0.2 },
  { id: 12, name: "brick",       color: "#B22222",   transparent: false, hardness: 3   },
];

for (const b of defaultBlocks) {
  blockPalette.set(b.id, b);
}

// ── Chunk storage ──────────────────────────────────────────────────────────────

const CHUNK_WIDTH = 16;
const CHUNK_HEIGHT = 64;
const CHUNK_DEPTH = 16;
const CHUNK_VOLUME = CHUNK_WIDTH * CHUNK_HEIGHT * CHUNK_DEPTH; // 16384

const chunks = new Map<string, ChunkData>();

function chunkKey(regionId: string, chunkX: number, chunkZ: number): string {
  return `${regionId}:${chunkX}:${chunkZ}`;
}

function blockIndex(x: number, y: number, z: number): number {
  return y * 256 + z * 16 + x;
}

// ── Terrain generation ─────────────────────────────────────────────────────────

function generateChunk(regionId: string, chunkX: number, chunkZ: number): ChunkData {
  const blocks = new Uint8Array(CHUNK_VOLUME);

  const waterLevel = 4;

  for (let x = 0; x < CHUNK_WIDTH; x++) {
    for (let z = 0; z < CHUNK_DEPTH; z++) {
      const worldX = chunkX * CHUNK_WIDTH + x;
      const worldZ = chunkZ * CHUNK_DEPTH + z;

      // Simple procedural heightmap using sin/cos waves for hills
      const height = Math.floor(
        10 +
        4 * Math.sin(worldX * 0.05) +
        3 * Math.cos(worldZ * 0.07) +
        2 * Math.sin(worldX * 0.12 + worldZ * 0.08)
      );

      const clampedHeight = Math.min(height, CHUNK_HEIGHT - 1);

      for (let y = 0; y < CHUNK_HEIGHT; y++) {
        const idx = blockIndex(x, y, z);

        if (y < clampedHeight - 3) {
          // Stone below
          blocks[idx] = 1;
        } else if (y < clampedHeight) {
          // Dirt in the middle
          blocks[idx] = 2;
        } else if (y === clampedHeight) {
          // Grass on top
          blocks[idx] = 3;
        } else if (y <= waterLevel && y > clampedHeight) {
          // Water at y <= 4 where there's no terrain
          blocks[idx] = 6;
        } else {
          // Air
          blocks[idx] = 0;
        }
      }
    }
  }

  const palette = Array.from(blockPalette.values());

  const chunk: ChunkData = {
    regionId,
    chunkX,
    chunkZ,
    palette,
    blocks,
  };

  chunks.set(chunkKey(regionId, chunkX, chunkZ), chunk);
  return chunk;
}

// ── RLE compression ────────────────────────────────────────────────────────────

export function compressChunk(chunk: ChunkData): { palette: BlockType[]; rle: number[] } {
  const rle: number[] = [];
  const blocks = chunk.blocks;

  let i = 0;
  while (i < blocks.length) {
    const blockId = blocks[i];
    let count = 1;
    while (i + count < blocks.length && blocks[i + count] === blockId && count < 65535) {
      count++;
    }
    rle.push(blockId, count);
    i += count;
  }

  return { palette: chunk.palette, rle };
}

export function decompressChunk(data: {
  regionId: string;
  chunkX: number;
  chunkZ: number;
  palette: BlockType[];
  rle: number[];
}): ChunkData {
  const blocks = new Uint8Array(CHUNK_VOLUME);
  let offset = 0;

  for (let i = 0; i < data.rle.length; i += 2) {
    const blockId = data.rle[i];
    const count = data.rle[i + 1];
    for (let j = 0; j < count && offset < CHUNK_VOLUME; j++) {
      blocks[offset++] = blockId;
    }
  }

  return {
    regionId: data.regionId,
    chunkX: data.chunkX,
    chunkZ: data.chunkZ,
    palette: data.palette,
    blocks,
  };
}

// ── Core functions ─────────────────────────────────────────────────────────────

export function getBlockTypes(): BlockType[] {
  return Array.from(blockPalette.values());
}

export function getOrGenerateChunk(regionId: string, chunkX: number, chunkZ: number): ChunkData {
  const key = chunkKey(regionId, chunkX, chunkZ);
  const existing = chunks.get(key);
  if (existing) return existing;
  return generateChunk(regionId, chunkX, chunkZ);
}

export function getChunksInRadius(
  regionId: string,
  cx: number,
  cz: number,
  radius: number
): ChunkData[] {
  const result: ChunkData[] = [];
  for (let dx = -radius; dx <= radius; dx++) {
    for (let dz = -radius; dz <= radius; dz++) {
      result.push(getOrGenerateChunk(regionId, cx + dx, cz + dz));
    }
  }
  return result;
}

export function setBlock(
  regionId: string,
  x: number,
  y: number,
  z: number,
  blockTypeId: number
): { chunkX: number; chunkZ: number } {
  const chunkX = Math.floor(x / CHUNK_WIDTH);
  const chunkZ = Math.floor(z / CHUNK_DEPTH);
  const localX = ((x % CHUNK_WIDTH) + CHUNK_WIDTH) % CHUNK_WIDTH;
  const localZ = ((z % CHUNK_DEPTH) + CHUNK_DEPTH) % CHUNK_DEPTH;

  if (y < 0 || y >= CHUNK_HEIGHT) {
    return { chunkX, chunkZ };
  }

  const chunk = getOrGenerateChunk(regionId, chunkX, chunkZ);
  chunk.blocks[blockIndex(localX, y, localZ)] = blockTypeId;

  return { chunkX, chunkZ };
}

export function getBlock(regionId: string, x: number, y: number, z: number): BlockType | undefined {
  const chunkX = Math.floor(x / CHUNK_WIDTH);
  const chunkZ = Math.floor(z / CHUNK_DEPTH);
  const localX = ((x % CHUNK_WIDTH) + CHUNK_WIDTH) % CHUNK_WIDTH;
  const localZ = ((z % CHUNK_DEPTH) + CHUNK_DEPTH) % CHUNK_DEPTH;

  if (y < 0 || y >= CHUNK_HEIGHT) {
    return undefined;
  }

  const chunk = getOrGenerateChunk(regionId, chunkX, chunkZ);
  const blockId = chunk.blocks[blockIndex(localX, y, localZ)];
  return blockPalette.get(blockId);
}

export function registerCustomBlock(
  id: number,
  name: string,
  color: string,
  transparent: boolean,
  hardness: number
): BlockType {
  if (id < 128) {
    throw new Error("Custom block IDs must be >= 128");
  }

  const block: BlockType = { id, name, color, transparent, hardness };
  blockPalette.set(id, block);
  return block;
}
