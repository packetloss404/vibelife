import type { FastifyInstance } from "fastify";
import {
  getCurrentSeason,
  getActiveHolidays,
  getSeasonalItems,
  collectSeasonalItem,
  getSeasonalProgress,
  getSeasonalDecorations,
  placeSeasonalDecoration,
  getSeasonalAchievements,
  checkSeasonalAchievements,
  getSeasonalLeaderboard,
  getRegionSeasonalTheme,
  type Season
} from "../world/seasonal-service.js";
import { getSession } from "../world/store.js";

export default async function seasonalRoutes(app: FastifyInstance) {
  // GET /api/seasonal/current — current season + active holidays
  app.get("/api/seasonal/current", async () => {
    return {
      season: getCurrentSeason(),
      holidays: getActiveHolidays()
    };
  });

  // GET /api/seasonal/items?season= — available items
  app.get<{ Querystring: { season?: string } }>("/api/seasonal/items", async (request) => {
    const season = request.query.season as Season | undefined;
    return {
      items: getSeasonalItems(season)
    };
  });

  // POST /api/seasonal/items/:id/collect — collect item
  app.post<{ Params: { id: string }; Body: { token?: string } }>("/api/seasonal/items/:id/collect", async (request, reply) => {
    const token = request.body.token;
    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const result = collectSeasonalItem(token, request.params.id);
    if (!result.ok) {
      return reply.code(403).send({ error: result.reason });
    }

    // Check achievements after collecting
    const session = getSession(token);
    if (session) {
      const newAchievements = checkSeasonalAchievements(session.accountId);
      return reply.send({ ok: true, newAchievements });
    }

    return reply.send({ ok: true, newAchievements: [] });
  });

  // GET /api/seasonal/progress?token= — player progress
  app.get<{ Querystring: { token?: string } }>("/api/seasonal/progress", async (request, reply) => {
    const token = request.query.token;
    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const progress = getSeasonalProgress(token);
    if (!progress) {
      return reply.code(403).send({ error: "invalid session" });
    }

    return reply.send({ progress });
  });

  // GET /api/seasonal/decorations?regionId= — region decorations
  app.get<{ Querystring: { regionId?: string } }>("/api/seasonal/decorations", async (request, reply) => {
    const regionId = request.query.regionId;
    if (!regionId) {
      return reply.code(400).send({ error: "regionId is required" });
    }

    return reply.send({ decorations: getSeasonalDecorations(regionId) });
  });

  // POST /api/seasonal/decorations — place decoration
  app.post<{ Body: { token?: string; regionId?: string; decorationType?: string } }>("/api/seasonal/decorations", async (request, reply) => {
    const { token, regionId, decorationType } = request.body;
    if (!token || !regionId || !decorationType) {
      return reply.code(400).send({ error: "token, regionId, and decorationType are required" });
    }

    const decoration = placeSeasonalDecoration(token, regionId, decorationType);
    if (!decoration) {
      return reply.code(403).send({ error: "failed to place decoration" });
    }

    return reply.send({ decoration });
  });

  // GET /api/seasonal/achievements?season= — seasonal achievements
  app.get<{ Querystring: { season?: string } }>("/api/seasonal/achievements", async (request) => {
    const season = request.query.season as Season | undefined;
    return { achievements: getSeasonalAchievements(season) };
  });

  // GET /api/seasonal/leaderboard?season= — leaderboard
  app.get<{ Querystring: { season?: string } }>("/api/seasonal/leaderboard", async (request) => {
    const season = (request.query.season as Season) || getCurrentSeason();
    return { leaderboard: getSeasonalLeaderboard(season) };
  });

  // GET /api/seasonal/theme/:regionId — region visual theme
  app.get<{ Params: { regionId: string } }>("/api/seasonal/theme/:regionId", async (request) => {
    return { theme: getRegionSeasonalTheme(request.params.regionId) };
  });
}
