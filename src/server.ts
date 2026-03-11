import path from "node:path";
import { fileURLToPath } from "node:url";
import Fastify from "fastify";
import cors from "@fastify/cors";
import websocket from "@fastify/websocket";
import fastifyStatic from "@fastify/static";
import rateLimit from "@fastify/rate-limit";
import { isRegionCommand, type ChatChannel } from "./contracts.js";
import {
  handleRadioTune,
  handleRadioSkip,
  handleEmote
} from "./world/store.js";
import {
  getChatHistory,
  getRegionPopulation,
  getSession,
  getPersistenceMode,
  handleChatMessage,
  handleWhisper,
  initializeWorldStore,
  listParcels,
  listRegionObjects,
  moveAvatar,
  removeAvatar
} from "./world/store.js";
import { broadcastRegion, broadcastRegionLocal, getRegionSequence, joinRegion, leaveRegion, nextRegionSequence, sendToAvatar, sendToAvatars } from "./world/region.js";

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
import { recordEmote } from "./world/emote-service.js";
import { registerGuildRoutes } from "./routes/guilds.js";
import { registerPresenceRoutes } from "./routes/presence.js";
import { registerActivityRoutes } from "./routes/activity.js";
import { registerMarketplaceRoutes } from "./routes/marketplace.js";
import { homeRoutes } from "./routes/homes.js";
import { homeRatingRoutes } from "./routes/home-ratings.js";
import { registerStorefrontRoutes } from "./routes/storefronts.js";
import { registerAchievementRoutes } from "./routes/achievements.js";
import {
  setPresenceOnLogin,
  setPresenceOnDisconnect,
  updateLastActivity,
  updatePresenceRegion,
} from "./world/presence-service.js";
import { postActivity } from "./world/activity-service.js";
import { findHomeParcelOwner, shouldRingDoorbell, checkHomeAccess } from "./world/home-service.js";
import { onObjectPlaced, onChatMessage, onFriendAdded, onRegionVisited } from "./world/achievement-service.js";
import scriptsPlugin from "./routes/scripts.js";
import interactivesRoutes from "./routes/interactives.js";
import voiceRoutes from "./routes/voice.js";
import { registerVoiceStatusRoutes } from "./routes/voice-status.js";
import petRoutes from "./routes/pets.js";
import photosRoutes from "./routes/photos.js";
import mediaRoutes from "./routes/media.js";
import seasonalRoutes from "./routes/seasonal.js";
import { cleanupVoiceForAccount } from "./world/voice-service.js";
import { removeAccountFromVoice } from "./world/voice-indicator-service.js";
import mobileRoutes from "./routes/mobile.js";
import creatorToolsRoutes from "./routes/creator-tools.js";
import { federationRoutes } from "./routes/federation.js";
import npcRoutes from "./routes/npcs.js";
import vrRoutes from "./routes/vr.js";
import { startNpcTickLoop } from "./world/npc-service.js";
import { startEnemyTickLoop } from "./world/enemy-service.js";
import { attackEnemy, getEnemiesInRegion } from "./world/enemy-service.js";
import { setBlock, getVoxelPermission } from "./world/store.js";
import { getOrCreateStats, regenTick } from "./world/combat-service.js";
import { avatarsByRegion } from "./world/_shared-state.js";
import { onBlockPlaced, onBlockBroken, onEnemyDefeated, onCombatLevelUp } from "./world/achievement-service.js";
import voxelRoutes from "./routes/voxels.js";
import combatRoutes from "./routes/combat.js";
import voxelShopRoutes from "./routes/voxel-shop.js";
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
const threeDir = path.resolve(__dirname, "../node_modules/three");

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

await app.register(websocket);
await app.register(fastifyStatic, {
  root: publicDir,
  prefix: "/",
  wildcard: false
});
await app.register(fastifyStatic, {
  root: threeDir,
  prefix: "/vendor/three/",
  decorateReply: false,
  wildcard: false
});

// ── Health ──────────────────────────────────────────────────────────────────

app.get("/api/health", async () => ({
  ok: true,
  now: new Date().toISOString(),
  stack: "Fastify + WebSocket region prototype",
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
await app.register(vrRoutes);

// ── Tier 5 Route Plugins (Voxel MMORPG) ──────────────────────────────
await app.register(voxelRoutes);
await app.register(combatRoutes);
await app.register(voxelShopRoutes);

// Start NPC AI tick loop
startNpcTickLoop();

// Start enemy AI tick loop (1s interval, separate from NPC 2s tick)
startEnemyTickLoop();

// HP/Mana regen tick for combat (1s interval)
setInterval(() => {
  for (const [, regionAvatars] of avatarsByRegion) {
    for (const avatar of regionAvatars.values()) {
      regenTick(avatar.accountId);
    }
  }
}, 1000);

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
  const { started, ended } = checkEventTransitions();
  for (const s of started) {
    broadcastRegion(s.regionId, { type: "event:started", sequence: nextRegionSequence(s.regionId), event: s.event });
  }
  for (const e of ended) {
    broadcastRegion(e.regionId, { type: "event:ended", sequence: nextRegionSequence(e.regionId), eventId: e.eventId });
  }
}, 15_000);

// Track which avatars are sitting: avatarId -> objectId
const sittingAvatars = new Map<string, string>();

// ── WebSocket ───────────────────────────────────────────────────────────────

app.get("/ws/regions/:regionId", { websocket: true }, async (socket, request) => {
  const { token, lastSequence } = request.query as { token?: string; lastSequence?: string };

  if (!token) {
    socket.close(1008, "Missing token");
    return;
  }

  const session = getSession(token);
  const regionId = (request.params as { regionId: string }).regionId;

  if (!session || session.regionId !== regionId) {
    socket.close(1008, "Invalid session");
    return;
  }

  joinRegion(regionId, session.avatarId, socket);

  // Achievement + presence hooks on WebSocket join
  onRegionVisited(session.accountId, regionId);
  setPresenceOnLogin(session.accountId, session.displayName, regionId);

  const enemiesInRegion = getEnemiesInRegion(regionId);
  socket.send(JSON.stringify({
    type: "snapshot",
    sequence: getRegionSequence(regionId),
    avatars: getRegionPopulation(regionId),
    objects: await listRegionObjects(regionId),
    parcels: await listParcels(regionId),
    chatHistory: getChatHistory(regionId),
    enemies: enemiesInRegion.map((e) => ({
      id: e.id, regionId: e.regionId, variant: e.variant, level: e.level,
      hp: e.hp, maxHp: e.maxHp, x: e.x, y: e.y, z: e.z, state: e.state
    })),
    combatStats: getOrCreateStats(session.accountId)
  }));

  if (lastSequence) {
    socket.send(JSON.stringify({
      type: "chat",
      sequence: nextRegionSequence(regionId),
      avatarId: "system",
      displayName: "System",
      message: `Resynced after sequence ${lastSequence}.`,
      channel: "region",
      createdAt: new Date().toISOString()
    }));
  }

  const joinedAvatar = getRegionPopulation(regionId).find((avatar) => avatar.avatarId === session.avatarId);

  if (joinedAvatar) {
    broadcastRegion(regionId, { type: "avatar:joined", sequence: nextRegionSequence(regionId), avatar: joinedAvatar });
  }

  socket.on("message", async (rawMessage: Buffer) => {
    try {
      const message = JSON.parse(rawMessage.toString()) as unknown;

      if (!isRegionCommand(message)) {
        throw new Error("Invalid command payload");
      }

      if (message.type === "move" && !sittingAvatars.has(session.avatarId)) {
        const clampedX = Math.max(-28, Math.min(28, message.x));
        const clampedZ = Math.max(-28, Math.min(28, message.z));
        const clampedY = Math.max(0, Math.min(4, message.y ?? 0));

        // Check home privacy before allowing move into a home parcel
        const parcels = await listParcels(regionId);
        const homeOwnerInfo = findHomeParcelOwner(parcels, clampedX, clampedZ);

        if (homeOwnerInfo && homeOwnerInfo.ownerAccountId !== session.accountId) {
          const access = await checkHomeAccess(session.accountId, homeOwnerInfo.ownerAccountId, token);
          if (!access.allowed) {
            socket.send(JSON.stringify({
              type: "chat",
              sequence: nextRegionSequence(regionId),
              avatarId: "system",
              displayName: "System",
              message: access.reason ?? "You cannot enter this home.",
              channel: "region",
              createdAt: new Date().toISOString()
            }));
            return;
          }
        }

        const avatar = await moveAvatar(token, clampedX, clampedZ, clampedY);

        if (avatar) {
          broadcastRegion(regionId, { type: "avatar:moved", sequence: nextRegionSequence(regionId), avatar });
          updateLastActivity(session.accountId);

          // Doorbell notification
          if (homeOwnerInfo && shouldRingDoorbell(session.accountId, homeOwnerInfo.ownerAccountId)) {
            broadcastRegion(regionId, {
              type: "home:doorbell",
              sequence: nextRegionSequence(regionId),
              visitorAvatarId: session.avatarId,
              visitorDisplayName: session.displayName,
              homeOwnerAccountId: homeOwnerInfo.ownerAccountId,
              parcelName: homeOwnerInfo.parcelName
            });
          }
        }
      }

      if (message.type === "chat") {
        const entry = handleChatMessage(session, message.message);
        broadcastRegion(regionId, {
          type: "chat",
          sequence: nextRegionSequence(regionId),
          avatarId: entry.avatarId,
          displayName: entry.displayName,
          message: entry.message,
          channel: entry.channel,
          createdAt: entry.createdAt
        });
        updateLastActivity(session.accountId);
        onChatMessage(session.accountId);
      }

      if (message.type === "whisper") {
        const whisperResult = handleWhisper(session, message.targetDisplayName, message.message);
        if (whisperResult) {
          const whisperEvent = {
            type: "whisper" as const,
            sequence: nextRegionSequence(regionId),
            fromAvatarId: whisperResult.fromSession.avatarId,
            fromDisplayName: whisperResult.fromSession.displayName,
            toAvatarId: whisperResult.toSession.avatarId,
            toDisplayName: whisperResult.toSession.displayName,
            message: whisperResult.message,
            createdAt: new Date().toISOString()
          };
          sendToAvatar(regionId, whisperResult.fromSession.avatarId, whisperEvent);
          sendToAvatar(regionId, whisperResult.toSession.avatarId, whisperEvent);
        } else {
          socket.send(JSON.stringify({
            type: "chat",
            sequence: nextRegionSequence(regionId),
            avatarId: "system",
            displayName: "System",
            message: `User "${message.targetDisplayName}" not found in this region.`,
            channel: "region",
            createdAt: new Date().toISOString()
          }));
        }
      }

      if (message.type === "radio:tune") {
        const station = handleRadioTune(token, message.stationId);
        if (station) {
          broadcastRegion(regionId, {
            type: "radio:changed",
            sequence: nextRegionSequence(regionId),
            stationId: station.id,
            stationName: station.name,
            trackName: station.tracks[station.currentTrack],
            currentTrack: station.currentTrack
          });
        }
      }

      if (message.type === "radio:skip") {
        const station = handleRadioSkip(token);
        if (station) {
          broadcastRegion(regionId, {
            type: "radio:changed",
            sequence: nextRegionSequence(regionId),
            stationId: station.id,
            stationName: station.name,
            trackName: station.tracks[station.currentTrack],
            currentTrack: station.currentTrack
          });
        }
      }

      if (message.type === "emote") {
        const result = handleEmote(token, message.emoteName);
        if (result) {
          broadcastRegion(regionId, {
            type: "avatar:emote",
            sequence: nextRegionSequence(regionId),
            avatarId: result.avatarId,
            displayName: result.displayName,
            emoteName: result.emote.name,
            duration_ms: result.emote.duration_ms
          });

          // Check for emote combos
          const combo = recordEmote(session.avatarId, message.emoteName, regionId);
          if (combo) {
            broadcastRegion(regionId, {
              type: "emote:combo",
              sequence: nextRegionSequence(regionId),
              avatarIds: combo.avatarIds,
              comboName: combo.comboName,
              position: combo.position
            });
          }
        }
      }

      if (message.type === "typing") {
        broadcastRegion(regionId, {
          type: "avatar:typing",
          avatarId: session.avatarId,
          displayName: session.displayName,
          typing: message.typing
        } as unknown as import("./contracts.js").RegionEvent, socket);
      }

      if (message.type === "sit") {
        const objects = await listRegionObjects(regionId);
        const target = objects.find((obj) => obj.id === message.objectId);

        if (target && (target.asset.includes("bench") || target.asset.includes("chair"))) {
          sittingAvatars.set(session.avatarId, message.objectId);
          const sitPosition = { x: target.x, y: target.y + 0.5, z: target.z };
          const avatar = await moveAvatar(token, sitPosition.x, sitPosition.z, sitPosition.y);

          if (avatar) {
            broadcastRegion(regionId, {
              type: "avatar:sit",
              sequence: nextRegionSequence(regionId),
              avatarId: session.avatarId,
              objectId: message.objectId,
              position: sitPosition
            });
          }
        }
      }

      if (message.type === "stand") {
        if (sittingAvatars.has(session.avatarId)) {
          sittingAvatars.delete(session.avatarId);
          broadcastRegion(regionId, {
            type: "avatar:stand",
            sequence: nextRegionSequence(regionId),
            avatarId: session.avatarId
          });
        }
      }

      if (message.type === "voxel:place_block") {
        const vp = await getVoxelPermission(session, message.x, message.z);
        if (!vp.allowed) {
          socket.send(JSON.stringify({
            type: "chat", sequence: nextRegionSequence(regionId),
            avatarId: "system", displayName: "System",
            message: vp.reason ?? "Cannot place blocks here.",
            channel: "region", createdAt: new Date().toISOString()
          }));
        } else {
          setBlock(regionId, message.x, message.y, message.z, message.blockTypeId);
          broadcastRegion(regionId, {
            type: "voxel:block_placed", sequence: nextRegionSequence(regionId),
            regionId, x: message.x, y: message.y, z: message.z,
            blockTypeId: message.blockTypeId, accountId: session.accountId
          });
          onBlockPlaced(session.accountId);
        }
      }

      if (message.type === "voxel:break_block") {
        const vp = await getVoxelPermission(session, message.x, message.z);
        if (!vp.allowed) {
          socket.send(JSON.stringify({
            type: "chat", sequence: nextRegionSequence(regionId),
            avatarId: "system", displayName: "System",
            message: vp.reason ?? "Cannot break blocks here.",
            channel: "region", createdAt: new Date().toISOString()
          }));
        } else {
          setBlock(regionId, message.x, message.y, message.z, 0);
          broadcastRegion(regionId, {
            type: "voxel:block_broken", sequence: nextRegionSequence(regionId),
            regionId, x: message.x, y: message.y, z: message.z,
            accountId: session.accountId
          });
          onBlockBroken(session.accountId);
        }
      }

      if (message.type === "combat:attack") {
        const result = attackEnemy(token, message.targetId, message.attackStyle);
        if (result && !("error" in result)) {
          broadcastRegion(regionId, {
            type: "combat:damage", sequence: nextRegionSequence(regionId),
            attackerId: session.accountId, targetId: message.targetId,
            damage: result.damage, critical: result.critical,
            targetHp: result.targetHp, targetMaxHp: result.targetMaxHp,
            attackStyle: message.attackStyle
          });
          if (result.killed) {
            onEnemyDefeated(session.accountId);
          }
          if (result.leveledUp && result.newLevel) {
            broadcastRegion(regionId, {
              type: "combat:level_up", sequence: nextRegionSequence(regionId),
              accountId: session.accountId, newLevel: result.newLevel
            });
            onCombatLevelUp(session.accountId, result.newLevel);
          }
        }
      }

      if (message.type === "group_chat") {
        const { getGroupMembers, listRegions, getRegionPopulation } = await import("./world/store.js");
        const members = await getGroupMembers(token, message.groupId);
        if (members.length > 0 && members.some((m) => m.accountId === session.accountId)) {
          const memberAccountIds = new Set(members.map((m) => m.accountId));
          const onlineAvatarIds = new Set<string>();
          for (const region of listRegions()) {
            for (const avatar of getRegionPopulation(region.id)) {
              if (memberAccountIds.has(avatar.accountId)) {
                onlineAvatarIds.add(avatar.avatarId);
              }
            }
          }
          sendToAvatars(onlineAvatarIds, {
            type: "group:chat",
            sequence: nextRegionSequence(regionId),
            groupId: message.groupId,
            avatarId: session.avatarId,
            displayName: session.displayName,
            message: message.message.slice(0, 180),
            createdAt: new Date().toISOString()
          });
        }
      }
    } catch {
      socket.send(JSON.stringify({
        type: "chat",
        sequence: nextRegionSequence(regionId),
        avatarId: "system",
        displayName: "System",
        message: "Ignored malformed event payload.",
        channel: "region",
        createdAt: new Date().toISOString()
      }));
    }
  });

  socket.on("close", () => {
    leaveRegion(regionId, session.avatarId);
    sittingAvatars.delete(session.avatarId);
    const removed = removeAvatar(token);

    if (removed) {
      broadcastRegion(regionId, {
        type: "avatar:left",
        sequence: nextRegionSequence(regionId),
        avatarId: removed.avatarId
      });
    }

    setPresenceOnDisconnect(session.accountId);
    const voiceRegions = cleanupVoiceForAccount(session.accountId);
    for (const vr of voiceRegions) {
      removeAccountFromVoice(session.accountId, vr.regionId);
    }
  });
});

const port = Number(process.env.PORT ?? 3000);

try {
  await app.listen({ port, host: "0.0.0.0" });
} catch (error) {
  app.log.error(error);
  process.exit(1);
}
