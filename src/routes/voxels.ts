import type { FastifyInstance } from "fastify";
import { getSession } from "../world/store.js";
import { getBlockTypes, getChunksInRadius, setBlock, getBlock, compressChunk, getOrGenerateChunk } from "../world/voxel-service.js";
import { getVoxelPermission } from "../world/_shared-state.js";

export default async function voxelRoutes(app: FastifyInstance) {
  app.get("/api/voxels/block-types", async () => ({
    blockTypes: getBlockTypes()
  }));

  app.get<{
    Params: { regionId: string };
    Querystring: { token?: string; cx?: string; cz?: string; radius?: string };
  }>("/api/regions/:regionId/chunks", async (request, reply) => {
    const { token, cx, cz, radius: radiusStr } = request.query;

    if (!token || cx === undefined || cz === undefined) {
      return reply.code(400).send({ error: "token, cx, and cz are required" });
    }

    const session = getSession(token);

    if (!session || session.regionId !== request.params.regionId) {
      return reply.code(403).send({ error: "session is not active in this region" });
    }

    const radius = Math.max(1, Math.min(4, Number(radiusStr ?? 2)));
    const rawChunks = getChunksInRadius(request.params.regionId, Number(cx), Number(cz), radius);

    const chunks = rawChunks.map((chunk) => {
      const compressed = compressChunk(chunk);
      return {
        chunkX: chunk.chunkX,
        chunkZ: chunk.chunkZ,
        palette: compressed.palette,
        blocks: JSON.stringify(compressed.rle)
      };
    });

    return reply.send({ chunks });
  });

  app.post<{
    Body: { token?: string; regionId?: string; x?: number; y?: number; z?: number; blockTypeId?: number };
  }>("/api/voxels/block", async (request, reply) => {
    const { token, regionId, x, y, z, blockTypeId } = request.body;

    if (!token || !regionId || x === undefined || y === undefined || z === undefined || blockTypeId === undefined) {
      return reply.code(400).send({ error: "token, regionId, x, y, z, and blockTypeId are required" });
    }

    const session = getSession(token);
    if (!session || session.regionId !== regionId) {
      return reply.code(403).send({ error: "invalid session for this region" });
    }

    const permission = await getVoxelPermission(session, x, z);

    if (!permission.allowed) {
      return reply.code(403).send({ error: permission.reason ?? "no permission to place blocks" });
    }

    const result = setBlock(regionId, x, y, z, blockTypeId);

    return reply.send({ ok: true, chunkX: result.chunkX, chunkZ: result.chunkZ });
  });

  app.delete<{
    Body: { token?: string; regionId?: string; x?: number; y?: number; z?: number };
  }>("/api/voxels/block", async (request, reply) => {
    const { token, regionId, x, y, z } = request.body;

    if (!token || !regionId || x === undefined || y === undefined || z === undefined) {
      return reply.code(400).send({ error: "token, regionId, x, y, and z are required" });
    }

    const session = getSession(token);
    if (!session || session.regionId !== regionId) {
      return reply.code(403).send({ error: "invalid session for this region" });
    }

    const permission = await getVoxelPermission(session, x, z);

    if (!permission.allowed) {
      return reply.code(403).send({ error: permission.reason ?? "no permission to remove blocks" });
    }

    setBlock(regionId, x, y, z, 0);

    return reply.send({ ok: true });
  });

  app.post<{
    Body: { token?: string; regionId?: string; blocks?: Array<{ x: number; y: number; z: number; blockTypeId: number }> };
  }>("/api/voxels/bulk", async (request, reply) => {
    const { token, regionId, blocks } = request.body;

    if (!token || !regionId || !blocks || !Array.isArray(blocks) || blocks.length === 0) {
      return reply.code(400).send({ error: "token, regionId, and blocks[] are required" });
    }

    if (blocks.length > 100) {
      return reply.code(400).send({ error: "maximum 100 blocks per request" });
    }

    const session = getSession(token);
    if (!session || session.regionId !== regionId) {
      return reply.code(403).send({ error: "invalid session for this region" });
    }

    let placed = 0;

    for (const block of blocks) {
      const permission = await getVoxelPermission(session, block.x, block.z);

      if (permission.allowed) {
        setBlock(regionId, block.x, block.y, block.z, block.blockTypeId);
        placed++;
      }
    }

    return reply.send({ ok: true, placed });
  });
}
