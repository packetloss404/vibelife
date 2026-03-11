import type { FastifyInstance } from "fastify";
import { getSession } from "../world/store.js";
import { registerCustomBlockType, listCustomBlocks, saveBlueprint, getBlueprint, listBlueprints, deleteBlueprint, placeBlueprint, markBlueprintForSale, listBlueprintsForSale } from "../world/voxel-shop-service.js";

export default async function voxelShopRoutes(app: FastifyInstance) {
  app.post<{
    Body: { token?: string; name?: string; color?: string; transparent?: boolean; hardness?: number; price?: number };
  }>("/api/voxel-shop/custom-block", async (request, reply) => {
    const { token, name, color, transparent, hardness, price } = request.body;

    if (!token || !name || !color) {
      return reply.code(400).send({ error: "token, name, and color are required" });
    }

    try {
      const block = registerCustomBlockType(
        token,
        name,
        color,
        transparent ?? false,
        hardness ?? 1,
        price ?? 0
      );
      return reply.send({ block });
    } catch (err: unknown) {
      return reply.code(403).send({ error: (err as Error).message });
    }
  });

  app.get("/api/voxel-shop/custom-blocks", async () => ({
    blocks: listCustomBlocks()
  }));

  app.post<{
    Body: { token?: string; name?: string; blocks?: Array<{ x: number; y: number; z: number; blockTypeId: number }> };
  }>("/api/voxel-shop/blueprint", async (request, reply) => {
    const { token, name, blocks } = request.body;

    if (!token || !name || !blocks || !Array.isArray(blocks) || blocks.length === 0) {
      return reply.code(400).send({ error: "token, name, and blocks[] are required" });
    }

    try {
      const blueprint = saveBlueprint(token, name, blocks);
      return reply.send({ blueprint });
    } catch (err: unknown) {
      return reply.code(403).send({ error: (err as Error).message });
    }
  });

  app.get<{ Querystring: { accountId?: string } }>("/api/voxel-shop/blueprints", async (request) => ({
    blueprints: listBlueprints(request.query.accountId)
  }));

  app.get<{ Params: { id: string } }>("/api/voxel-shop/blueprints/:id", async (request, reply) => {
    const blueprint = getBlueprint(request.params.id);

    if (!blueprint) {
      return reply.code(404).send({ error: "blueprint not found" });
    }

    return reply.send({ blueprint });
  });

  app.delete<{ Params: { id: string }; Body: { token?: string } }>("/api/voxel-shop/blueprints/:id", async (request, reply) => {
    const token = request.body.token;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    try {
      const deleted = deleteBlueprint(token, request.params.id);
      if (!deleted) {
        return reply.code(404).send({ error: "blueprint not found or not owned" });
      }
      return reply.send({ ok: true });
    } catch (err: unknown) {
      return reply.code(403).send({ error: (err as Error).message });
    }
  });

  app.post<{
    Params: { id: string };
    Body: { token?: string; regionId?: string; x?: number; y?: number; z?: number };
  }>("/api/voxel-shop/blueprints/:id/place", async (request, reply) => {
    const { token, regionId, x, y, z } = request.body;

    if (!token || !regionId || x === undefined || y === undefined || z === undefined) {
      return reply.code(400).send({ error: "token, regionId, x, y, and z are required" });
    }

    const session = getSession(token);

    if (!session || session.regionId !== regionId) {
      return reply.code(403).send({ error: "session is not active in this region" });
    }

    try {
      const placed = placeBlueprint(token, request.params.id, regionId, x, y, z);
      return reply.send({ ok: true, placed });
    } catch (err: unknown) {
      return reply.code(404).send({ error: (err as Error).message });
    }
  });

  app.post<{
    Params: { id: string };
    Body: { token?: string; price?: number };
  }>("/api/voxel-shop/blueprints/:id/sell", async (request, reply) => {
    const { token, price } = request.body;

    if (!token || price === undefined || price < 0) {
      return reply.code(400).send({ error: "token and a non-negative price are required" });
    }

    try {
      markBlueprintForSale(token, request.params.id, price);
      return reply.send({ ok: true });
    } catch (err: unknown) {
      return reply.code(403).send({ error: (err as Error).message });
    }
  });

  app.get("/api/voxel-shop/marketplace", async () => ({
    blueprints: listBlueprintsForSale()
  }));
}
