import type { FastifyInstance } from "fastify";
import {
  createMediaObject,
  updateMediaConfig,
  removeMediaObject,
  getMediaObject,
  listMediaObjects,
  validateMediaConfig,
  type MediaType,
} from "../world/media-service.js";

// NOTE for contracts.ts: Add MediaObjectContract type and RegionEvent entries
// for "media:created", "media:updated", "media:removed".
// See comment block at bottom of this file.

// NOTE for server.ts: Register this plugin with:
//   import mediaRoutes from "./routes/media.js";
//   await app.register(mediaRoutes);

export default async function mediaRoutes(app: FastifyInstance) {
  // POST /api/media — attach media to an existing object
  app.post<{
    Body: {
      token?: string;
      objectId?: string;
      mediaType?: string;
      config?: Record<string, unknown>;
    };
  }>("/api/media", async (request, reply) => {
    const { token, objectId, mediaType, config } = request.body;

    if (!token || !objectId || !mediaType || !config) {
      return reply.code(400).send({ error: "token, objectId, mediaType, and config are required" });
    }

    const validTypes: MediaType[] = ["photo_frame", "video_screen", "projection", "billboard", "slideshow"];
    if (!validTypes.includes(mediaType as MediaType)) {
      return reply.code(400).send({ error: `mediaType must be one of: ${validTypes.join(", ")}` });
    }

    const validation = validateMediaConfig(mediaType as MediaType, config);
    if (!validation.valid) {
      return reply.code(400).send({ error: validation.reason });
    }

    const media = await createMediaObject(token, objectId, mediaType as MediaType, config);

    if (!media) {
      return reply.code(403).send({ error: "failed to attach media (invalid session, duplicate, or bad config)" });
    }

    return reply.send({ media });
  });

  // GET /api/media?regionId= — list all media in a region
  app.get<{
    Querystring: { regionId?: string };
  }>("/api/media", async (request, reply) => {
    const { regionId } = request.query;

    if (!regionId) {
      return reply.code(400).send({ error: "regionId query parameter is required" });
    }

    const media = await listMediaObjects(regionId);
    return reply.send({ media });
  });

  // GET /api/media/:objectId — get media info for an object
  app.get<{
    Params: { objectId: string };
  }>("/api/media/:objectId", async (request, reply) => {
    const media = await getMediaObject(request.params.objectId);

    if (!media) {
      return reply.code(404).send({ error: "media not found" });
    }

    return reply.send({ media });
  });

  // PATCH /api/media/:objectId — update media config
  app.patch<{
    Params: { objectId: string };
    Body: { token?: string; config?: Record<string, unknown> };
  }>("/api/media/:objectId", async (request, reply) => {
    const { token, config } = request.body;

    if (!token || !config) {
      return reply.code(400).send({ error: "token and config are required" });
    }

    const media = await updateMediaConfig(token, request.params.objectId, config);

    if (!media) {
      return reply.code(403).send({ error: "failed to update media" });
    }

    return reply.send({ media });
  });

  // DELETE /api/media/:objectId — remove media attachment
  app.delete<{
    Params: { objectId: string };
    Body: { token?: string };
  }>("/api/media/:objectId", async (request, reply) => {
    const token = request.body.token;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const deleted = await removeMediaObject(token, request.params.objectId);

    if (!deleted) {
      return reply.code(404).send({ error: "media not found or not owned" });
    }

    return reply.send({ ok: true });
  });
}

// ---------------------------------------------------------------
// NOTE: The following additions are needed in src/contracts.ts:
//
// export type MediaObjectContract = {
//   id: string;
//   objectId: string;
//   mediaType: "photo_frame" | "video_screen" | "projection" | "billboard" | "slideshow";
//   config: Record<string, unknown>;
//   regionId: string;
//   ownerAccountId: string;
//   createdAt: string;
// };
//
// Add to RegionEvent union:
//   | { type: "media:created"; sequence: number; media: MediaObjectContract }
//   | { type: "media:updated"; sequence: number; media: MediaObjectContract }
//   | { type: "media:removed"; sequence: number; objectId: string }
// ---------------------------------------------------------------
