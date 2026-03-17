import { FastifyInstance } from "fastify";
import {
  adminAssignParcel,
  adminDeleteRegionObject,
  banAccount,
  unbanAccount,
  getActiveBan
} from "../world/store.js";
import {
  appendAuditLog,
  getSession,
  listAuditLogs
} from "../world/store.js";

export default async function adminRoutes(app: FastifyInstance) {
  app.post<{ Body: { token?: string; parcelId?: string; ownerAccountId?: string | null } }>("/api/admin/parcels/assign", async (request, reply) => {
    const { token, parcelId, ownerAccountId = null } = request.body;

    if (!token || !parcelId) {
      return reply.code(400).send({ error: "token and parcelId are required" });
    }

    const parcel = await adminAssignParcel(token, parcelId, ownerAccountId);

    if (!parcel) {
      return reply.code(403).send({ error: "admin parcel reassignment failed" });
    }

    const session = getSession(token);
    if (session) {
      await appendAuditLog(token, "admin.parcel.assign", "parcel", parcel.id, `assigned ${parcel.name} to ${ownerAccountId ?? "none"}`, session.regionId);
    }

    return reply.send({ parcel });
  });

  app.post<{ Body: { token?: string; objectId?: string } }>("/api/admin/objects/delete", async (request, reply) => {
    const { token, objectId } = request.body;

    if (!token || !objectId) {
      return reply.code(400).send({ error: "token and objectId are required" });
    }

    const session = getSession(token);
    const deleted = await adminDeleteRegionObject(token, objectId);

    if (!deleted || !session) {
      return reply.code(403).send({ error: "admin object cleanup failed" });
    }

    await appendAuditLog(token, "admin.object.delete", "object", objectId, "admin deleted region object", session.regionId);
    return reply.send({ ok: true });
  });

  app.get<{ Querystring: { token?: string; limit?: string } }>("/api/admin/audit-logs", async (request, reply) => {
    const token = request.query.token;
    const limit = Number(request.query.limit ?? 50);

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const logs = await listAuditLogs(token, Math.max(1, Math.min(200, limit)));

    if (!logs) {
      return reply.code(403).send({ error: "admin audit access denied" });
    }

    return reply.send({ logs });
  });

  app.post<{ Body: { token?: string; accountId?: string; reason?: string; expiresAt?: string } }>("/api/admin/ban", async (request, reply) => {
    const { token, accountId, reason, expiresAt = null } = request.body;

    if (!token || !accountId || !reason) {
      return reply.code(400).send({ error: "token, accountId, and reason are required" });
    }

    const ban = await banAccount(token, accountId, reason, expiresAt ?? null);

    if (!ban) {
      return reply.code(403).send({ error: "ban failed" });
    }

    await appendAuditLog(token, "admin.ban", "account", accountId, reason, null);
    return reply.send({ ban });
  });

  app.delete<{ Body: { token?: string; accountId?: string } }>("/api/admin/ban", async (request, reply) => {
    const { token, accountId } = request.body;

    if (!token || !accountId) {
      return reply.code(400).send({ error: "token and accountId are required" });
    }

    const unbanned = await unbanAccount(token, accountId);

    if (!unbanned) {
      return reply.code(404).send({ error: "ban not found" });
    }

    await appendAuditLog(token, "admin.unban", "account", accountId, "unbanned", null);
    return reply.send({ ok: true });
  });

  app.get<{ Querystring: { token?: string } }>("/api/avatar/ban/status", async (request, reply) => {
    const token = request.query.token;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const ban = await getActiveBan(token);
    return reply.send({ banned: !!ban, ban });
  });
}
