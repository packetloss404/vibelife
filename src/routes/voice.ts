import type { FastifyInstance } from "fastify";
import {
  joinVoiceChannel,
  leaveVoiceChannel,
  setVoiceMuted,
  setVoiceDeafened,
  getVoiceParticipants,
} from "../world/voice-service.js";
import { getSession } from "../world/store.js";

/**
 * Voice chat REST routes.
 *
 * Register with: app.register(voiceRoutes);
 *
 * NOTE: server.ts must register this plugin, e.g.
 *   import voiceRoutes from "./routes/voice.js";
 *   await app.register(voiceRoutes);
 */
export default async function voiceRoutes(app: FastifyInstance) {
  // -----------------------------------------------------------------------
  // POST /api/voice/join — join the voice channel for a region
  // -----------------------------------------------------------------------
  app.post<{
    Body: { token?: string; regionId?: string; parcelId?: string };
  }>("/api/voice/join", async (request, reply) => {
    const { token, regionId, parcelId = null } = request.body ?? {};

    if (!token || !regionId) {
      return reply.code(400).send({ error: "token and regionId are required" });
    }

    const session = getSession(token);

    if (!session) {
      return reply.code(401).send({ error: "invalid session" });
    }

    const result = joinVoiceChannel(token, regionId, parcelId ?? null);

    if (!result) {
      return reply.code(409).send({ error: "unable to join voice channel (full or invalid)" });
    }

    return reply.send({
      channelId: result.channel.id,
      regionId: result.channel.regionId,
      iceServers: result.iceServers,
      participant: result.participant,
      participants: [...result.channel.participants.values()],
    });
  });

  // -----------------------------------------------------------------------
  // POST /api/voice/leave — leave the voice channel
  // -----------------------------------------------------------------------
  app.post<{
    Body: { token?: string; regionId?: string };
  }>("/api/voice/leave", async (request, reply) => {
    const { token, regionId } = request.body ?? {};

    if (!token || !regionId) {
      return reply.code(400).send({ error: "token and regionId are required" });
    }

    const result = leaveVoiceChannel(token, regionId);

    if (!result) {
      return reply.code(404).send({ error: "not in voice channel" });
    }

    return reply.send({ ok: true, accountId: result.accountId, regionId: result.regionId });
  });

  // -----------------------------------------------------------------------
  // POST /api/voice/mute — toggle mute
  // -----------------------------------------------------------------------
  app.post<{
    Body: { token?: string; regionId?: string; muted?: boolean };
  }>("/api/voice/mute", async (request, reply) => {
    const { token, regionId, muted } = request.body ?? {};

    if (!token || !regionId || muted === undefined) {
      return reply.code(400).send({ error: "token, regionId, and muted are required" });
    }

    const participant = setVoiceMuted(token, regionId, muted);

    if (!participant) {
      return reply.code(404).send({ error: "not in voice channel" });
    }

    return reply.send({ participant });
  });

  // -----------------------------------------------------------------------
  // POST /api/voice/deafen — toggle deafen
  // -----------------------------------------------------------------------
  app.post<{
    Body: { token?: string; regionId?: string; deafened?: boolean };
  }>("/api/voice/deafen", async (request, reply) => {
    const { token, regionId, deafened } = request.body ?? {};

    if (!token || !regionId || deafened === undefined) {
      return reply.code(400).send({ error: "token, regionId, and deafened are required" });
    }

    const participant = setVoiceDeafened(token, regionId, deafened);

    if (!participant) {
      return reply.code(404).send({ error: "not in voice channel" });
    }

    return reply.send({ participant });
  });

  // -----------------------------------------------------------------------
  // GET /api/voice/participants?regionId= — list voice participants
  // -----------------------------------------------------------------------
  app.get<{
    Querystring: { regionId?: string };
  }>("/api/voice/participants", async (request, reply) => {
    const { regionId } = request.query;

    if (!regionId) {
      return reply.code(400).send({ error: "regionId query parameter is required" });
    }

    const participants = getVoiceParticipants(regionId);
    return reply.send({ participants });
  });
}
