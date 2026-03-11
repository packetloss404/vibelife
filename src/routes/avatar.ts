import { FastifyInstance } from "fastify";
import {
  appendAuditLog,
  createTeleportPoint,
  deleteTeleportPoint,
  getSession,
  listTeleportPoints,
  teleportToRegion,
  updateAvatarAppearance
} from "../world/store.js";
import { broadcastRegion, nextRegionSequence } from "../world/region.js";

export default async function avatarRoutes(app: FastifyInstance) {
  app.patch<{
    Body: {
      token?: string;
      bodyColor?: string;
      accentColor?: string;
      headColor?: string;
      hairColor?: string;
      outfit?: string;
      accessory?: string;
    };
  }>("/api/avatar/appearance", async (request, reply) => {
    const { token, bodyColor, accentColor, headColor, hairColor, outfit, accessory } = request.body;

    if (!token || !bodyColor || !accentColor || !headColor || !hairColor || !outfit || !accessory) {
      return reply.code(400).send({ error: "complete avatar appearance payload is required" });
    }

    const avatar = await updateAvatarAppearance(token, { bodyColor, accentColor, headColor, hairColor, outfit, accessory });

    if (!avatar) {
      return reply.code(404).send({ error: "avatar session not found" });
    }

    const session = getSession(token);
    if (session) {
      broadcastRegion(session.regionId, { type: "avatar:updated", sequence: nextRegionSequence(session.regionId), avatar });
    }

    return reply.send({ avatar });
  });

  app.post<{ Body: { token?: string; targetRegionId?: string; x?: number; y?: number; z?: number } }>("/api/avatar/teleport", async (request, reply) => {
    const { token, targetRegionId, x = 0, y = 0, z = 0 } = request.body;

    if (!token || !targetRegionId) {
      return reply.code(400).send({ error: "token and targetRegionId are required" });
    }

    const result = await teleportToRegion(token, targetRegionId, x, y, z);

    if (!result.ok) {
      return reply.code(403).send({ error: result.reason });
    }

    await appendAuditLog(token, "avatar.teleport", "account", result.session?.accountId ?? "", `teleported to ${targetRegionId}`, targetRegionId);

    return reply.send({
      session: result.session,
      avatar: result.avatar,
      regionId: targetRegionId
    });
  });

  app.get<{ Querystring: { token?: string } }>("/api/avatar/teleport-points", async (request, reply) => {
    const token = request.query.token;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const points = await listTeleportPoints(token);
    return reply.send({ points });
  });

  app.post<{ Body: { token?: string; name?: string; regionId?: string; x?: number; y?: number; z?: number; rotationY?: number } }>("/api/avatar/teleport-points", async (request, reply) => {
    const { token, name, regionId, x, y, z, rotationY = 0 } = request.body;

    if (!token || !name || !regionId || x === undefined || y === undefined || z === undefined) {
      return reply.code(400).send({ error: "token, name, regionId, x, y, z are required" });
    }

    const point = await createTeleportPoint(token, name, regionId, x, y, z, rotationY);

    if (!point) {
      return reply.code(403).send({ error: "failed to create teleport point" });
    }

    return reply.send({ point });
  });

  app.delete<{ Body: { token?: string; pointId?: string } }>("/api/avatar/teleport-points", async (request, reply) => {
    const { token, pointId } = request.body;

    if (!token || !pointId) {
      return reply.code(400).send({ error: "token and pointId are required" });
    }

    const deleted = await deleteTeleportPoint(token, pointId);

    if (!deleted) {
      return reply.code(404).send({ error: "teleport point not found" });
    }

    return reply.send({ ok: true });
  });
}
