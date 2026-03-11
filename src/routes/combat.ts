import type { FastifyInstance } from "fastify";
import { getSession } from "../world/store.js";
import { getCombatStats, getLeaderboard } from "../world/combat-service.js";
import { getEnemiesInRegion, attackEnemy } from "../world/enemy-service.js";

export default async function combatRoutes(app: FastifyInstance) {
  app.get<{ Querystring: { token?: string } }>("/api/combat/stats", async (request, reply) => {
    const token = request.query.token;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const session = getSession(token);

    if (!session) {
      return reply.code(403).send({ error: "invalid session" });
    }

    const stats = getCombatStats(session.accountId);

    return reply.send({ stats });
  });

  app.post<{
    Body: { token?: string; targetId?: string; attackStyle?: string };
  }>("/api/combat/attack", async (request, reply) => {
    const { token, targetId, attackStyle } = request.body;

    if (!token || !targetId) {
      return reply.code(400).send({ error: "token and targetId are required" });
    }

    const session = getSession(token);

    if (!session) {
      return reply.code(403).send({ error: "invalid session" });
    }

    const result = await attackEnemy(session.accountId, targetId, attackStyle ?? "melee");

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
