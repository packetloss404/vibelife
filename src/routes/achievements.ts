import type { FastifyInstance } from "fastify";
import {
  listAllAchievements,
  getPlayerProgress,
  generateDailyChallenges,
  generateWeeklyChallenges,
  getLeaderboard,
  getAvailableTitles,
  setTitle,
  onBlockPlaced,
  onBlockBroken,
  onEnemyDefeated,
  onRegionVisited,
  onFriendAdded,
  onObjectPlaced,
  type Achievement,
} from "../world/achievement-service.js";
import { getSession } from "../world/store.js";

export async function registerAchievementRoutes(app: FastifyInstance) {
  // List all achievements
  app.get("/api/achievements", async () => ({
    achievements: listAllAchievements(),
  }));

  // Get player progress
  app.get<{ Querystring: { token?: string } }>("/api/progress", async (request, reply) => {
    const token = request.query.token;
    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const progress = getPlayerProgress(token);
    if (!progress) {
      return reply.code(403).send({ error: "invalid session" });
    }

    return reply.send({ progress });
  });

  // Get daily/weekly challenges
  app.get<{ Querystring: { token?: string } }>("/api/progress/challenges", async (request, reply) => {
    const token = request.query.token;
    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const session = getSession(token);
    if (!session) {
      return reply.code(403).send({ error: "invalid session" });
    }

    const dailyChallenges = generateDailyChallenges(session.accountId);
    const weeklyChallenges = generateWeeklyChallenges(session.accountId);

    return reply.send({ dailyChallenges, weeklyChallenges });
  });

  // Get leaderboard
  app.get<{ Querystring: { category?: string; limit?: string } }>("/api/leaderboard", async (request) => {
    const category = request.query.category;
    const limit = Number(request.query.limit ?? 10);

    return {
      leaderboard: getLeaderboard(category, Math.max(1, Math.min(50, limit))),
    };
  });

  // Get available titles
  app.get<{ Querystring: { token?: string } }>("/api/titles", async (request, reply) => {
    const token = request.query.token;
    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const session = getSession(token);
    if (!session) {
      return reply.code(403).send({ error: "invalid session" });
    }

    const titles = getAvailableTitles(session.accountId);
    return reply.send({ titles });
  });

  // Set active title
  app.post<{ Body: { token?: string; title?: string } }>("/api/titles/set", async (request, reply) => {
    const { token, title } = request.body;

    if (!token || !title) {
      return reply.code(400).send({ error: "token and title are required" });
    }

    const success = setTitle(token, title);
    if (!success) {
      return reply.code(403).send({ error: "title not available or invalid session" });
    }

    return reply.send({ ok: true, title });
  });

  // ── Spigot bridge: stat increment by accountId ──────────────────────────

  app.post<{ Body: { accountId?: string; stat?: string; regionId?: string } }>("/api/achievements/increment", async (request, reply) => {
    const { accountId, stat, regionId } = request.body;

    if (!accountId || !stat) {
      return reply.code(400).send({ error: "accountId and stat are required" });
    }

    let unlocked: Achievement[] = [];
    switch (stat) {
      case "blocksPlaced": unlocked = onBlockPlaced(accountId); break;
      case "blocksBroken": unlocked = onBlockBroken(accountId); break;
      case "enemiesDefeated": unlocked = onEnemyDefeated(accountId); break;
      case "regionVisited": unlocked = regionId ? onRegionVisited(accountId, regionId) : []; break;
      case "friendsMade": unlocked = onFriendAdded(accountId); break;
      case "objectsPlaced": unlocked = onObjectPlaced(accountId); break;
      default:
        return reply.code(400).send({ error: "unknown stat: " + stat });
    }

    return reply.send({
      unlocked: unlocked.map(a => ({ id: a.id, name: a.name, description: a.description }))
    });
  });
}
