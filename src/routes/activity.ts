import type { FastifyInstance } from "fastify";
import {
  getGlobalFeed,
  getFriendsFeed,
  likeActivity,
  getActivityFeed,
} from "../world/activity-service.js";

export async function registerActivityRoutes(app: FastifyInstance) {
  app.get<{ Querystring: { limit?: string; offset?: string } }>(
    "/api/activity/feed",
    async (request, reply) => {
      const limit = Math.max(1, Math.min(100, Number(request.query.limit ?? 20)));
      const offset = Math.max(0, Number(request.query.offset ?? 0));

      const activities = getGlobalFeed(limit, offset);
      return reply.send({ activities });
    }
  );

  app.get<{ Querystring: { token?: string; limit?: string } }>(
    "/api/activity/friends",
    async (request, reply) => {
      const token = request.query.token;

      if (!token) {
        return reply.code(400).send({ error: "token is required" });
      }

      const limit = Math.max(1, Math.min(100, Number(request.query.limit ?? 20)));
      const activities = await getFriendsFeed(token, limit);
      return reply.send({ activities });
    }
  );

  app.post<{ Params: { id: string }; Body: { token?: string } }>(
    "/api/activity/:id/like",
    async (request, reply) => {
      const { token } = request.body;

      if (!token) {
        return reply.code(400).send({ error: "token is required" });
      }

      const activity = likeActivity(token, request.params.id);

      if (!activity) {
        return reply.code(404).send({ error: "activity not found" });
      }

      return reply.send({ activity });
    }
  );

  app.get<{ Params: { accountId: string }; Querystring: { limit?: string } }>(
    "/api/activity/player/:accountId",
    async (request, reply) => {
      const limit = Math.max(1, Math.min(100, Number(request.query.limit ?? 20)));
      const activities = getActivityFeed(request.params.accountId, limit);
      return reply.send({ activities });
    }
  );
}
