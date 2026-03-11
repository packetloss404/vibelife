import type { FastifyInstance, FastifyPluginCallback } from "fastify";
import { getRequestToken } from "../middleware/auth.js";
import {
  createMobileSession,
  destroyMobileSession,
  getMobileSession,
  registerPushToken,
  unregisterPushToken,
  getNotificationPreferences,
  updateNotificationPreferences,
  listNotifications,
  markNotificationRead,
  markAllNotificationsRead,
  getUnreadNotificationCount,
  getMobileDashboard,
  getMobileWorldSnapshot,
  getMobileFriendsList,
  getMobileInventory,
  getMobileMarketplace,
  getMobileRegionList,
  getMobileFeed,
  getLightweightSync,
  quickTeleport,
  quickMessage,
  quickSendCurrency,
  type MobileDevicePlatform
} from "../world/mobile-service.js";

function resolveToken(request: { body?: unknown; query?: unknown; headers: Record<string, unknown> }): string | undefined {
  return getRequestToken(request as never);
}

const mobileRoutes: FastifyPluginCallback = (app: FastifyInstance, _opts, done) => {

  // ---------------------------------------------------------------------------
  // Mobile session management
  // ---------------------------------------------------------------------------

  // POST /api/mobile/session — create or refresh a mobile session
  app.post<{
    Body: { token?: string; platform?: MobileDevicePlatform };
  }>("/api/mobile/session", async (request, reply) => {
    const token = resolveToken(request);
    const { platform = "unknown" } = request.body;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const session = createMobileSession(token, platform);

    if (!session) {
      return reply.code(401).send({ error: "invalid or expired session" });
    }

    return reply.send({ session });
  });

  // GET /api/mobile/session — get current mobile session info
  app.get<{
    Querystring: { token?: string };
  }>("/api/mobile/session", async (request, reply) => {
    const token = resolveToken(request);

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const session = getMobileSession(token);

    if (!session) {
      return reply.code(401).send({ error: "no active mobile session" });
    }

    return reply.send({ session });
  });

  // DELETE /api/mobile/session — destroy a mobile session
  app.delete<{
    Body: { token?: string };
  }>("/api/mobile/session", async (request, reply) => {
    const token = resolveToken(request);

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const destroyed = destroyMobileSession(token);
    return reply.send({ ok: destroyed });
  });

  // ---------------------------------------------------------------------------
  // Push notification token management
  // ---------------------------------------------------------------------------

  // POST /api/mobile/push-token — register a push notification token
  app.post<{
    Body: { token?: string; platform?: MobileDevicePlatform; pushToken?: string };
  }>("/api/mobile/push-token", async (request, reply) => {
    const { token, platform = "unknown", pushToken } = request.body;

    if (!token || !pushToken) {
      return reply.code(400).send({ error: "token and pushToken are required" });
    }

    const result = registerPushToken(token, platform, pushToken);

    if (!result) {
      return reply.code(401).send({ error: "invalid session" });
    }

    return reply.send({ pushToken: result });
  });

  // DELETE /api/mobile/push-token — unregister push notification token
  app.delete<{
    Body: { token?: string };
  }>("/api/mobile/push-token", async (request, reply) => {
    const { token } = request.body;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const removed = unregisterPushToken(token);
    return reply.send({ ok: removed });
  });

  // ---------------------------------------------------------------------------
  // Notification preferences
  // ---------------------------------------------------------------------------

  // GET /api/mobile/notifications/preferences — get notification preferences
  app.get<{
    Querystring: { token?: string };
  }>("/api/mobile/notifications/preferences", async (request, reply) => {
    const token = resolveToken(request);

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const prefs = getNotificationPreferences(token);

    if (!prefs) {
      return reply.code(401).send({ error: "invalid session" });
    }

    return reply.send({ preferences: prefs });
  });

  // PATCH /api/mobile/notifications/preferences — update notification preferences
  app.patch<{
    Body: {
      token?: string;
      friendOnline?: boolean;
      friendMessage?: boolean;
      groupInvite?: boolean;
      currencyReceived?: boolean;
      regionEvent?: boolean;
      systemAlert?: boolean;
      quietHoursStart?: string | null;
      quietHoursEnd?: string | null;
    };
  }>("/api/mobile/notifications/preferences", async (request, reply) => {
    const { token, ...updates } = request.body;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const prefs = updateNotificationPreferences(token, updates);

    if (!prefs) {
      return reply.code(401).send({ error: "invalid session" });
    }

    return reply.send({ preferences: prefs });
  });

  // ---------------------------------------------------------------------------
  // Notifications
  // ---------------------------------------------------------------------------

  // GET /api/mobile/notifications — list notifications
  app.get<{
    Querystring: { token?: string; limit?: string; unreadOnly?: string };
  }>("/api/mobile/notifications", async (request, reply) => {
    const token = request.query.token;
    const limit = Number(request.query.limit ?? 50);
    const unreadOnly = request.query.unreadOnly === "true";

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const items = listNotifications(token, Math.max(1, Math.min(100, limit)), unreadOnly);
    const unreadCount = getUnreadNotificationCount(token);

    return reply.send({ notifications: items, unreadCount });
  });

  // PATCH /api/mobile/notifications/read — mark a notification as read
  app.patch<{
    Body: { token?: string; notificationId?: string };
  }>("/api/mobile/notifications/read", async (request, reply) => {
    const { token, notificationId } = request.body;

    if (!token || !notificationId) {
      return reply.code(400).send({ error: "token and notificationId are required" });
    }

    const marked = markNotificationRead(token, notificationId);
    return reply.send({ ok: marked });
  });

  // POST /api/mobile/notifications/read-all — mark all notifications as read
  app.post<{
    Body: { token?: string };
  }>("/api/mobile/notifications/read-all", async (request, reply) => {
    const { token } = request.body;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const count = markAllNotificationsRead(token);
    return reply.send({ ok: true, markedRead: count });
  });

  // ---------------------------------------------------------------------------
  // Dashboard and feed
  // ---------------------------------------------------------------------------

  // GET /api/mobile/dashboard — get mobile dashboard data
  app.get<{
    Querystring: { token?: string };
  }>("/api/mobile/dashboard", async (request, reply) => {
    const token = request.query.token;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const dashboard = await getMobileDashboard(token);

    if (!dashboard) {
      return reply.code(401).send({ error: "invalid session" });
    }

    return reply.send({ dashboard });
  });

  // GET /api/mobile/feed — get activity feed
  app.get<{
    Querystring: { token?: string; limit?: string };
  }>("/api/mobile/feed", async (request, reply) => {
    const token = request.query.token;
    const limit = Number(request.query.limit ?? 30);

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const feed = await getMobileFeed(token, Math.max(1, Math.min(100, limit)));
    return reply.send({ feed });
  });

  // ---------------------------------------------------------------------------
  // World state (lightweight sync for simplified 3D view)
  // ---------------------------------------------------------------------------

  // GET /api/mobile/world — get lightweight world snapshot
  app.get<{
    Querystring: { token?: string };
  }>("/api/mobile/world", async (request, reply) => {
    const token = request.query.token;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const snapshot = await getMobileWorldSnapshot(token);

    if (!snapshot) {
      return reply.code(401).send({ error: "invalid session" });
    }

    return reply.send({ world: snapshot });
  });

  // GET /api/mobile/world/sync — get lightweight position sync for 3D view
  app.get<{
    Querystring: { token?: string };
  }>("/api/mobile/world/sync", async (request, reply) => {
    const token = request.query.token;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const sync = await getLightweightSync(token);

    if (!sync) {
      return reply.code(401).send({ error: "invalid session" });
    }

    return reply.send({ sync });
  });

  // ---------------------------------------------------------------------------
  // Friends (mobile-optimized with online status)
  // ---------------------------------------------------------------------------

  // GET /api/mobile/friends — get friends with online status
  app.get<{
    Querystring: { token?: string };
  }>("/api/mobile/friends", async (request, reply) => {
    const token = request.query.token;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const result = await getMobileFriendsList(token);

    if (!result) {
      return reply.code(401).send({ error: "invalid session" });
    }

    return reply.send(result);
  });

  // ---------------------------------------------------------------------------
  // Inventory (mobile-optimized)
  // ---------------------------------------------------------------------------

  // GET /api/mobile/inventory — get inventory items
  app.get<{
    Querystring: { token?: string };
  }>("/api/mobile/inventory", async (request, reply) => {
    const token = request.query.token;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const items = await getMobileInventory(token);

    if (!items) {
      return reply.code(401).send({ error: "invalid session" });
    }

    return reply.send({ inventory: items });
  });

  // ---------------------------------------------------------------------------
  // Marketplace (mobile-optimized)
  // ---------------------------------------------------------------------------

  // GET /api/mobile/marketplace — browse marketplace listings
  app.get<{
    Querystring: { token?: string; limit?: string };
  }>("/api/mobile/marketplace", async (request, reply) => {
    const token = request.query.token;
    const limit = Number(request.query.limit ?? 50);

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const listings = await getMobileMarketplace(token, Math.max(1, Math.min(100, limit)));
    return reply.send({ listings });
  });

  // ---------------------------------------------------------------------------
  // Regions (mobile-optimized with friend counts)
  // ---------------------------------------------------------------------------

  // GET /api/mobile/regions — list regions with population and friend data
  app.get<{
    Querystring: { token?: string };
  }>("/api/mobile/regions", async (request, reply) => {
    const token = request.query.token;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const result = await getMobileRegionList(token);

    if (!result) {
      return reply.code(401).send({ error: "invalid session" });
    }

    return reply.send(result);
  });

  // ---------------------------------------------------------------------------
  // Quick actions
  // ---------------------------------------------------------------------------

  // POST /api/mobile/quick-actions/teleport — quick teleport to a location
  app.post<{
    Body: { token?: string; regionId?: string; x?: number; y?: number; z?: number };
  }>("/api/mobile/quick-actions/teleport", async (request, reply) => {
    const { token, regionId, x = 0, y = 0, z = 0 } = request.body;

    if (!token || !regionId) {
      return reply.code(400).send({ error: "token and regionId are required" });
    }

    const result = await quickTeleport(token, regionId, x, y, z);

    if (!result.ok) {
      return reply.code(403).send({ error: result.reason ?? "teleport failed" });
    }

    return reply.send({ ok: true, regionId: result.regionId });
  });

  // POST /api/mobile/quick-actions/message — send a quick message to a friend
  app.post<{
    Body: { token?: string; toAccountId?: string; message?: string };
  }>("/api/mobile/quick-actions/message", async (request, reply) => {
    const { token, toAccountId, message } = request.body;

    if (!token || !toAccountId || !message) {
      return reply.code(400).send({ error: "token, toAccountId, and message are required" });
    }

    const result = await quickMessage(token, toAccountId, message);

    if (!result.ok) {
      return reply.code(403).send({ error: result.reason ?? "message failed" });
    }

    return reply.send({ ok: true });
  });

  // POST /api/mobile/quick-actions/send-currency — quick send currency
  app.post<{
    Body: { token?: string; toAccountId?: string; amount?: number; description?: string };
  }>("/api/mobile/quick-actions/send-currency", async (request, reply) => {
    const { token, toAccountId, amount, description = "mobile gift" } = request.body;

    if (!token || !toAccountId || !amount || amount <= 0) {
      return reply.code(400).send({ error: "token, toAccountId, and positive amount are required" });
    }

    const result = await quickSendCurrency(token, toAccountId, amount, description);

    if (!result.ok) {
      return reply.code(403).send({ error: result.reason ?? "send failed" });
    }

    return reply.send({ ok: true, balance: result.balance });
  });

  done();
};

export default mobileRoutes;
