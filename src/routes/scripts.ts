import type { FastifyInstance } from "fastify";
import { requireAuth } from "../middleware/auth.js";
import {
  createScript,
  getScript,
  updateScript,
  deleteScript,
  listScriptsForParcel,
  listScriptsForRegion,
  toggleScript,
  createTriggerZone,
  listTriggerZones,
  type ScriptNode,
  type NodeConnection,
  type TriggerZoneShape,
} from "../world/script-service.js";

export default async function scriptsPlugin(app: FastifyInstance) {
  // POST /api/scripts — create a visual script
  app.post<{
    Body: {
      token?: string;
      name?: string;
      regionId?: string;
      parcelId?: string;
    };
  }>("/api/scripts", { preHandler: requireAuth }, async (request, reply) => {
    const { name, regionId, parcelId } = request.body;
    const token = request.authToken;

    if (!token) {
      return reply.code(401).send({ error: "invalid session" });
    }

    if (!name || !regionId || !parcelId) {
      return reply.code(400).send({ error: "name, regionId, and parcelId are required" });
    }

    const script = await createScript(token, name, regionId, parcelId);

    if (!script) {
      return reply.code(403).send({ error: "no build permission on this parcel" });
    }

    return reply.send({ script });
  });

  // GET /api/scripts?regionId=&parcelId= — list scripts
  app.get<{
    Querystring: { token?: string; regionId?: string; parcelId?: string };
  }>("/api/scripts", { preHandler: requireAuth }, async (request, reply) => {
    const { regionId, parcelId } = request.query;

    if (!request.session) {
      return reply.code(401).send({ error: "invalid session" });
    }

    if (!regionId) {
      return reply.code(400).send({ error: "regionId is required" });
    }

    const scripts = parcelId
      ? listScriptsForParcel(regionId, parcelId)
      : listScriptsForRegion(regionId);

    return reply.send({ scripts });
  });

  // GET /api/scripts/:id — get single script
  app.get<{
    Params: { id: string };
    Querystring: { token?: string };
  }>("/api/scripts/:id", { preHandler: requireAuth }, async (request, reply) => {
    if (!request.session) {
      return reply.code(401).send({ error: "invalid session" });
    }

    const script = getScript(request.params.id);

    if (!script) {
      return reply.code(404).send({ error: "script not found" });
    }

    return reply.send({ script });
  });

  // PUT /api/scripts/:id — update script nodes and connections
  app.put<{
    Params: { id: string };
    Body: {
      token?: string;
      nodes?: ScriptNode[];
      connections?: NodeConnection[];
    };
  }>("/api/scripts/:id", { preHandler: requireAuth }, async (request, reply) => {
    const { nodes, connections } = request.body;
    const token = request.authToken;

    if (!token) {
      return reply.code(401).send({ error: "invalid session" });
    }

    if (!nodes || !connections) {
      return reply.code(400).send({ error: "nodes and connections are required" });
    }

    const script = await updateScript(token, request.params.id, nodes, connections);

    if (!script) {
      return reply.code(403).send({ error: "script not found or permission denied" });
    }

    return reply.send({ script });
  });

  // DELETE /api/scripts/:id — delete script
  app.delete<{
    Params: { id: string };
    Body: { token?: string };
  }>("/api/scripts/:id", { preHandler: requireAuth }, async (request, reply) => {
    const token = request.authToken;

    if (!token) {
      return reply.code(401).send({ error: "invalid session" });
    }

    const deleted = await deleteScript(token, request.params.id);

    if (!deleted) {
      return reply.code(404).send({ error: "script not found or permission denied" });
    }

    return reply.send({ ok: true });
  });

  // POST /api/scripts/:id/toggle — enable/disable
  app.post<{
    Params: { id: string };
    Body: { token?: string };
  }>("/api/scripts/:id/toggle", { preHandler: requireAuth }, async (request, reply) => {
    const token = request.authToken;

    if (!token) {
      return reply.code(401).send({ error: "invalid session" });
    }

    const script = await toggleScript(token, request.params.id);

    if (!script) {
      return reply.code(403).send({ error: "script not found or permission denied" });
    }

    return reply.send({ script });
  });

  // GET /api/trigger-zones?regionId= — list trigger zones
  app.get<{
    Querystring: { token?: string; regionId?: string };
  }>("/api/trigger-zones", { preHandler: requireAuth }, async (request, reply) => {
    const { regionId } = request.query;

    if (!request.session) {
      return reply.code(401).send({ error: "invalid session" });
    }

    if (!regionId) {
      return reply.code(400).send({ error: "regionId is required" });
    }

    const zones = listTriggerZones(regionId);
    return reply.send({ zones });
  });

  // POST /api/trigger-zones — create trigger zone
  app.post<{
    Body: {
      token?: string;
      scriptId?: string;
      position?: { x: number; y: number; z: number };
      radius?: number;
      shape?: TriggerZoneShape;
      size?: { x: number; y: number; z: number };
    };
  }>("/api/trigger-zones", { preHandler: requireAuth }, async (request, reply) => {
    const { scriptId, position, radius = 3, shape = "sphere", size } = request.body;
    const token = request.authToken;

    if (!token) {
      return reply.code(401).send({ error: "invalid session" });
    }

    if (!scriptId || !position) {
      return reply.code(400).send({ error: "scriptId and position are required" });
    }

    const zone = await createTriggerZone(
      token,
      scriptId,
      position,
      radius,
      shape,
      size ?? { x: 3, y: 3, z: 3 }
    );

    if (!zone) {
      return reply.code(403).send({ error: "script not found or permission denied" });
    }

    return reply.send({ zone });
  });
}
