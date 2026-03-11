import type { FastifyInstance } from "fastify";
import {
  setPresenceStatus,
  getPresence,
  getFriendsPresence,
  type PresenceStatus,
} from "../world/presence-service.js";

const VALID_STATUSES: PresenceStatus[] = ["online", "busy", "away", "invisible", "offline"];

export async function registerPresenceRoutes(app: FastifyInstance) {
  app.post<{ Body: { token?: string; status?: string; customMessage?: string } }>(
    "/api/presence/status",
    async (request, reply) => {
      const { token, status, customMessage } = request.body;

      if (!token || !status) {
        return reply.code(400).send({ error: "token and status are required" });
      }

      if (!VALID_STATUSES.includes(status as PresenceStatus)) {
        return reply.code(400).send({ error: "invalid status" });
      }

      const presence = setPresenceStatus(token, status as PresenceStatus, customMessage);

      if (!presence) {
        return reply.code(403).send({ error: "invalid session" });
      }

      return reply.send({ presence });
    }
  );

  app.get<{ Params: { accountId: string } }>(
    "/api/presence/:accountId",
    async (request, reply) => {
      const presence = getPresence(request.params.accountId);

      if (!presence) {
        return reply.send({ presence: null });
      }

      return reply.send({ presence });
    }
  );

  app.get<{ Querystring: { token?: string } }>(
    "/api/presence/friends",
    async (request, reply) => {
      const token = request.query.token;

      if (!token) {
        return reply.code(400).send({ error: "token is required" });
      }

      const presences = await getFriendsPresence(token);
      return reply.send({ presences });
    }
  );
}
