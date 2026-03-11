// Creator Tools Service — Feature 17: Creator Tools Platform
//
// Integration notes (DO NOT auto-apply):
//   store.ts — add to barrel exports:
//     export { submitAssetForReview, listAssetReviewQueue, reviewAsset, getCreatorAnalytics,
//       getCreatorRevenue, configureRevenueSplit, listPayouts, requestPayout,
//       registerPlugin, listPlugins, revokePlugin, registerWebhook, listWebhooks,
//       deleteWebhook, fireWebhooks } from "./creator-tools-service.js";
//
//   server.ts — register the route plugin:
//     import creatorToolsRoutes from "./routes/creator-tools.js";
//     await app.register(creatorToolsRoutes);

import { randomUUID, randomBytes } from "node:crypto";
import { getSession, type Session } from "./store.js";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export type AssetSubmission = {
  id: string;
  accountId: string;
  accountDisplayName: string;
  name: string;
  description: string;
  assetType: string;
  sourceFormat: string;
  sourceUrl: string;
  thumbnailUrl: string | null;
  fileSize: number;
  status: "pending" | "approved" | "rejected" | "revision_requested";
  reviewerAccountId: string | null;
  reviewNotes: string | null;
  conversionStatus: "queued" | "converting" | "ready" | "failed";
  conversionFormat: string;
  conversionUrl: string | null;
  tags: string[];
  submittedAt: string;
  reviewedAt: string | null;
};

export type CreatorAnalytics = {
  accountId: string;
  totalAssets: number;
  approvedAssets: number;
  pendingAssets: number;
  rejectedAssets: number;
  totalViews: number;
  totalSales: number;
  totalRevenue: number;
  popularItems: Array<{
    assetId: string;
    name: string;
    views: number;
    sales: number;
    revenue: number;
  }>;
  revenueByMonth: Array<{
    month: string;
    revenue: number;
    sales: number;
  }>;
  periodStart: string;
  periodEnd: string;
};

export type RevenueSplit = {
  id: string;
  accountId: string;
  platformPercent: number;
  creatorPercent: number;
  updatedAt: string;
};

export type Payout = {
  id: string;
  accountId: string;
  amount: number;
  status: "pending" | "processing" | "completed" | "failed";
  requestedAt: string;
  completedAt: string | null;
};

export type CreatorPlugin = {
  id: string;
  accountId: string;
  name: string;
  description: string;
  apiKey: string;
  webhookUrl: string | null;
  permissions: string[];
  enabled: boolean;
  createdAt: string;
  updatedAt: string;
};

export type CreatorWebhook = {
  id: string;
  accountId: string;
  pluginId: string | null;
  url: string;
  secret: string;
  events: string[];
  enabled: boolean;
  createdAt: string;
  lastFiredAt: string | null;
  failCount: number;
};

// ---------------------------------------------------------------------------
// Validation constants
// ---------------------------------------------------------------------------

const ALLOWED_SOURCE_FORMATS = ["glb", "gltf", "blend", "fbx", "obj", "vrm"];
const ALLOWED_ASSET_TYPES = ["model", "texture", "animation", "audio", "script", "scene"];
const MAX_FILE_SIZE = 100 * 1024 * 1024; // 100 MB
const MAX_TAGS = 10;
const MAX_PLUGINS_PER_ACCOUNT = 20;
const MAX_WEBHOOKS_PER_ACCOUNT = 50;
const DEFAULT_PLATFORM_PERCENT = 10;
const DEFAULT_CREATOR_PERCENT = 90;
const MIN_PAYOUT_AMOUNT = 100;
const WEBHOOK_EVENTS = [
  "asset.submitted",
  "asset.approved",
  "asset.rejected",
  "asset.sold",
  "payout.completed",
  "plugin.enabled",
  "plugin.disabled",
];

// ---------------------------------------------------------------------------
// In-memory stores
// ---------------------------------------------------------------------------

const assetSubmissions = new Map<string, AssetSubmission>();
const creatorRevenueSplits = new Map<string, RevenueSplit>();
const payouts = new Map<string, Payout>();
const plugins = new Map<string, CreatorPlugin>();
const webhooks = new Map<string, CreatorWebhook>();

// Per-asset analytics counters (assetId -> { views, sales, revenue })
const assetStats = new Map<string, { views: number; sales: number; revenue: number }>();

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function generateApiKey(): string {
  return `vl_${randomBytes(24).toString("hex")}`;
}

function generateWebhookSecret(): string {
  return `whsec_${randomBytes(32).toString("hex")}`;
}

function validateSourceFormat(format: string): boolean {
  return ALLOWED_SOURCE_FORMATS.includes(format.toLowerCase());
}

function validateAssetType(assetType: string): boolean {
  return ALLOWED_ASSET_TYPES.includes(assetType.toLowerCase());
}

function currentIso(): string {
  return new Date().toISOString();
}

function getMonthKey(date: Date): string {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}`;
}

function isAdminSession(session: Session): boolean {
  return session.role === "admin";
}

// ---------------------------------------------------------------------------
// Asset Pipeline — Submit, Validate, Convert Status
// ---------------------------------------------------------------------------

export async function submitAssetForReview(
  token: string,
  input: {
    name: string;
    description: string;
    assetType: string;
    sourceFormat: string;
    sourceUrl: string;
    thumbnailUrl?: string | null;
    fileSize: number;
    tags?: string[];
  }
): Promise<{ submission?: AssetSubmission; error?: string }> {
  const session = getSession(token);
  if (!session) return { error: "invalid session" };

  // Validate asset type
  if (!validateAssetType(input.assetType)) {
    return { error: `invalid assetType; allowed: ${ALLOWED_ASSET_TYPES.join(", ")}` };
  }

  // Validate source format
  if (!validateSourceFormat(input.sourceFormat)) {
    return { error: `invalid sourceFormat; allowed: ${ALLOWED_SOURCE_FORMATS.join(", ")}` };
  }

  // Validate file size
  if (input.fileSize <= 0 || input.fileSize > MAX_FILE_SIZE) {
    return { error: `fileSize must be between 1 and ${MAX_FILE_SIZE} bytes` };
  }

  // Validate name
  const name = (input.name ?? "").trim().slice(0, 128);
  if (!name) {
    return { error: "name is required" };
  }

  // Validate tags
  const tags = (input.tags ?? []).slice(0, MAX_TAGS).map((t) => t.trim().slice(0, 32).toLowerCase()).filter(Boolean);

  // Determine conversion format based on source
  const conversionFormat = input.sourceFormat === "glb" ? "glb" : "glb"; // all non-glb convert to glb

  const submission: AssetSubmission = {
    id: randomUUID(),
    accountId: session.accountId,
    accountDisplayName: session.displayName,
    name,
    description: (input.description ?? "").trim().slice(0, 1024),
    assetType: input.assetType.toLowerCase(),
    sourceFormat: input.sourceFormat.toLowerCase(),
    sourceUrl: input.sourceUrl,
    thumbnailUrl: input.thumbnailUrl ?? null,
    fileSize: input.fileSize,
    status: "pending",
    reviewerAccountId: null,
    reviewNotes: null,
    conversionStatus: input.sourceFormat.toLowerCase() === "glb" ? "ready" : "queued",
    conversionFormat,
    conversionUrl: input.sourceFormat.toLowerCase() === "glb" ? input.sourceUrl : null,
    tags,
    submittedAt: currentIso(),
    reviewedAt: null,
  };

  assetSubmissions.set(submission.id, submission);

  // Simulate async conversion for non-glb formats
  if (submission.conversionStatus === "queued") {
    simulateConversion(submission.id);
  }

  await fireWebhooks("asset.submitted", {
    submissionId: submission.id,
    accountId: session.accountId,
    name: submission.name,
    assetType: submission.assetType,
  });

  return { submission };
}

function simulateConversion(submissionId: string): void {
  const submission = assetSubmissions.get(submissionId);
  if (!submission) return;

  // Mark as converting immediately
  submission.conversionStatus = "converting";
  assetSubmissions.set(submissionId, submission);

  // Simulate conversion completion after a short delay
  setTimeout(() => {
    const sub = assetSubmissions.get(submissionId);
    if (!sub || sub.conversionStatus !== "converting") return;

    sub.conversionStatus = "ready";
    sub.conversionUrl = sub.sourceUrl.replace(/\.[^.]+$/, ".glb");
    assetSubmissions.set(submissionId, sub);
  }, 2000);
}

export async function getSubmission(token: string, submissionId: string): Promise<AssetSubmission | undefined> {
  const session = getSession(token);
  if (!session) return undefined;

  const submission = assetSubmissions.get(submissionId);
  if (!submission) return undefined;

  // Creators can see their own; admins can see all
  if (submission.accountId !== session.accountId && !isAdminSession(session)) {
    return undefined;
  }

  return submission;
}

export async function listCreatorSubmissions(token: string): Promise<AssetSubmission[]> {
  const session = getSession(token);
  if (!session) return [];

  return [...assetSubmissions.values()]
    .filter((s) => s.accountId === session.accountId)
    .sort((a, b) => b.submittedAt.localeCompare(a.submittedAt));
}

// ---------------------------------------------------------------------------
// Asset Review and Approval Process
// ---------------------------------------------------------------------------

export async function listAssetReviewQueue(token: string, statusFilter?: string): Promise<AssetSubmission[] | undefined> {
  const session = getSession(token);
  if (!session || !isAdminSession(session)) return undefined;

  let queue = [...assetSubmissions.values()];

  if (statusFilter && ["pending", "approved", "rejected", "revision_requested"].includes(statusFilter)) {
    queue = queue.filter((s) => s.status === statusFilter);
  }

  return queue.sort((a, b) => a.submittedAt.localeCompare(b.submittedAt));
}

export async function reviewAsset(
  token: string,
  submissionId: string,
  decision: "approved" | "rejected" | "revision_requested",
  notes?: string
): Promise<{ submission?: AssetSubmission; error?: string }> {
  const session = getSession(token);
  if (!session || !isAdminSession(session)) {
    return { error: "admin access required" };
  }

  const submission = assetSubmissions.get(submissionId);
  if (!submission) {
    return { error: "submission not found" };
  }

  submission.status = decision;
  submission.reviewerAccountId = session.accountId;
  submission.reviewNotes = (notes ?? "").trim().slice(0, 1024) || null;
  submission.reviewedAt = currentIso();

  assetSubmissions.set(submissionId, submission);

  const eventType = decision === "approved" ? "asset.approved" : "asset.rejected";
  await fireWebhooks(eventType, {
    submissionId: submission.id,
    accountId: submission.accountId,
    name: submission.name,
    decision,
    reviewerAccountId: session.accountId,
  });

  return { submission };
}

// ---------------------------------------------------------------------------
// Creator Analytics Dashboard
// ---------------------------------------------------------------------------

export function recordAssetView(assetId: string): void {
  const stats = assetStats.get(assetId) ?? { views: 0, sales: 0, revenue: 0 };
  stats.views += 1;
  assetStats.set(assetId, stats);
}

export function recordAssetSale(assetId: string, amount: number): void {
  const stats = assetStats.get(assetId) ?? { views: 0, sales: 0, revenue: 0 };
  stats.sales += 1;
  stats.revenue += amount;
  assetStats.set(assetId, stats);
}

export async function getCreatorAnalytics(
  token: string,
  periodDays: number = 30
): Promise<CreatorAnalytics | undefined> {
  const session = getSession(token);
  if (!session) return undefined;

  const accountId = session.accountId;
  const submissions = [...assetSubmissions.values()].filter((s) => s.accountId === accountId);

  const approvedIds = new Set(submissions.filter((s) => s.status === "approved").map((s) => s.id));

  let totalViews = 0;
  let totalSales = 0;
  let totalRevenue = 0;

  const popularItems: CreatorAnalytics["popularItems"] = [];

  for (const sub of submissions) {
    const stats = assetStats.get(sub.id) ?? { views: 0, sales: 0, revenue: 0 };
    totalViews += stats.views;
    totalSales += stats.sales;
    totalRevenue += stats.revenue;

    popularItems.push({
      assetId: sub.id,
      name: sub.name,
      views: stats.views,
      sales: stats.sales,
      revenue: stats.revenue,
    });
  }

  // Sort popular items by revenue descending, then sales, then views
  popularItems.sort((a, b) => b.revenue - a.revenue || b.sales - a.sales || b.views - a.views);

  // Build revenue-by-month for the period
  const now = new Date();
  const periodStart = new Date(now.getTime() - periodDays * 24 * 60 * 60 * 1000);
  const monthBuckets = new Map<string, { revenue: number; sales: number }>();

  // Initialize month buckets for the period
  const cursor = new Date(periodStart);
  cursor.setDate(1);
  while (cursor <= now) {
    const key = getMonthKey(cursor);
    monthBuckets.set(key, { revenue: 0, sales: 0 });
    cursor.setMonth(cursor.getMonth() + 1);
  }

  // Distribute total revenue/sales into current month (simplified — real impl would track per-transaction dates)
  const currentMonth = getMonthKey(now);
  const bucket = monthBuckets.get(currentMonth);
  if (bucket) {
    bucket.revenue = totalRevenue;
    bucket.sales = totalSales;
  }

  const revenueByMonth = [...monthBuckets.entries()].map(([month, data]) => ({
    month,
    revenue: data.revenue,
    sales: data.sales,
  }));

  return {
    accountId,
    totalAssets: submissions.length,
    approvedAssets: submissions.filter((s) => s.status === "approved").length,
    pendingAssets: submissions.filter((s) => s.status === "pending").length,
    rejectedAssets: submissions.filter((s) => s.status === "rejected").length,
    totalViews,
    totalSales,
    totalRevenue,
    popularItems: popularItems.slice(0, 20),
    revenueByMonth,
    periodStart: periodStart.toISOString(),
    periodEnd: now.toISOString(),
  };
}

// ---------------------------------------------------------------------------
// Revenue Sharing for Marketplace Creators
// ---------------------------------------------------------------------------

export async function getCreatorRevenue(token: string): Promise<{
  split: RevenueSplit;
  pendingPayout: number;
  lifetimeEarnings: number;
  payouts: Payout[];
} | undefined> {
  const session = getSession(token);
  if (!session) return undefined;

  const split = getOrCreateRevenueSplit(session.accountId);

  // Calculate earnings from asset stats
  const submissions = [...assetSubmissions.values()].filter((s) => s.accountId === session.accountId);
  let lifetimeEarnings = 0;
  for (const sub of submissions) {
    const stats = assetStats.get(sub.id) ?? { views: 0, sales: 0, revenue: 0 };
    lifetimeEarnings += stats.revenue * (split.creatorPercent / 100);
  }

  // Calculate already-paid-out amount
  const accountPayouts = [...payouts.values()]
    .filter((p) => p.accountId === session.accountId)
    .sort((a, b) => b.requestedAt.localeCompare(a.requestedAt));

  const paidOut = accountPayouts
    .filter((p) => p.status === "completed")
    .reduce((sum, p) => sum + p.amount, 0);

  const pendingPayout = Math.max(0, lifetimeEarnings - paidOut);

  return {
    split,
    pendingPayout: Math.round(pendingPayout * 100) / 100,
    lifetimeEarnings: Math.round(lifetimeEarnings * 100) / 100,
    payouts: accountPayouts,
  };
}

function getOrCreateRevenueSplit(accountId: string): RevenueSplit {
  let split = creatorRevenueSplits.get(accountId);
  if (!split) {
    split = {
      id: randomUUID(),
      accountId,
      platformPercent: DEFAULT_PLATFORM_PERCENT,
      creatorPercent: DEFAULT_CREATOR_PERCENT,
      updatedAt: currentIso(),
    };
    creatorRevenueSplits.set(accountId, split);
  }
  return split;
}

export async function configureRevenueSplit(
  token: string,
  targetAccountId: string,
  platformPercent: number,
  creatorPercent: number
): Promise<{ split?: RevenueSplit; error?: string }> {
  const session = getSession(token);
  if (!session || !isAdminSession(session)) {
    return { error: "admin access required" };
  }

  if (platformPercent < 0 || creatorPercent < 0 || platformPercent + creatorPercent !== 100) {
    return { error: "platformPercent + creatorPercent must equal 100" };
  }

  const split = getOrCreateRevenueSplit(targetAccountId);
  split.platformPercent = platformPercent;
  split.creatorPercent = creatorPercent;
  split.updatedAt = currentIso();
  creatorRevenueSplits.set(targetAccountId, split);

  return { split };
}

export async function listPayouts(token: string): Promise<Payout[]> {
  const session = getSession(token);
  if (!session) return [];

  return [...payouts.values()]
    .filter((p) => p.accountId === session.accountId)
    .sort((a, b) => b.requestedAt.localeCompare(a.requestedAt));
}

export async function requestPayout(
  token: string,
  amount: number
): Promise<{ payout?: Payout; error?: string }> {
  const session = getSession(token);
  if (!session) return { error: "invalid session" };

  if (amount < MIN_PAYOUT_AMOUNT) {
    return { error: `minimum payout amount is ${MIN_PAYOUT_AMOUNT}` };
  }

  // Verify they have enough pending
  const revenueData = await getCreatorRevenue(token);
  if (!revenueData || revenueData.pendingPayout < amount) {
    return { error: "insufficient pending payout balance" };
  }

  // Check for already-pending payouts
  const hasPending = [...payouts.values()].some(
    (p) => p.accountId === session.accountId && (p.status === "pending" || p.status === "processing")
  );
  if (hasPending) {
    return { error: "a payout is already in progress" };
  }

  const payout: Payout = {
    id: randomUUID(),
    accountId: session.accountId,
    amount,
    status: "pending",
    requestedAt: currentIso(),
    completedAt: null,
  };

  payouts.set(payout.id, payout);

  // Simulate payout processing
  simulatePayoutProcessing(payout.id);

  return { payout };
}

function simulatePayoutProcessing(payoutId: string): void {
  setTimeout(() => {
    const payout = payouts.get(payoutId);
    if (!payout || payout.status !== "pending") return;
    payout.status = "processing";
    payouts.set(payoutId, payout);

    setTimeout(async () => {
      const p = payouts.get(payoutId);
      if (!p || p.status !== "processing") return;
      p.status = "completed";
      p.completedAt = currentIso();
      payouts.set(payoutId, p);

      await fireWebhooks("payout.completed", {
        payoutId: p.id,
        accountId: p.accountId,
        amount: p.amount,
      });
    }, 3000);
  }, 2000);
}

// ---------------------------------------------------------------------------
// SDK — Plugin Registry, API Keys, Webhooks
// ---------------------------------------------------------------------------

export async function registerPlugin(
  token: string,
  input: {
    name: string;
    description?: string;
    webhookUrl?: string | null;
    permissions?: string[];
  }
): Promise<{ plugin?: CreatorPlugin; error?: string }> {
  const session = getSession(token);
  if (!session) return { error: "invalid session" };

  const name = (input.name ?? "").trim().slice(0, 64);
  if (!name) {
    return { error: "plugin name is required" };
  }

  // Check plugin limit
  const accountPlugins = [...plugins.values()].filter((p) => p.accountId === session.accountId);
  if (accountPlugins.length >= MAX_PLUGINS_PER_ACCOUNT) {
    return { error: `maximum ${MAX_PLUGINS_PER_ACCOUNT} plugins per account` };
  }

  // Check for duplicate name per account
  if (accountPlugins.some((p) => p.name.toLowerCase() === name.toLowerCase())) {
    return { error: "plugin name already exists for this account" };
  }

  const allowedPermissions = ["read:assets", "write:assets", "read:analytics", "read:revenue", "manage:webhooks"];
  const permissions = (input.permissions ?? ["read:assets"])
    .filter((p) => allowedPermissions.includes(p));

  const plugin: CreatorPlugin = {
    id: randomUUID(),
    accountId: session.accountId,
    name,
    description: (input.description ?? "").trim().slice(0, 256),
    apiKey: generateApiKey(),
    webhookUrl: input.webhookUrl ?? null,
    permissions,
    enabled: true,
    createdAt: currentIso(),
    updatedAt: currentIso(),
  };

  plugins.set(plugin.id, plugin);

  await fireWebhooks("plugin.enabled", {
    pluginId: plugin.id,
    accountId: session.accountId,
    name: plugin.name,
  });

  return { plugin };
}

export async function listPlugins(token: string): Promise<CreatorPlugin[]> {
  const session = getSession(token);
  if (!session) return [];

  return [...plugins.values()]
    .filter((p) => p.accountId === session.accountId)
    .sort((a, b) => b.createdAt.localeCompare(a.createdAt));
}

export async function getPlugin(token: string, pluginId: string): Promise<CreatorPlugin | undefined> {
  const session = getSession(token);
  if (!session) return undefined;

  const plugin = plugins.get(pluginId);
  if (!plugin || plugin.accountId !== session.accountId) return undefined;

  return plugin;
}

export async function updatePlugin(
  token: string,
  pluginId: string,
  updates: {
    name?: string;
    description?: string;
    webhookUrl?: string | null;
    permissions?: string[];
    enabled?: boolean;
  }
): Promise<{ plugin?: CreatorPlugin; error?: string }> {
  const session = getSession(token);
  if (!session) return { error: "invalid session" };

  const plugin = plugins.get(pluginId);
  if (!plugin || plugin.accountId !== session.accountId) {
    return { error: "plugin not found" };
  }

  if (updates.name !== undefined) {
    const name = updates.name.trim().slice(0, 64);
    if (!name) return { error: "plugin name cannot be empty" };
    plugin.name = name;
  }

  if (updates.description !== undefined) {
    plugin.description = updates.description.trim().slice(0, 256);
  }

  if (updates.webhookUrl !== undefined) {
    plugin.webhookUrl = updates.webhookUrl;
  }

  if (updates.permissions !== undefined) {
    const allowedPermissions = ["read:assets", "write:assets", "read:analytics", "read:revenue", "manage:webhooks"];
    plugin.permissions = updates.permissions.filter((p) => allowedPermissions.includes(p));
  }

  if (updates.enabled !== undefined) {
    const wasEnabled = plugin.enabled;
    plugin.enabled = updates.enabled;
    if (wasEnabled && !updates.enabled) {
      await fireWebhooks("plugin.disabled", { pluginId: plugin.id, accountId: session.accountId, name: plugin.name });
    } else if (!wasEnabled && updates.enabled) {
      await fireWebhooks("plugin.enabled", { pluginId: plugin.id, accountId: session.accountId, name: plugin.name });
    }
  }

  plugin.updatedAt = currentIso();
  plugins.set(pluginId, plugin);

  return { plugin };
}

export async function revokePlugin(token: string, pluginId: string): Promise<boolean> {
  const session = getSession(token);
  if (!session) return false;

  const plugin = plugins.get(pluginId);
  if (!plugin || plugin.accountId !== session.accountId) return false;

  // Remove associated webhooks
  for (const [whId, wh] of webhooks) {
    if (wh.pluginId === pluginId) {
      webhooks.delete(whId);
    }
  }

  plugins.delete(pluginId);

  await fireWebhooks("plugin.disabled", {
    pluginId: plugin.id,
    accountId: session.accountId,
    name: plugin.name,
  });

  return true;
}

export async function regenerateApiKey(token: string, pluginId: string): Promise<{ apiKey?: string; error?: string }> {
  const session = getSession(token);
  if (!session) return { error: "invalid session" };

  const plugin = plugins.get(pluginId);
  if (!plugin || plugin.accountId !== session.accountId) {
    return { error: "plugin not found" };
  }

  plugin.apiKey = generateApiKey();
  plugin.updatedAt = currentIso();
  plugins.set(pluginId, plugin);

  return { apiKey: plugin.apiKey };
}

// ---------------------------------------------------------------------------
// Webhooks
// ---------------------------------------------------------------------------

export async function registerWebhook(
  token: string,
  input: {
    pluginId?: string | null;
    url: string;
    events: string[];
  }
): Promise<{ webhook?: CreatorWebhook; error?: string }> {
  const session = getSession(token);
  if (!session) return { error: "invalid session" };

  const url = (input.url ?? "").trim();
  if (!url) {
    return { error: "webhook url is required" };
  }

  // Validate events
  const events = (input.events ?? []).filter((e) => WEBHOOK_EVENTS.includes(e));
  if (events.length === 0) {
    return { error: `at least one valid event required; available: ${WEBHOOK_EVENTS.join(", ")}` };
  }

  // Check plugin ownership if pluginId specified
  if (input.pluginId) {
    const plugin = plugins.get(input.pluginId);
    if (!plugin || plugin.accountId !== session.accountId) {
      return { error: "plugin not found" };
    }
  }

  // Check webhook limit
  const accountWebhooks = [...webhooks.values()].filter((w) => w.accountId === session.accountId);
  if (accountWebhooks.length >= MAX_WEBHOOKS_PER_ACCOUNT) {
    return { error: `maximum ${MAX_WEBHOOKS_PER_ACCOUNT} webhooks per account` };
  }

  const webhook: CreatorWebhook = {
    id: randomUUID(),
    accountId: session.accountId,
    pluginId: input.pluginId ?? null,
    url,
    secret: generateWebhookSecret(),
    events,
    enabled: true,
    createdAt: currentIso(),
    lastFiredAt: null,
    failCount: 0,
  };

  webhooks.set(webhook.id, webhook);

  return { webhook };
}

export async function listWebhooks(token: string): Promise<CreatorWebhook[]> {
  const session = getSession(token);
  if (!session) return [];

  return [...webhooks.values()]
    .filter((w) => w.accountId === session.accountId)
    .sort((a, b) => b.createdAt.localeCompare(a.createdAt));
}

export async function updateWebhook(
  token: string,
  webhookId: string,
  updates: {
    url?: string;
    events?: string[];
    enabled?: boolean;
  }
): Promise<{ webhook?: CreatorWebhook; error?: string }> {
  const session = getSession(token);
  if (!session) return { error: "invalid session" };

  const webhook = webhooks.get(webhookId);
  if (!webhook || webhook.accountId !== session.accountId) {
    return { error: "webhook not found" };
  }

  if (updates.url !== undefined) {
    const url = updates.url.trim();
    if (!url) return { error: "webhook url cannot be empty" };
    webhook.url = url;
  }

  if (updates.events !== undefined) {
    const events = updates.events.filter((e) => WEBHOOK_EVENTS.includes(e));
    if (events.length === 0) return { error: "at least one valid event is required" };
    webhook.events = events;
  }

  if (updates.enabled !== undefined) {
    webhook.enabled = updates.enabled;
  }

  webhooks.set(webhookId, webhook);

  return { webhook };
}

export async function deleteWebhook(token: string, webhookId: string): Promise<boolean> {
  const session = getSession(token);
  if (!session) return false;

  const webhook = webhooks.get(webhookId);
  if (!webhook || webhook.accountId !== session.accountId) return false;

  webhooks.delete(webhookId);
  return true;
}

export async function fireWebhooks(event: string, payload: Record<string, unknown>): Promise<void> {
  const matchingWebhooks = [...webhooks.values()].filter(
    (w) => w.enabled && w.events.includes(event)
  );

  for (const wh of matchingWebhooks) {
    wh.lastFiredAt = currentIso();
    webhooks.set(wh.id, wh);

    // In production, this would POST to wh.url with the payload and HMAC signature.
    // For the in-memory prototype, we log the delivery intent.
    try {
      // Simulated delivery — real implementation would use fetch() with
      // HMAC-SHA256 signature in X-VibeLife-Signature header using wh.secret
      console.log(`[webhook] ${event} -> ${wh.url} (webhook ${wh.id})`);
    } catch {
      wh.failCount += 1;
      if (wh.failCount >= 10) {
        wh.enabled = false;
      }
      webhooks.set(wh.id, wh);
    }
  }
}

// ---------------------------------------------------------------------------
// Utility: Validate API Key (for SDK consumers)
// ---------------------------------------------------------------------------

export function validateApiKey(apiKey: string): { valid: boolean; plugin?: CreatorPlugin } {
  for (const plugin of plugins.values()) {
    if (plugin.apiKey === apiKey && plugin.enabled) {
      return { valid: true, plugin };
    }
  }
  return { valid: false };
}
