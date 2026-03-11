import type { FastifyInstance } from "fastify";
import { requireAuth } from "../middleware/auth.js";
import {
  registerInteractive,
  removeInteractive,
  getInteractiveByObjectId,
  getInteractivesByRegion,
  interactWith,
  type InteractionType,
} from "../world/interactive-service.js";

const VALID_TYPES: InteractionType[] = [
  "door",
  "elevator",
  "platform",
  "button",
  "switch",
  "teleporter",
  "chest",
];

export default async function interactivesRoutes(app: FastifyInstance) {
  // POST /api/interactives — register an object as interactive
  app.post<{
    Body: {
      token?: string;
      objectId?: string;
      regionId?: string;
      interactionType?: string;
      config?: Record<string, unknown>;
    };
  }>("/api/interactives", { preHandler: requireAuth }, async (request, reply) => {
    const { objectId, regionId, interactionType, config = {} } = request.body;

    if (!objectId || !regionId || !interactionType) {
      return reply.code(400).send({
        error: "objectId, regionId, and interactionType are required",
      });
    }

    if (!VALID_TYPES.includes(interactionType as InteractionType)) {
      return reply.code(400).send({
        error: `interactionType must be one of: ${VALID_TYPES.join(", ")}`,
      });
    }

    const interactive = registerInteractive(
      objectId,
      regionId,
      interactionType as InteractionType,
      config
    );

    return reply.send({ interactive });
  });

  // GET /api/interactives?regionId= — list interactives in a region
  app.get<{
    Querystring: { regionId?: string; token?: string };
  }>("/api/interactives", { preHandler: requireAuth }, async (request, reply) => {
    const { regionId } = request.query;
    const session = request.session;
    if (!session) {
      return reply.code(401).send({ error: "invalid session" });
    }

    const region = regionId ?? session.regionId;
    const interactives = getInteractivesByRegion(region);
    return reply.send({ interactives });
  });

  // GET /api/interactives/:objectId — get interactive state
  app.get<{
    Params: { objectId: string };
    Querystring: { token?: string };
  }>("/api/interactives/:objectId", { preHandler: requireAuth }, async (request, reply) => {
    if (!request.session) {
      return reply.code(401).send({ error: "invalid session" });
    }

    const interactive = getInteractiveByObjectId(request.params.objectId);
    if (!interactive) {
      return reply.code(404).send({ error: "interactive object not found" });
    }

    return reply.send({ interactive });
  });

  // POST /api/interactives/:objectId/interact — interact with object
  app.post<{
    Params: { objectId: string };
    Body: { token?: string };
  }>("/api/interactives/:objectId/interact", { preHandler: requireAuth }, async (request, reply) => {
    const token = request.authToken;
    if (!token) {
      return reply.code(401).send({ error: "invalid session" });
    }

    const result = interactWith(token, request.params.objectId);

    if (!result) {
      return reply.code(404).send({
        error: "interactive object not found or invalid session",
      });
    }

    return reply.send({ interactive: result });
  });

  // DELETE /api/interactives/:objectId — remove interactive behavior
  app.delete<{
    Params: { objectId: string };
    Body: { token?: string };
  }>("/api/interactives/:objectId", { preHandler: requireAuth }, async (request, reply) => {
    if (!request.session) {
      return reply.code(401).send({ error: "invalid session" });
    }

    const removed = removeInteractive(request.params.objectId);

    if (!removed) {
      return reply.code(404).send({ error: "interactive object not found" });
    }

    return reply.send({ ok: true });
  });
}
