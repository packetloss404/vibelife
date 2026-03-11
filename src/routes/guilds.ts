import type { FastifyInstance } from "fastify";
import {
  getGuildDetails,
  setGroupParcel,
  removeGroupParcel,
  listGroupParcels,
  depositToTreasury,
  withdrawFromTreasury,
  getTreasuryBalance,
  getTreasuryHistory,
  setMemberRole,
  setGroupEmblem,
  setBannerText,
  createAlliance,
  acceptAlliance,
  removeAlliance,
  listAlliances,
} from "../world/guild-service.js";

export async function registerGuildRoutes(app: FastifyInstance) {
  // ── Guild details ──────────────────────────────────────────────────────

  app.get<{ Params: { id: string } }>(
    "/api/groups/:id/details",
    async (request, reply) => {
      const details = await getGuildDetails(request.params.id);
      return reply.send({ details });
    }
  );

  // ── Parcels ────────────────────────────────────────────────────────────

  app.post<{ Params: { id: string }; Body: { token?: string; parcelId?: string } }>(
    "/api/groups/:id/parcels",
    async (request, reply) => {
      const { token, parcelId } = request.body;
      if (!token || !parcelId) {
        return reply.code(400).send({ error: "token and parcelId are required" });
      }
      const result = await setGroupParcel(token, request.params.id, parcelId);
      if (!result.ok) {
        return reply.code(403).send({ error: result.reason });
      }
      return reply.send({ ok: true });
    }
  );

  app.delete<{ Params: { id: string; parcelId: string }; Body: { token?: string } }>(
    "/api/groups/:id/parcels/:parcelId",
    async (request, reply) => {
      const token = request.body.token;
      if (!token) {
        return reply.code(400).send({ error: "token is required" });
      }
      const result = await removeGroupParcel(token, request.params.id, request.params.parcelId);
      if (!result.ok) {
        return reply.code(403).send({ error: result.reason });
      }
      return reply.send({ ok: true });
    }
  );

  app.get<{ Params: { id: string } }>(
    "/api/groups/:id/parcels",
    async (request, reply) => {
      const parcelIds = await listGroupParcels(request.params.id);
      return reply.send({ parcelIds });
    }
  );

  // ── Treasury ───────────────────────────────────────────────────────────

  app.post<{ Params: { id: string }; Body: { token?: string; amount?: number } }>(
    "/api/groups/:id/treasury/deposit",
    async (request, reply) => {
      const { token, amount } = request.body;
      if (!token || !amount) {
        return reply.code(400).send({ error: "token and amount are required" });
      }
      const result = await depositToTreasury(token, request.params.id, amount);
      if (!result.ok) {
        return reply.code(403).send({ error: result.reason });
      }
      return reply.send({ ok: true, treasury: result.treasury });
    }
  );

  app.post<{ Params: { id: string }; Body: { token?: string; amount?: number } }>(
    "/api/groups/:id/treasury/withdraw",
    async (request, reply) => {
      const { token, amount } = request.body;
      if (!token || !amount) {
        return reply.code(400).send({ error: "token and amount are required" });
      }
      const result = await withdrawFromTreasury(token, request.params.id, amount);
      if (!result.ok) {
        return reply.code(403).send({ error: result.reason });
      }
      return reply.send({ ok: true, treasury: result.treasury });
    }
  );

  app.get<{ Params: { id: string } }>(
    "/api/groups/:id/treasury",
    async (request, reply) => {
      const balance = await getTreasuryBalance(request.params.id);
      const history = await getTreasuryHistory(request.params.id);
      return reply.send({ balance, history });
    }
  );

  // ── Member roles ───────────────────────────────────────────────────────

  app.patch<{
    Params: { id: string; accountId: string };
    Body: { token?: string; role?: string };
  }>(
    "/api/groups/:id/members/:accountId/role",
    async (request, reply) => {
      const { token, role } = request.body;
      if (!token || !role) {
        return reply.code(400).send({ error: "token and role are required" });
      }
      if (!["member", "officer", "owner"].includes(role)) {
        return reply.code(400).send({ error: "role must be member, officer, or owner" });
      }
      const result = await setMemberRole(
        token,
        request.params.id,
        request.params.accountId,
        role as "member" | "officer" | "owner"
      );
      if (!result.ok) {
        return reply.code(403).send({ error: result.reason });
      }
      return reply.send({ ok: true });
    }
  );

  // ── Emblem & banner ────────────────────────────────────────────────────

  app.patch<{ Params: { id: string }; Body: { token?: string; color?: string; icon?: string } }>(
    "/api/groups/:id/emblem",
    async (request, reply) => {
      const { token, color, icon } = request.body;
      if (!token || !color || !icon) {
        return reply.code(400).send({ error: "token, color, and icon are required" });
      }
      const result = await setGroupEmblem(token, request.params.id, color, icon);
      if (!result.ok) {
        return reply.code(403).send({ error: result.reason });
      }
      return reply.send({ ok: true });
    }
  );

  app.patch<{ Params: { id: string }; Body: { token?: string; text?: string } }>(
    "/api/groups/:id/banner",
    async (request, reply) => {
      const { token, text } = request.body;
      if (!token || text === undefined) {
        return reply.code(400).send({ error: "token and text are required" });
      }
      const result = await setBannerText(token, request.params.id, text);
      if (!result.ok) {
        return reply.code(403).send({ error: result.reason });
      }
      return reply.send({ ok: true });
    }
  );

  // ── Alliances ──────────────────────────────────────────────────────────

  app.post<{ Params: { id: string }; Body: { token?: string; targetGroupId?: string } }>(
    "/api/groups/:id/alliances",
    async (request, reply) => {
      const { token, targetGroupId } = request.body;
      if (!token || !targetGroupId) {
        return reply.code(400).send({ error: "token and targetGroupId are required" });
      }
      const result = await createAlliance(token, request.params.id, targetGroupId);
      if (!result.ok) {
        return reply.code(403).send({ error: result.reason });
      }
      return reply.send({ ok: true });
    }
  );

  app.post<{ Params: { id: string; targetGroupId: string }; Body: { token?: string } }>(
    "/api/groups/:id/alliances/:targetGroupId/accept",
    async (request, reply) => {
      const token = request.body.token;
      if (!token) {
        return reply.code(400).send({ error: "token is required" });
      }
      const result = await acceptAlliance(
        token,
        request.params.id,
        request.params.targetGroupId
      );
      if (!result.ok) {
        return reply.code(403).send({ error: result.reason });
      }
      return reply.send({ ok: true });
    }
  );

  app.delete<{ Params: { id: string; targetGroupId: string }; Body: { token?: string } }>(
    "/api/groups/:id/alliances/:targetGroupId",
    async (request, reply) => {
      const token = request.body.token;
      if (!token) {
        return reply.code(400).send({ error: "token is required" });
      }
      const result = await removeAlliance(
        token,
        request.params.id,
        request.params.targetGroupId
      );
      if (!result.ok) {
        return reply.code(403).send({ error: result.reason });
      }
      return reply.send({ ok: true });
    }
  );

  app.get<{ Params: { id: string } }>(
    "/api/groups/:id/alliances",
    async (request, reply) => {
      const alliances = await listAlliances(request.params.id);
      return reply.send({ alliances });
    }
  );
}
