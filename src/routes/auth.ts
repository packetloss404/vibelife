import { FastifyInstance } from "fastify";
import {
  appendAuditLog,
  createGuestSession,
  createMcSession,
  linkMcAccount,
  getPersistenceMode,
  loginSession,
  registerSession
} from "../world/store.js";

export default async function authRoutes(app: FastifyInstance) {
  app.post<{ Body: { displayName?: string; regionId?: string } }>("/api/auth/guest", { config: { rateLimit: { max: 10, timeWindow: "1 minute" } } }, async (request, reply) => {
    const displayName = (request.body.displayName ?? "Guest Voyager").trim().slice(0, 32) || "Guest Voyager";
    const { account, inventory, parcels, appearance, session, avatar } = await createGuestSession(displayName, request.body.regionId);

    return reply.send({
      session,
      account,
      inventory,
      parcels,
      appearance,
      avatar,
      persistence: getPersistenceMode()
    });
  });

  app.post<{ Body: { displayName?: string; password?: string; regionId?: string } }>("/api/auth/register", { config: { rateLimit: { max: 5, timeWindow: "1 minute" } } }, async (request, reply) => {
    const displayName = (request.body.displayName ?? "").trim().slice(0, 32);
    const password = (request.body.password ?? "").trim();
    const adminBootstrapToken = (request.body as { adminBootstrapToken?: string }).adminBootstrapToken;

    if (!displayName || password.length < 4) {
      return reply.code(400).send({ error: "displayName and password are required" });
    }

    const result = await registerSession(displayName, password, request.body.regionId, adminBootstrapToken);

    if (!result.ok) {
      return reply.code(409).send({ error: result.reason });
    }

    await appendAuditLog(result.session.token, "auth.register", "account", result.account.id, `registered ${result.account.kind}/${result.account.role}`, result.session.regionId);

    return reply.send({
      session: result.session,
      account: result.account,
      inventory: result.inventory,
      parcels: result.parcels,
      appearance: result.appearance,
      avatar: result.avatar,
      persistence: getPersistenceMode()
    });
  });

  app.post<{ Body: { displayName?: string; password?: string; regionId?: string } }>("/api/auth/login", { config: { rateLimit: { max: 10, timeWindow: "1 minute" } } }, async (request, reply) => {
    const displayName = (request.body.displayName ?? "").trim().slice(0, 32);
    const password = (request.body.password ?? "").trim();

    if (!displayName || password.length < 4) {
      return reply.code(400).send({ error: "displayName and password are required" });
    }

    const result = await loginSession(displayName, password, request.body.regionId);

    if (!result.ok) {
      return reply.code(401).send({ error: result.reason });
    }

    await appendAuditLog(result.session.token, "auth.login", "account", result.account.id, `login ${result.account.kind}/${result.account.role}`, result.session.regionId);

    return reply.send({
      session: result.session,
      account: result.account,
      inventory: result.inventory,
      parcels: result.parcels,
      appearance: result.appearance,
      avatar: result.avatar,
      persistence: getPersistenceMode()
    });
  });

  // ── Minecraft auth (Spigot plugin calls these) ────────────────────────────

  app.post<{ Body: { mcUuid?: string; mcUsername?: string; regionId?: string } }>("/api/auth/mc-login", { config: { rateLimit: { max: 20, timeWindow: "1 minute" } } }, async (request, reply) => {
    const mcUuid = (request.body.mcUuid ?? "").trim();
    const mcUsername = (request.body.mcUsername ?? "").trim().slice(0, 32) || "Steve";

    if (!mcUuid) {
      return reply.code(400).send({ error: "mcUuid is required" });
    }

    const result = await createMcSession(mcUuid, mcUsername, request.body.regionId);

    await appendAuditLog(result.session.token, "auth.mc-login", "account", result.account.id, `mc login uuid=${mcUuid} new=${result.isNewAccount}`, result.session.regionId);

    return reply.send({
      session: result.session,
      account: result.account,
      isNewAccount: result.isNewAccount,
      persistence: getPersistenceMode()
    });
  });

  app.post<{ Body: { mcUuid?: string; displayName?: string; password?: string } }>("/api/auth/mc-link", { config: { rateLimit: { max: 5, timeWindow: "1 minute" } } }, async (request, reply) => {
    const mcUuid = (request.body.mcUuid ?? "").trim();
    const displayName = (request.body.displayName ?? "").trim().slice(0, 32);
    const password = (request.body.password ?? "").trim();

    if (!mcUuid || !displayName || password.length < 4) {
      return reply.code(400).send({ error: "mcUuid, displayName, and password are required" });
    }

    const result = await linkMcAccount(mcUuid, displayName, password);

    if (!result.ok) {
      return reply.code(401).send({ error: result.reason });
    }

    return reply.send({ ok: true, accountId: result.accountId });
  });
}
