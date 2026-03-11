import type { FastifyInstance } from "fastify";
import { requireAuth } from "../middleware/auth.js";
import { getCombatStats, getLeaderboard } from "../world/combat-service.js";
import { getEnemiesInRegion, attackEnemy } from "../world/enemy-service.js";

export default async function combatRoutes(app: FastifyInstance) {
  app.get<{ Querystring: { token?: string } }>("/api/combat/stats", { preHandler: requireAuth }, async (request, reply) => {
    const session = request.session;

    if (!session) {
      return reply.code(401).send({ error: "invalid session" });
    }

    const stats = getCombatStats(session.accountId);

    return reply.send({ stats });
  });

  app.post<{
    Body: { token?: string; targetId?: string; attackStyle?: string };
  }>("/api/combat/attack", { preHandler: requireAuth }, async (request, reply) => {
    const { targetId, attackStyle } = request.body;
    const token = request.authToken;

    if (!targetId) {
      return reply.code(400).send({ error: "targetId is required" });
    }

    if (!token) {
      return reply.code(401).send({ error: "invalid session" });
    }

    const result = await attackEnemy(token, targetId, attackStyle ?? "melee");

    return reply.send(result);
  });

  app.get<{ Querystring: { regionId?: string } }>("/api/combat/enemies", async (request, reply) => {
    const regionId = request.query.regionId;

    if (!regionId) {
      return reply.code(400).send({ error: "regionId is required" });
    }

    const enemies = getEnemiesInRegion(regionId);

    return reply.send({ enemies });
  });

  app.get<{ Querystring: { limit?: string } }>("/api/combat/leaderboard", async (request, reply) => {
    const limit = Math.max(1, Math.min(100, Number(request.query.limit ?? 10)));
    const leaderboard = getLeaderboard(limit);

    return reply.send({ leaderboard });
  });
}
