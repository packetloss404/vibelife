import type { FastifyInstance } from "fastify";
import {
  rateHome,
  favoriteHome,
  getHomeRatings,
  getHomeVisitorCount,
  getFavoriteHomes,
  getFeaturedHomes,
  getShowcaseHomes,
} from "../world/home-rating-service.js";

export async function homeRatingRoutes(app: FastifyInstance) {
  app.post<{ Body: { token?: string; parcelId?: string; rating?: number } }>(
    "/api/homes/rate",
    async (request, reply) => {
      const { token, parcelId, rating } = request.body;

      if (!token || !parcelId || rating === undefined) {
        return reply.code(400).send({ error: "token, parcelId, and rating are required" });
      }

      if (rating < 1 || rating > 5) {
        return reply.code(400).send({ error: "rating must be between 1 and 5" });
      }

      const result = rateHome(token, parcelId, rating);

      if (!result) {
        return reply.code(403).send({ error: "invalid session" });
      }

      return reply.send(result);
    }
  );

  app.post<{ Body: { token?: string; parcelId?: string } }>(
    "/api/homes/favorite",
    async (request, reply) => {
      const { token, parcelId } = request.body;

      if (!token || !parcelId) {
        return reply.code(400).send({ error: "token and parcelId are required" });
      }

      const result = favoriteHome(token, parcelId);

      if (!result) {
        return reply.code(403).send({ error: "invalid session" });
      }

      return reply.send(result);
    }
  );

  app.get<{ Querystring: { limit?: string } }>(
    "/api/homes/featured",
    async (request, reply) => {
      const limit = Number(request.query.limit ?? 10);
      const homes = await getFeaturedHomes(Math.max(1, Math.min(50, limit)));
      return reply.send({ homes });
    }
  );

  app.get<{ Querystring: { token?: string } }>(
    "/api/homes/favorites",
    async (request, reply) => {
      const token = request.query.token;

      if (!token) {
        return reply.code(400).send({ error: "token is required" });
      }

      const parcelIds = getFavoriteHomes(token);
      return reply.send({ parcelIds });
    }
  );

  app.get<{ Params: { parcelId: string } }>(
    "/api/homes/:parcelId/ratings",
    async (request, reply) => {
      const result = getHomeRatings(request.params.parcelId);
      return reply.send(result);
    }
  );

  app.get<{ Params: { parcelId: string } }>(
    "/api/homes/:parcelId/visitors",
    async (request, reply) => {
      const count = getHomeVisitorCount(request.params.parcelId);
      return reply.send({ visitorCount: count });
    }
  );

  app.get(
    "/api/homes/showcase",
    async (_request, reply) => {
      const homes = await getShowcaseHomes();
      return reply.send({ homes });
    }
  );
}
