// Creator Tools Routes — Feature 17: Creator Tools Platform
//
// Integration notes (DO NOT auto-apply):
//   server.ts — register this plugin:
//     import creatorToolsRoutes from "./routes/creator-tools.js";
//     await app.register(creatorToolsRoutes);

import type { FastifyInstance } from "fastify";
import {
  submitAssetForReview,
  getSubmission,
  listCreatorSubmissions,
  listAssetReviewQueue,
  reviewAsset,
  getCreatorAnalytics,
  getCreatorRevenue,
  configureRevenueSplit,
  listPayouts,
  requestPayout,
  registerPlugin,
  listPlugins,
  getPlugin,
  updatePlugin,
  revokePlugin,
  regenerateApiKey,
  registerWebhook,
  listWebhooks,
  updateWebhook,
  deleteWebhook,
  recordAssetView,
  recordAssetSale,
  validateApiKey,
} from "../world/creator-tools-service.js";

export default async function creatorToolsRoutes(app: FastifyInstance) {

  // ---------------------------------------------------------------------------
  // Asset Pipeline — Submit & Track
  // ---------------------------------------------------------------------------

  /** Submit an asset for review (Blender-to-VibeLife pipeline entry point) */
  app.post<{
    Body: {
      token?: string;
      name?: string;
      description?: string;
      assetType?: string;
      sourceFormat?: string;
      sourceUrl?: string;
      thumbnailUrl?: string | null;
      fileSize?: number;
      tags?: string[];
    };
  }>("/api/creator/assets/submit", async (request, reply) => {
    const { token, name, description = "", assetType, sourceFormat, sourceUrl, thumbnailUrl = null, fileSize, tags = [] } = request.body;

    if (!token || !name || !assetType || !sourceFormat || !sourceUrl || fileSize === undefined) {
      return reply.code(400).send({ error: "token, name, assetType, sourceFormat, sourceUrl, and fileSize are required" });
    }

    const result = await submitAssetForReview(token, {
      name,
      description,
      assetType,
      sourceFormat,
      sourceUrl,
      thumbnailUrl,
      fileSize,
      tags,
    });

    if (result.error) {
      return reply.code(400).send({ error: result.error });
    }

    return reply.send({ submission: result.submission });
  });

  /** Get a specific submission's status (including conversion progress) */
  app.get<{
    Params: { submissionId: string };
    Querystring: { token?: string };
  }>("/api/creator/assets/submit/:submissionId", async (request, reply) => {
    const token = request.query.token;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const submission = await getSubmission(token, request.params.submissionId);

    if (!submission) {
      return reply.code(404).send({ error: "submission not found" });
    }

    return reply.send({ submission });
  });

  /** List all submissions by the authenticated creator */
  app.get<{
    Querystring: { token?: string };
  }>("/api/creator/assets/submissions", async (request, reply) => {
    const token = request.query.token;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const submissions = await listCreatorSubmissions(token);
    return reply.send({ submissions });
  });

  // ---------------------------------------------------------------------------
  // Asset Review (Admin)
  // ---------------------------------------------------------------------------

  /** List the review queue (admin only) */
  app.get<{
    Querystring: { token?: string; status?: string };
  }>("/api/creator/assets/review", async (request, reply) => {
    const token = request.query.token;
    const status = request.query.status;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const queue = await listAssetReviewQueue(token, status);

    if (!queue) {
      return reply.code(403).send({ error: "admin access required" });
    }

    return reply.send({ queue });
  });

  /** Review a submission (admin only) — approve, reject, or request revision */
  app.post<{
    Body: {
      token?: string;
      submissionId?: string;
      decision?: string;
      notes?: string;
    };
  }>("/api/creator/assets/review", async (request, reply) => {
    const { token, submissionId, decision, notes = "" } = request.body;

    if (!token || !submissionId || !decision) {
      return reply.code(400).send({ error: "token, submissionId, and decision are required" });
    }

    if (!["approved", "rejected", "revision_requested"].includes(decision)) {
      return reply.code(400).send({ error: "decision must be approved, rejected, or revision_requested" });
    }

    const result = await reviewAsset(
      token,
      submissionId,
      decision as "approved" | "rejected" | "revision_requested",
      notes
    );

    if (result.error) {
      const code = result.error === "admin access required" ? 403 : 404;
      return reply.code(code).send({ error: result.error });
    }

    return reply.send({ submission: result.submission });
  });

  // ---------------------------------------------------------------------------
  // Creator Analytics
  // ---------------------------------------------------------------------------

  /** Get creator analytics dashboard data */
  app.get<{
    Querystring: { token?: string; periodDays?: string };
  }>("/api/creator/analytics", async (request, reply) => {
    const token = request.query.token;
    const periodDays = Math.max(1, Math.min(365, Number(request.query.periodDays ?? 30)));

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const analytics = await getCreatorAnalytics(token, periodDays);

    if (!analytics) {
      return reply.code(403).send({ error: "unable to retrieve analytics" });
    }

    return reply.send({ analytics });
  });

  /** Record an asset view (called when someone views an asset listing) */
  app.post<{
    Body: { token?: string; assetId?: string };
  }>("/api/creator/analytics/view", async (request, reply) => {
    const { token, assetId } = request.body;

    if (!token || !assetId) {
      return reply.code(400).send({ error: "token and assetId are required" });
    }

    recordAssetView(assetId);
    return reply.send({ ok: true });
  });

  /** Record an asset sale (called upon marketplace purchase completion) */
  app.post<{
    Body: { token?: string; assetId?: string; amount?: number };
  }>("/api/creator/analytics/sale", async (request, reply) => {
    const { token, assetId, amount } = request.body;

    if (!token || !assetId || !amount || amount <= 0) {
      return reply.code(400).send({ error: "token, assetId, and positive amount are required" });
    }

    recordAssetSale(assetId, amount);
    return reply.send({ ok: true });
  });

  // ---------------------------------------------------------------------------
  // Revenue Sharing
  // ---------------------------------------------------------------------------

  /** Get current creator revenue info (split config, pending payout, history) */
  app.get<{
    Querystring: { token?: string };
  }>("/api/creator/revenue", async (request, reply) => {
    const token = request.query.token;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const revenue = await getCreatorRevenue(token);

    if (!revenue) {
      return reply.code(403).send({ error: "unable to retrieve revenue data" });
    }

    return reply.send({ revenue });
  });

  /** Configure revenue split for a creator (admin only) */
  app.post<{
    Body: {
      token?: string;
      targetAccountId?: string;
      platformPercent?: number;
      creatorPercent?: number;
    };
  }>("/api/creator/revenue/split", async (request, reply) => {
    const { token, targetAccountId, platformPercent, creatorPercent } = request.body;

    if (!token || !targetAccountId || platformPercent === undefined || creatorPercent === undefined) {
      return reply.code(400).send({ error: "token, targetAccountId, platformPercent, and creatorPercent are required" });
    }

    const result = await configureRevenueSplit(token, targetAccountId, platformPercent, creatorPercent);

    if (result.error) {
      const code = result.error === "admin access required" ? 403 : 400;
      return reply.code(code).send({ error: result.error });
    }

    return reply.send({ split: result.split });
  });

  /** List creator payouts */
  app.get<{
    Querystring: { token?: string };
  }>("/api/creator/revenue/payouts", async (request, reply) => {
    const token = request.query.token;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const payoutList = await listPayouts(token);
    return reply.send({ payouts: payoutList });
  });

  /** Request a payout */
  app.post<{
    Body: { token?: string; amount?: number };
  }>("/api/creator/revenue/payouts", async (request, reply) => {
    const { token, amount } = request.body;

    if (!token || !amount || amount <= 0) {
      return reply.code(400).send({ error: "token and positive amount are required" });
    }

    const result = await requestPayout(token, amount);

    if (result.error) {
      return reply.code(400).send({ error: result.error });
    }

    return reply.send({ payout: result.payout });
  });

  // ---------------------------------------------------------------------------
  // SDK — Plugin Registry
  // ---------------------------------------------------------------------------

  /** Register a new plugin */
  app.post<{
    Body: {
      token?: string;
      name?: string;
      description?: string;
      webhookUrl?: string | null;
      permissions?: string[];
    };
  }>("/api/creator/plugins", async (request, reply) => {
    const { token, name, description = "", webhookUrl = null, permissions = [] } = request.body;

    if (!token || !name) {
      return reply.code(400).send({ error: "token and name are required" });
    }

    const result = await registerPlugin(token, { name, description, webhookUrl, permissions });

    if (result.error) {
      return reply.code(400).send({ error: result.error });
    }

    return reply.send({ plugin: result.plugin });
  });

  /** List creator's plugins */
  app.get<{
    Querystring: { token?: string };
  }>("/api/creator/plugins", async (request, reply) => {
    const token = request.query.token;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const pluginList = await listPlugins(token);
    return reply.send({ plugins: pluginList });
  });

  /** Get a specific plugin */
  app.get<{
    Params: { pluginId: string };
    Querystring: { token?: string };
  }>("/api/creator/plugins/:pluginId", async (request, reply) => {
    const token = request.query.token;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const plugin = await getPlugin(token, request.params.pluginId);

    if (!plugin) {
      return reply.code(404).send({ error: "plugin not found" });
    }

    return reply.send({ plugin });
  });

  /** Update a plugin */
  app.patch<{
    Params: { pluginId: string };
    Body: {
      token?: string;
      name?: string;
      description?: string;
      webhookUrl?: string | null;
      permissions?: string[];
      enabled?: boolean;
    };
  }>("/api/creator/plugins/:pluginId", async (request, reply) => {
    const { token, ...updates } = request.body;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const result = await updatePlugin(token, request.params.pluginId, updates);

    if (result.error) {
      return reply.code(result.error === "plugin not found" ? 404 : 400).send({ error: result.error });
    }

    return reply.send({ plugin: result.plugin });
  });

  /** Revoke/delete a plugin */
  app.delete<{
    Params: { pluginId: string };
    Body: { token?: string };
  }>("/api/creator/plugins/:pluginId", async (request, reply) => {
    const token = request.body.token;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const revoked = await revokePlugin(token, request.params.pluginId);

    if (!revoked) {
      return reply.code(404).send({ error: "plugin not found" });
    }

    return reply.send({ ok: true });
  });

  /** Regenerate API key for a plugin */
  app.post<{
    Params: { pluginId: string };
    Body: { token?: string };
  }>("/api/creator/plugins/:pluginId/regenerate-key", async (request, reply) => {
    const token = request.body.token;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const result = await regenerateApiKey(token, request.params.pluginId);

    if (result.error) {
      return reply.code(404).send({ error: result.error });
    }

    return reply.send({ apiKey: result.apiKey });
  });

  /** Validate an API key (for SDK consumers to test their keys) */
  app.post<{
    Body: { apiKey?: string };
  }>("/api/creator/plugins/validate-key", async (request, reply) => {
    const { apiKey } = request.body;

    if (!apiKey) {
      return reply.code(400).send({ error: "apiKey is required" });
    }

    const result = validateApiKey(apiKey);

    return reply.send({
      valid: result.valid,
      pluginId: result.plugin?.id ?? null,
      pluginName: result.plugin?.name ?? null,
      permissions: result.plugin?.permissions ?? [],
    });
  });

  // ---------------------------------------------------------------------------
  // SDK — Webhooks
  // ---------------------------------------------------------------------------

  /** Register a new webhook */
  app.post<{
    Body: {
      token?: string;
      pluginId?: string | null;
      url?: string;
      events?: string[];
    };
  }>("/api/creator/webhooks", async (request, reply) => {
    const { token, pluginId = null, url, events = [] } = request.body;

    if (!token || !url) {
      return reply.code(400).send({ error: "token and url are required" });
    }

    const result = await registerWebhook(token, { pluginId, url, events });

    if (result.error) {
      return reply.code(400).send({ error: result.error });
    }

    return reply.send({ webhook: result.webhook });
  });

  /** List creator's webhooks */
  app.get<{
    Querystring: { token?: string };
  }>("/api/creator/webhooks", async (request, reply) => {
    const token = request.query.token;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const webhookList = await listWebhooks(token);
    return reply.send({ webhooks: webhookList });
  });

  /** Update a webhook */
  app.patch<{
    Params: { webhookId: string };
    Body: {
      token?: string;
      url?: string;
      events?: string[];
      enabled?: boolean;
    };
  }>("/api/creator/webhooks/:webhookId", async (request, reply) => {
    const { token, ...updates } = request.body;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const result = await updateWebhook(token, request.params.webhookId, updates);

    if (result.error) {
      return reply.code(result.error === "webhook not found" ? 404 : 400).send({ error: result.error });
    }

    return reply.send({ webhook: result.webhook });
  });

  /** Delete a webhook */
  app.delete<{
    Params: { webhookId: string };
    Body: { token?: string };
  }>("/api/creator/webhooks/:webhookId", async (request, reply) => {
    const token = request.body.token;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const deleted = await deleteWebhook(token, request.params.webhookId);

    if (!deleted) {
      return reply.code(404).send({ error: "webhook not found" });
    }

    return reply.send({ ok: true });
  });
}
