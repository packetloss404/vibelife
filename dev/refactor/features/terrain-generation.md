# Feature: Procedural Terrain Generation

**Sprint**: 1
**Status**: Not Started
**Priority**: Critical — foundation for the entire voxel world

## Summary

Replace the flat ground plane with full procedural voxel world generation. Server generates chunks deterministically from a world seed using layered noise functions. Each chunk is 16x256x16 blocks with biome-appropriate block composition, cave networks, ore veins, and surface decorations.

## Current State

- `src/world/voxel-service.ts` — stores 16x64x16 chunks, basic terrain gen (flat stone + dirt + grass layers)
- `native-client/godot/scripts/world/terrain_manager.gd` — renders a flat green ground plane (TO BE DELETED)
- Chunks loaded via HTTP GET `/api/regions/:regionId/chunks?cx=&cz=&radius=`

## Target State

### Server: `src/world/voxel-service.ts`

#### World Seed
```
Each region has a numeric seed (derived from regionId hash or stored in region config).
All generation is deterministic: same seed + same chunk coords = same terrain.
```

#### Height Map (2D Noise)
```
Base terrain height at (x, z):
  - Continental noise: large-scale (scale=256), determines land vs ocean
  - Erosion noise: medium-scale (scale=64), creates valleys and plateaus
  - Detail noise: small-scale (scale=16), adds bumps and variation

  height = base_height + continental * 40 + erosion * 15 + detail * 5
  base_height = 64 (sea level at y=64 for 256-height chunks)

  Clamp final height to [1, 240]
```

#### Biome Selection (2D Noise)
```
Two noise channels:
  - Temperature noise (scale=512): hot ↔ cold
  - Humidity noise (scale=512): wet ↔ dry

Biome grid:
              Dry          Medium        Wet
  Hot:        Desert       Savanna       Jungle
  Warm:       Plains       Forest        Swamp
  Cold:       Tundra       Taiga         Snowy Taiga
  Freezing:   Ice Plains   Snowy Forest  Frozen Ocean

Special: Mountains (when continental noise > 0.7), Ocean (when continental < -0.3)
```

#### Block Composition by Biome
```
Plains:     grass top, 3 dirt, stone below
Desert:     4 sand, 2 sandstone, stone below
Forest:     grass top, 3 dirt, stone below (more trees)
Tundra:     snow top, 3 dirt, stone below
Swamp:      grass top, 3 dirt, clay patches, stone below
Mountains:  stone all the way up, snow cap above y=180
Ocean:      water above, sand/gravel floor, stone below
Jungle:     grass top, 3 dirt, stone below (dense tall trees)
Taiga:      grass top, 3 dirt, stone (spruce trees)
```

#### Cave Generation (3D Noise)
```
3D simplex noise (scale=32):
  - If noise_value > 0.55: carve air
  - Only between y=5 and y=height-5
  - Creates interconnected tunnels and caverns

Cheese caves (large): 3D noise scale=64, threshold 0.6
Spaghetti caves (narrow): 3D noise scale=16, threshold 0.7
```

#### Ore Distribution
```
For each stone block, check ore noise:
  Coal:     y=5-128,  frequency=1.0%,  vein_size=8-12
  Iron:     y=5-63,   frequency=0.7%,  vein_size=4-8
  Gold:     y=5-31,   frequency=0.3%,  vein_size=4-6
  Diamond:  y=5-15,   frequency=0.1%,  vein_size=2-4
  Crystal:  y=5-15,   frequency=0.08%, vein_size=1-3
  Emerald:  y=5-31,   frequency=0.05%, vein_size=1-2 (mountains only)
  Redstone: y=5-15,   frequency=0.5%,  vein_size=4-8
  Lapis:    y=5-31,   frequency=0.2%,  vein_size=3-6

Vein generation: pick random point in vein_size radius, place ore if currently stone
```

#### Surface Decorations
```
Trees:
  - Oak: trunk 4-6 tall, 5x5 leaf canopy (rounded), plains/forest
  - Birch: trunk 5-7 tall, 3x3 leaves, forest
  - Spruce: trunk 6-9 tall, triangular leaves, taiga
  - Jungle: trunk 8-14 tall, large canopy, jungle (rare giant variant)

Placement: noise-based density per biome (forest=15%, plains=2%, jungle=30%)
Constraint: no tree within 2 blocks of another tree trunk

Flowers: random placement on grass, 1-2% density in plains
Tall grass: 10-20% density on grass blocks in plains/forest
Mushrooms: rare on dirt in dark areas (caves, dense forest floor)
Cactus: desert only, 1-3 tall, requires sand below and air on all 4 sides
Sugar cane: river/ocean edges, on sand/dirt adjacent to water, 1-3 tall
```

#### Water
```
Sea level: y=64
All air blocks below y=64 that are exposed to the surface: fill with water
Lava: y=10 and below, fill exposed air pockets
Rivers: carved channels at sea level using 2D ridged noise
```

#### Bedrock
```
y=0: solid bedrock (unbreakable)
y=1-4: random bedrock patches (50% at y=1, 25% at y=2, 12% at y=3, 6% at y=4)
```

### Server: Chunk Generation API

```typescript
// Generate chunk on first request, cache result
function generateChunk(regionId: string, cx: number, cz: number): VoxelChunkContract {
  const seed = getRegionSeed(regionId)
  const blocks = new Uint8Array(16 * 256 * 16) // 65,536 bytes

  for (let x = 0; x < 16; x++) {
    for (let z = 0; z < 16; z++) {
      const worldX = cx * 16 + x
      const worldZ = cz * 16 + z

      const height = getHeight(seed, worldX, worldZ)
      const biome = getBiome(seed, worldX, worldZ)

      fillColumn(blocks, x, z, height, biome, seed)
      carveCaves(blocks, x, z, seed, cx, cz)
      placeOres(blocks, x, z, seed, cx, cz)
    }
  }

  placeStructures(blocks, seed, cx, cz) // trees, flowers, etc.
  fillWater(blocks) // water below sea level

  return { chunkX: cx, chunkZ: cz, blocks: rleCompress(blocks), palette: [...] }
}
```

### Client Changes

- Delete `terrain_manager.gd` and remove Ground node from main.tscn
- Remove `terrain = TerrainManager.new()` and `terrain.setup_terrain()` from main.gd
- Update voxel_manager.gd to expect 256-height chunks
- Update block index formula for 256 height: `y * 256 + z * 16 + x` (same formula, just y range extends to 255)

## Contracts Changes (`src/contracts.ts`)

```typescript
// Update VoxelChunkContract
type VoxelChunkContract = {
  chunkX: number
  chunkZ: number
  palette: BlockTypeContract[]
  blocks: string // base64 RLE-compressed, now 16*256*16 = 65536 blocks
  biome: string  // NEW: biome identifier for this chunk
}
```

## Testing

- Generate a chunk at (0,0) with a known seed, verify block composition matches expectations
- Verify caves don't break through bedrock
- Verify water fills correctly
- Verify trees don't float or overlap
- Verify ore distribution matches depth ranges
- Performance: chunk generation < 100ms on server

## Dependencies

- Block types must be expanded first (block-types.md) so terrain gen can reference them
- RLE compression must handle 65,536 blocks efficiently
