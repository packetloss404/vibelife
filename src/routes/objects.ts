import { FastifyInstance } from "fastify";
import {
  deleteRegionObject,
  getObjectPermissions,
  getSession,
  saveObjectPermissions,
  updateRegionObject,
  createObjectScript,
  listObjectScripts,
  updateObjectScript,
  deleteObjectScript,
  handleGroupObjects,
  handleUngroupObjects,
  handleDuplicateGroup,
  groupMoveObjects,
  groupDeleteObjects,
  duplicateObjects
} from "../world/store.js";

export default async function objectRoutes(app: FastifyInstance) {
  app.patch<{
    Params: { objectId: string };
    Body: { token?: string; x?: number; y?: number; z?: number; rotationY?: number; scale?: number };
  }>("/api/objects/:objectId", async (request, reply) => {
    const { token, x, y, z, rotationY, scale } = request.body;

    if (!token || x === undefined || y === undefined || z === undefined || rotationY === undefined || scale === undefined) {
      return reply.code(400).send({ error: "token, x, y, z, rotationY, and scale are required" });
    }

    const object = await updateRegionObject(token, request.params.objectId, { x, y, z, rotationY, scale });

    if (!object.object) {
      const statusCode = object.permission.allowed ? 404 : 403;
      return reply.code(statusCode).send({ error: object.permission.reason ?? "object not found or not owned" });
    }

    return reply.send({ object: object.object });
  });

  app.delete<{
    Params: { objectId: string };
    Body: { token?: string };
  }>("/api/objects/:objectId", async (request, reply) => {
    const token = request.body.token;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const deleted = await deleteRegionObject(token, request.params.objectId);

    if (!deleted) {
      return reply.code(404).send({ error: "object not found or not owned" });
    }

    return reply.send({ ok: true });
  });

  app.get<{ Params: { objectId: string } }>("/api/objects/:objectId/permissions", async (request, reply) => {
    const perms = await getObjectPermissions(request.params.objectId);
    return reply.send({ permissions: perms ?? { objectId: request.params.objectId, allowCopy: true, allowModify: true, allowTransfer: true } });
  });

  app.patch<{ Params: { objectId: string }; Body: { token?: string; allowCopy?: boolean; allowModify?: boolean; allowTransfer?: boolean } }>("/api/objects/:objectId/permissions", async (request, reply) => {
    const { token, allowCopy = true, allowModify = true, allowTransfer = true } = request.body;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const saved = await saveObjectPermissions(token, request.params.objectId, allowCopy, allowModify, allowTransfer);

    if (!saved) {
      return reply.code(403).send({ error: "failed to save permissions" });
    }

    return reply.send({ ok: true });
  });

  app.get<{ Params: { objectId: string }; Querystring: { token?: string } }>("/api/objects/:objectId/scripts", async (request, reply) => {
    const scripts = await listObjectScripts(request.params.objectId);
    return reply.send({ scripts });
  });

  app.post<{ Body: { token?: string; objectId?: string; scriptName?: string; scriptCode?: string } }>("/api/objects/scripts", async (request, reply) => {
    const { token, objectId, scriptName, scriptCode = "" } = request.body;

    if (!token || !objectId || !scriptName) {
      return reply.code(400).send({ error: "token, objectId, and scriptName are required" });
    }

    const script = await createObjectScript(token, objectId, scriptName, scriptCode);

    if (!script) {
      return reply.code(403).send({ error: "failed to create script" });
    }

    return reply.send({ script });
  });

  app.patch<{ Body: { token?: string; scriptId?: string; scriptCode?: string; enabled?: boolean } }>("/api/objects/scripts", async (request, reply) => {
    const { token, scriptId, scriptCode, enabled = true } = request.body;

    if (!token || !scriptId) {
      return reply.code(400).send({ error: "token and scriptId are required" });
    }

    const script = await updateObjectScript(token, scriptId, scriptCode ?? "", enabled);

    if (!script) {
      return reply.code(403).send({ error: "failed to update script" });
    }

    return reply.send({ script });
  });

  app.delete<{ Body: { token?: string; scriptId?: string } }>("/api/objects/scripts", async (request, reply) => {
    const { token, scriptId } = request.body;

    if (!token || !scriptId) {
      return reply.code(400).send({ error: "token and scriptId are required" });
    }

    const deleted = await deleteObjectScript(token, scriptId);

    if (!deleted) {
      return reply.code(404).send({ error: "script not found" });
    }

    return reply.send({ ok: true });
  });

  app.post<{ Body: { token?: string; objectIds?: string[]; groupName?: string } }>("/api/objects/group", async (request, reply) => {
    const { token, objectIds, groupName } = request.body;

    if (!token || !objectIds || !Array.isArray(objectIds) || objectIds.length === 0 || !groupName) {
      return reply.code(400).send({ error: "token, objectIds, and groupName are required" });
    }

    const group = await handleGroupObjects(token, objectIds, groupName);

    if (!group) {
      return reply.code(403).send({ error: "failed to group objects" });
    }

    return reply.send({ group });
  });

  app.post<{ Body: { token?: string; groupId?: string } }>("/api/objects/ungroup", async (request, reply) => {
    const { token, groupId } = request.body;

    if (!token || !groupId) {
      return reply.code(400).send({ error: "token and groupId are required" });
    }

    const ungrouped = handleUngroupObjects(token, groupId);

    if (!ungrouped) {
      return reply.code(403).send({ error: "failed to ungroup objects" });
    }

    return reply.send({ ok: true });
  });

  app.post<{ Params: { groupId: string }; Body: { token?: string; offsetX?: number; offsetY?: number; offsetZ?: number } }>("/api/groups/:groupId/duplicate", async (request, reply) => {
    const { token, offsetX = 2, offsetY = 0, offsetZ = 2 } = request.body;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const duplicated = await handleDuplicateGroup(token, request.params.groupId, { x: offsetX, y: offsetY, z: offsetZ });

    if (!duplicated) {
      return reply.code(403).send({ error: "failed to duplicate group" });
    }

    return reply.send({ objects: duplicated });
  });

  app.post<{ Body: { token?: string; objectIds?: string[]; deltaX?: number; deltaY?: number; deltaZ?: number } }>("/api/objects/group-move", async (request, reply) => {
    const { token, objectIds, deltaX, deltaY, deltaZ } = request.body;

    if (!token || !objectIds || !Array.isArray(objectIds) || objectIds.length === 0 || deltaX === undefined || deltaY === undefined || deltaZ === undefined) {
      return reply.code(400).send({ error: "token, objectIds[], deltaX, deltaY, and deltaZ are required" });
    }

    const session = getSession(token);
    if (!session) {
      return reply.code(403).send({ error: "invalid session" });
    }

    const updated = await groupMoveObjects(token, objectIds, deltaX, deltaY, deltaZ);

    return reply.send({ objects: updated });
  });

  app.post<{ Body: { token?: string; objectIds?: string[] } }>("/api/objects/group-delete", async (request, reply) => {
    const { token, objectIds } = request.body;

    if (!token || !objectIds || !Array.isArray(objectIds) || objectIds.length === 0) {
      return reply.code(400).send({ error: "token and objectIds[] are required" });
    }

    const session = getSession(token);
    if (!session) {
      return reply.code(403).send({ error: "invalid session" });
    }

    const deleted = await groupDeleteObjects(token, objectIds);

    return reply.send({ deletedIds: deleted });
  });

  app.post<{ Body: { token?: string; regionId?: string; objectIds?: string[]; offsetX?: number; offsetZ?: number } }>("/api/objects/duplicate", async (request, reply) => {
    const { token, regionId, objectIds, offsetX = 1, offsetZ = 1 } = request.body;

    if (!token || !regionId || !objectIds || !Array.isArray(objectIds) || objectIds.length === 0) {
      return reply.code(400).send({ error: "token, regionId, and objectIds[] are required" });
    }

    const session = getSession(token);
    if (!session || session.regionId !== regionId) {
      return reply.code(403).send({ error: "session is not active in this region" });
    }

    const created = await duplicateObjects(token, regionId, objectIds, offsetX, offsetZ);

    return reply.send({ objects: created });
  });
}
