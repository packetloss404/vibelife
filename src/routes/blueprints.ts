import type { FastifyInstance } from "fastify";
import {
  getSession,
  createBlueprint,
  listBlueprints,
  getBlueprint,
  deleteBlueprint,
  placeBlueprint
} from "../world/store.js";

export async function blueprintRoutes(app: FastifyInstance) {
  app.post<{ Body: { token?: string; name?: string; objectIds?: string[] } }>("/api/blueprints", async (request, reply) => {
    const { token, name, objectIds } = request.body;

    if (!token || !name || !objectIds || !Array.isArray(objectIds) || objectIds.length === 0) {
      return reply.code(400).send({ error: "token, name, and objectIds[] are required" });
    }

    const blueprint = await createBlueprint(token, name, objectIds);

    if (!blueprint) {
      return reply.code(403).send({ error: "unable to create blueprint" });
    }

    return reply.send({ blueprint });
  });

  app.get<{ Querystring: { token?: string } }>("/api/blueprints", async (request, reply) => {
    const token = request.query.token;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const items = listBlueprints(token);
    return reply.send({ blueprints: items });
  });

  app.get<{ Params: { id: string } }>("/api/blueprints/:id", async (request, reply) => {
    const blueprint = getBlueprint(request.params.id);

    if (!blueprint) {
      return reply.code(404).send({ error: "blueprint not found" });
    }

    return reply.send({ blueprint });
  });

  app.delete<{ Params: { id: string }; Body: { token?: string } }>("/api/blueprints/:id", async (request, reply) => {
    const token = request.body.token;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const deleted = deleteBlueprint(token, request.params.id);

    if (!deleted) {
      return reply.code(404).send({ error: "blueprint not found or not owned" });
    }

    return reply.send({ ok: true });
  });

  app.post<{ Params: { id: string }; Body: { token?: string; regionId?: string; x?: number; z?: number } }>("/api/blueprints/:id/place", async (request, reply) => {
    const { token, regionId, x, z } = request.body;

    if (!token || !regionId || x === undefined || z === undefined) {
      return reply.code(400).send({ error: "token, regionId, x, and z are required" });
    }

    const session = getSession(token);

    if (!session || session.regionId !== regionId) {
      return reply.code(403).send({ error: "session is not active in this region" });
    }

    const objects = await placeBlueprint(token, request.params.id, regionId, x, z);

    if (objects.length === 0) {
      return reply.code(403).send({ error: "unable to place blueprint" });
    }

    return reply.send({ objects });
  });
}
