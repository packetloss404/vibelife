import path from "node:path";
import { fileURLToPath } from "node:url";
import Fastify from "fastify";
import cors from "@fastify/cors";
import fastifyStatic from "@fastify/static";
import rateLimit from "@fastify/rate-limit";
import {
  getPersistenceMode,
  initializeWorldStore,
} from "./world/store.js";

import authRoutes from "./routes/auth.js";
import regionRoutes from "./routes/regions.js";
import objectRoutes from "./routes/objects.js";
import socialRoutes from "./routes/social.js";
import economyRoutes from "./routes/economy.js";
import adminRoutes from "./routes/admin.js";
import parcelRoutes from "./routes/parcels.js";
import radioRoutes from "./routes/radio.js";
import emoteRoutes from "./routes/emotes.js";
import chatRoutes from "./routes/chat.js";
import avatarRoutes from "./routes/avatar.js";
import assetRoutes from "./routes/assets.js";
import { blueprintRoutes } from "./routes/blueprints.js";
import { registerGuildRoutes } from "./routes/guilds.js";
import { registerPresenceRoutes } from "./routes/presence.js";
import { registerActivityRoutes } from "./routes/activity.js";
import { registerMarketplaceRoutes } from "./routes/marketplace.js";
import { homeRoutes } from "./routes/homes.js";
import { homeRatingRoutes } from "./routes/home-ratings.js";
import { registerStorefrontRoutes } from "./routes/storefronts.js";
import { registerAchievementRoutes } from "./routes/achievements.js";
import scriptsPlugin from "./routes/scripts.js";
import interactivesRoutes from "./routes/interactives.js";
import voiceRoutes from "./routes/voice.js";
import { registerVoiceStatusRoutes } from "./routes/voice-status.js";
import petRoutes from "./routes/pets.js";
import photosRoutes from "./routes/photos.js";
import mediaRoutes from "./routes/media.js";
import seasonalRoutes from "./routes/seasonal.js";
import mobileRoutes from "./routes/mobile.js";
import creatorToolsRoutes from "./routes/creator-tools.js";
import { federationRoutes } from "./routes/federation.js";
import npcRoutes from "./routes/npcs.js";
import {
  createEvent,
  listEvents,
  getEvent,
  rsvpEvent,
  cancelEvent,
  listUpcomingEvents,
  getEventAttendees,
  checkEventTransitions,
  getEventLeaderboard,
  type GameEventType
} from "./world/event-service.js";

const app = Fastify({ logger: true });
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const publicDir = path.resolve(__dirname, "../public");

await initializeWorldStore();

const allowedOrigins = process.env.CORS_ORIGINS
  ? process.env.CORS_ORIGINS.split(",").map((o) => o.trim())
  : ["http://localhost:3000", "http://127.0.0.1:3000"];

await app.register(cors, {
  origin: (origin, cb) => {
    if (!origin || allowedOrigins.includes(origin)) {
      cb(null, true);
    } else {
      cb(new Error("CORS origin not allowed"), false);
    }
  }
});

await app.register(rateLimit, {
  max: 60,
  timeWindow: "1 minute"
});

await app.register(fastifyStatic, {
  root: publicDir,
  prefix: "/",
  wildcard: false
});

// ── Health ──────────────────────────────────────────────────────────────────

app.get("/api/health", async () => ({
  ok: true,
  now: new Date().toISOString(),
  stack: "Fastify sidecar for Paper + Fabric",
  persistence: getPersistenceMode()
}));

// ── Route Plugins ───────────────────────────────────────────────────────────

await app.register(authRoutes);
await app.register(regionRoutes);
await app.register(objectRoutes);
await app.register(socialRoutes);
await app.register(economyRoutes);
await app.register(adminRoutes);
await app.register(parcelRoutes);
await app.register(radioRoutes);
await app.register(emoteRoutes);
await app.register(chatRoutes);
await app.register(avatarRoutes);
await app.register(assetRoutes);
await app.register(blueprintRoutes);

// ── Tier 2 Route Plugins ──────────────────────────────────────────────────
await registerGuildRoutes(app);
await registerPresenceRoutes(app);
await registerActivityRoutes(app);
await registerMarketplaceRoutes(app);
await app.register(homeRoutes);
await app.register(homeRatingRoutes);
await registerStorefrontRoutes(app);
await registerAchievementRoutes(app);

// ── Tier 3 Route Plugins ──────────────────────────────────────────────────
await app.register(scriptsPlugin);
await app.register(interactivesRoutes);
await app.register(voiceRoutes);
registerVoiceStatusRoutes(app);
await app.register(petRoutes);
await app.register(photosRoutes);
await app.register(mediaRoutes);
await app.register(seasonalRoutes);

// ── Tier 4 Route Plugins ──────────────────────────────────────────────────
await app.register(mobileRoutes);
await app.register(creatorToolsRoutes);
await app.register(federationRoutes);
await app.register(npcRoutes);

// ── Events System ──────────────────────────────────────────────────────────

app.post<{ Body: { token?: string; name?: string; description?: string; regionId?: string; parcelId?: string; eventType?: string; startTime?: string; endTime?: string; recurring?: string; maxAttendees?: number; prizes?: string } }>("/api/events", async (request, reply) => {
  const { token, name, description = "", regionId, parcelId, eventType, startTime, endTime, recurring, maxAttendees, prizes } = request.body;
  if (!token || !name || !regionId || !eventType || !startTime || !endTime) {
    return reply.code(400).send({ error: "token, name, regionId, eventType, startTime, and endTime are required" });
  }
  const validTypes: GameEventType[] = ["build_competition", "dance_party", "grand_opening", "workshop", "meetup", "concert", "market_day", "exploration"];
  if (!validTypes.includes(eventType as GameEventType)) {
    return reply.code(400).send({ error: "invalid eventType" });
  }
  const event = createEvent(token, { name, description, regionId, parcelId, eventType: eventType as GameEventType, startTime, endTime, recurring: (recurring as "daily" | "weekly" | "monthly") ?? null, maxAttendees, prizes });
  if (!event) return reply.code(403).send({ error: "failed to create event" });
  return reply.send({ event });
});

app.get<{ Querystring: { regionId?: string; upcoming?: string } }>("/api/events", async (request, reply) => {
  const { regionId, upcoming } = request.query;
  const events = listEvents(regionId, upcoming === "true");
  return reply.send({ events });
});

app.get<{ Querystring: { limit?: string } }>("/api/events/upcoming", async (request, reply) => {
  const limit = Math.max(1, Math.min(50, Number(request.query.limit ?? 10)));
  const events = listUpcomingEvents(limit);
  return reply.send({ events });
});

app.get("/api/events/leaderboard", async (_request, reply) => {
  const leaderboard = getEventLeaderboard();
  return reply.send(leaderboard);
});

app.get<{ Params: { id: string } }>("/api/events/:id", async (request, reply) => {
  const event = getEvent(request.params.id);
  if (!event) return reply.code(404).send({ error: "event not found" });
  return reply.send({ event });
});

app.post<{ Params: { id: string }; Body: { token?: string } }>("/api/events/:id/rsvp", async (request, reply) => {
  const { token } = request.body;
  if (!token) return reply.code(400).send({ error: "token is required" });
  const event = rsvpEvent(token, request.params.id);
  if (!event) return reply.code(404).send({ error: "event not found or at capacity" });
  return reply.send({ event });
});

app.delete<{ Params: { id: string }; Body: { token?: string } }>("/api/events/:id", async (request, reply) => {
  const { token } = request.body;
  if (!token) return reply.code(400).send({ error: "token is required" });
  const cancelled = cancelEvent(token, request.params.id);
  if (!cancelled) return reply.code(403).send({ error: "event not found or not authorized" });
  return reply.send({ ok: true });
});

app.get<{ Params: { id: string } }>("/api/events/:id/attendees", async (request, reply) => {
  const attendees = getEventAttendees(request.params.id);
  return reply.send({ attendees });
});

// Event transition checker (runs every 15 seconds)
setInterval(() => {
  checkEventTransitions();
}, 15_000);

// ── Start ───────────────────────────────────────────────────────────────────

const port = Number(process.env.PORT ?? 3000);

try {
  await app.listen({ port, host: "0.0.0.0" });
} catch (error) {
  app.log.error(error);
  process.exit(1);
}
