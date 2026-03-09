import path from "node:path";
import { fileURLToPath } from "node:url";
import Fastify from "fastify";
import cors from "@fastify/cors";
import websocket from "@fastify/websocket";
import fastifyStatic from "@fastify/static";
import {
  claimParcel,
  createRegionObject,
  createGuestSession,
  deleteRegionObject,
  getPersistenceMode,
  getRegionPopulation,
  getSession,
  initializeWorldStore,
  listParcels,
  listRegionObjects,
  listRegions,
  moveAvatar,
  removeAvatar,
  updateAvatarAppearance,
  updateRegionObject
} from "./world/store.js";
import { broadcastRegion, joinRegion, leaveRegion } from "./world/region.js";

const app = Fastify({ logger: true });
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const publicDir = path.resolve(__dirname, "../public");

await initializeWorldStore();

await app.register(cors, { origin: true });
await app.register(websocket);
await app.register(fastifyStatic, {
  root: publicDir,
  prefix: "/",
  wildcard: false
});

app.get("/api/health", async () => ({
  ok: true,
  now: new Date().toISOString(),
  stack: "Fastify + WebSocket region prototype",
  persistence: getPersistenceMode()
}));

app.get("/api/regions", async () => ({
  regions: listRegions().map((region) => ({
    ...region,
    population: getRegionPopulation(region.id).length
  }))
}));

app.get<{ Params: { regionId: string } }>("/api/regions/:regionId/parcels", async (request) => ({
  parcels: await listParcels(request.params.regionId)
}));

app.get<{ Params: { regionId: string } }>("/api/regions/:regionId/objects", async (request) => ({
  objects: await listRegionObjects(request.params.regionId)
}));

app.post<{ Body: { displayName?: string; regionId?: string } }>("/api/auth/guest", async (request, reply) => {
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

app.patch<{
  Body: {
    token?: string;
    bodyColor?: string;
    accentColor?: string;
    headColor?: string;
    hairColor?: string;
    outfit?: string;
    accessory?: string;
  };
}>("/api/avatar/appearance", async (request, reply) => {
  const { token, bodyColor, accentColor, headColor, hairColor, outfit, accessory } = request.body;

  if (!token || !bodyColor || !accentColor || !headColor || !hairColor || !outfit || !accessory) {
    return reply.code(400).send({ error: "complete avatar appearance payload is required" });
  }

  const avatar = await updateAvatarAppearance(token, { bodyColor, accentColor, headColor, hairColor, outfit, accessory });

  if (!avatar) {
    return reply.code(404).send({ error: "avatar session not found" });
  }

  const session = getSession(token);
  if (session) {
    broadcastRegion(session.regionId, { type: "avatar:updated", avatar });
  }

  return reply.send({ avatar });
});

app.post<{ Body: { token?: string; parcelId?: string } }>("/api/parcels/claim", async (request, reply) => {
  const token = request.body.token;
  const parcelId = request.body.parcelId;

  if (!token || !parcelId) {
    return reply.code(400).send({ error: "token and parcelId are required" });
  }

  const parcel = await claimParcel(token, parcelId);

  if (!parcel) {
    return reply.code(409).send({ error: "parcel unavailable" });
  }

  return reply.send({ parcel });
});

app.post<{
  Params: { regionId: string };
  Body: { token?: string; asset?: string; x?: number; y?: number; z?: number; rotationY?: number; scale?: number };
}>("/api/regions/:regionId/objects", async (request, reply) => {
  const { token, asset, x, y, z, rotationY, scale } = request.body;

  if (!token || !asset || x === undefined || y === undefined || z === undefined) {
    return reply.code(400).send({ error: "token, asset, x, y, and z are required" });
  }

  const object = await createRegionObject(token, {
    asset,
    x,
    y,
    z,
    rotationY: rotationY ?? 0,
    scale: scale ?? 1
  });

  if (!object.object || object.object.regionId !== request.params.regionId) {
    return reply.code(403).send({ error: object.permission.reason ?? "unable to create object in region" });
  }

  broadcastRegion(request.params.regionId, { type: "object:created", object: object.object });

  return reply.send({ object: object.object });
});

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

  broadcastRegion(object.object.regionId, { type: "object:updated", object: object.object });

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

  const session = getSession(token);
  const deleted = await deleteRegionObject(token, request.params.objectId);

  if (!deleted) {
    return reply.code(404).send({ error: "object not found or not owned" });
  }

  if (session) {
    broadcastRegion(session.regionId, { type: "object:deleted", objectId: request.params.objectId });
  }

  return reply.send({ ok: true });
});

app.get("/ws/regions/:regionId", { websocket: true }, async (socket, request) => {
  const token = (request.query as { token?: string }).token;

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

  socket.send(JSON.stringify({
    type: "snapshot",
    avatars: getRegionPopulation(regionId),
    objects: await listRegionObjects(regionId)
  }));

  const joinedAvatar = getRegionPopulation(regionId).find((avatar) => avatar.avatarId === session.avatarId);

  if (joinedAvatar) {
    broadcastRegion(regionId, { type: "avatar:joined", avatar: joinedAvatar });
  }

  socket.on("message", async (rawMessage: Buffer) => {
    try {
      const message = JSON.parse(rawMessage.toString()) as
        | { type: "move"; x: number; z: number; y?: number }
        | { type: "chat"; message: string };

      if (message.type === "move") {
        const avatar = await moveAvatar(
          token,
          Math.max(-28, Math.min(28, message.x)),
          Math.max(-28, Math.min(28, message.z)),
          Math.max(0, Math.min(4, message.y ?? 0))
        );

        if (avatar) {
          broadcastRegion(regionId, { type: "avatar:moved", avatar });
        }
      }

      if (message.type === "chat") {
        broadcastRegion(regionId, {
          type: "chat",
          avatarId: session.avatarId,
          displayName: session.displayName,
          message: message.message.slice(0, 180),
          createdAt: new Date().toISOString()
        });
      }
    } catch {
      socket.send(JSON.stringify({
        type: "chat",
        avatarId: "system",
        displayName: "System",
        message: "Ignored malformed event payload.",
        createdAt: new Date().toISOString()
      }));
    }
  });

  socket.on("close", () => {
    leaveRegion(regionId, session.avatarId);
    const removed = removeAvatar(token);

    if (removed) {
      broadcastRegion(regionId, {
        type: "avatar:left",
        avatarId: removed.avatarId
      });
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
