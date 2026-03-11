import { FastifyInstance } from "fastify";
import {
  createAsset,
  deleteAsset,
  listAssets
} from "../world/store.js";

export default async function assetRoutes(app: FastifyInstance) {
  app.get<{ Querystring: { token?: string } }>("/api/assets", async (request, reply) => {
    const token = request.query.token;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const assets = await listAssets(token);
    return reply.send({ assets });
  });

  app.post<{ Body: { token?: string; name?: string; description?: string; assetType?: string; url?: string; thumbnailUrl?: string; price?: number } }>("/api/assets", async (request, reply) => {
    const { token, name, description = "", assetType, url, thumbnailUrl = null, price = 0 } = request.body;

    if (!token || !name || !assetType || !url) {
      return reply.code(400).send({ error: "token, name, assetType, and url are required" });
    }

    const asset = await createAsset(token, name, description, assetType, url, thumbnailUrl, price);

    if (!asset) {
      return reply.code(403).send({ error: "failed to create asset" });
    }

    return reply.send({ asset });
  });

  app.delete<{ Body: { token?: string; assetId?: string } }>("/api/assets", async (request, reply) => {
    const { token, assetId } = request.body;

    if (!token || !assetId) {
      return reply.code(400).send({ error: "token and assetId are required" });
    }

    const deleted = await deleteAsset(token, assetId);

    if (!deleted) {
      return reply.code(404).send({ error: "asset not found" });
    }

    return reply.send({ ok: true });
  });
}
