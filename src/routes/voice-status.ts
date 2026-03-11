/**
 * Voice status REST routes.
 *
 * NOTE: server.ts needs to:
 *   import { registerVoiceStatusRoutes } from "./routes/voice-status.js";
 *   registerVoiceStatusRoutes(app);
 */

import type { FastifyInstance } from "fastify";
import { getSession } from "../world/store.js";
import {
  getSpeakingAvatars,
  setSpeaking,
} from "../world/voice-indicator-service.js";

export function registerVoiceStatusRoutes(app: FastifyInstance): void {
  // GET /api/voice/status?regionId=&token= — list voice participants with speaking state
  app.get<{
    Querystring: { regionId?: string; token?: string };
  }>("/api/voice/status", async (request, reply) => {
    const { regionId, token } = request.query;

    if (!token || !regionId) {
      return reply.code(400).send({ error: "token and regionId are required" });
    }

    const session = getSession(token);

    if (!session) {
      return reply.code(401).send({ error: "invalid session" });
    }

    const speakers = getSpeakingAvatars(regionId);

    return reply.send({
      regionId,
      participants: speakers.map((s) => ({
        accountId: s.accountId,
        avatarId: s.avatarId,
        speaking: s.speaking,
        updatedAt: s.updatedAt,
      })),
    });
  });

  // POST /api/voice/speaking — update speaking state
  app.post<{
    Body: { token?: string; speaking?: boolean };
  }>("/api/voice/speaking", async (request, reply) => {
    const { token, speaking } = request.body;

    if (!token || speaking === undefined) {
      return reply.code(400).send({ error: "token and speaking are required" });
    }

    const session = getSession(token);

    if (!session) {
      return reply.code(401).send({ error: "invalid session" });
    }

    const state = setSpeaking(
      session.accountId,
      session.avatarId,
      session.regionId,
      speaking
    );

    return reply.send({ state });
  });
}
