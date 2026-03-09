import path from "node:path";
import { fileURLToPath } from "node:url";
import Fastify from "fastify";
import cors from "@fastify/cors";
import websocket from "@fastify/websocket";
import fastifyStatic from "@fastify/static";
import {
  claimParcel,
  createGuestSession,
  getPersistenceMode,
  getRegionPopulation,
  getSession,
  initializeWorldStore,
  listParcels,
  listRegions,
  moveAvatar,
  removeAvatar
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

app.post<{ Body: { displayName?: string; regionId?: string } }>("/api/auth/guest", async (request, reply) => {
  const displayName = (request.body.displayName ?? "Guest Voyager").trim().slice(0, 32) || "Guest Voyager";
  const { account, inventory, parcels, session, avatar } = await createGuestSession(displayName, request.body.regionId);

  return reply.send({
    session,
    account,
    inventory,
    parcels,
    avatar,
    persistence: getPersistenceMode()
  });
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

app.get("/ws/regions/:regionId", { websocket: true }, (connection, request) => {
  const token = (request.query as { token?: string }).token;

  if (!token) {
    connection.websocket.close(1008, "Missing token");
    return;
  }

  const session = getSession(token);
  const regionId = (request.params as { regionId: string }).regionId;

  if (!session || session.regionId !== regionId) {
    connection.websocket.close(1008, "Invalid session");
    return;
  }

  joinRegion(regionId, session.avatarId, connection.websocket);

  connection.websocket.send(JSON.stringify({
    type: "snapshot",
    avatars: getRegionPopulation(regionId)
  }));

  const joinedAvatar = getRegionPopulation(regionId).find((avatar) => avatar.avatarId === session.avatarId);

  if (joinedAvatar) {
    broadcastRegion(regionId, { type: "avatar:joined", avatar: joinedAvatar });
  }

  connection.websocket.on("message", async (rawMessage: Buffer) => {
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
      connection.websocket.send(JSON.stringify({
        type: "chat",
        avatarId: "system",
        displayName: "System",
        message: "Ignored malformed event payload.",
        createdAt: new Date().toISOString()
      }));
    }
  });

  connection.websocket.on("close", () => {
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
