import path from "node:path";
import { fileURLToPath } from "node:url";
import Fastify from "fastify";
import cors from "@fastify/cors";
import websocket from "@fastify/websocket";
import fastifyStatic from "@fastify/static";
import { isRegionCommand } from "./contracts.js";
import {
  adminAssignParcel,
  adminDeleteRegionObject,
  banAccount,
  unbanAccount,
  getActiveBan
} from "./world/store.js";
import {
  addParcelCollaborator,
  addFriend,
  addGroupMember,
  appendAuditLog,
  blockAccount,
  claimParcel,
  createGroup,
  createRegionNotice,
  createRegionObject,
  createTeleportPoint,
  createGuestSession,
  deleteRegionObject,
  deleteTeleportPoint,
  deleteRegionNotice,
  equipInventoryItem,
  getAvatarProfile,
  getCurrencyBalance,
  getGroupMembers,
  getObjectPermissions,
  getPersistenceMode,
  getRegionPopulation,
  getSession,
  initializeWorldStore,
  listCurrencyTransactions,
  listFriends,
  listGroups,
  listOfflineMessages,
  listParcels,
  listRegionNotices,
  listRegionObjects,
  listRegions,
  listAuditLogs,
  listTeleportPoints,
  loginSession,
  markMessageRead,
  moveAvatar,
  registerSession,
  removeFriend,
  removeGroupMember,
  removeParcelCollaborator,
  releaseParcel,
  removeAvatar,
  saveAvatarProfile,
  saveObjectPermissions,
  sendCurrency,
  sendOfflineMessage,
  teleportToRegion,
  transferParcel,
  updateAvatarAppearance,
  updateRegionObject,
  unblockAccount,
  createObjectScript,
  listObjectScripts,
  updateObjectScript,
  deleteObjectScript,
  listAssets,
  createAsset,
  deleteAsset
} from "./world/store.js";
import { broadcastRegion, getRegionSequence, joinRegion, leaveRegion, nextRegionSequence } from "./world/region.js";

const app = Fastify({ logger: true });
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const publicDir = path.resolve(__dirname, "../public");
const threeDir = path.resolve(__dirname, "../node_modules/three");

await initializeWorldStore();

await app.register(cors, { origin: true });
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

app.post<{ Body: { displayName?: string; password?: string; regionId?: string } }>("/api/auth/register", async (request, reply) => {
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

app.post<{ Body: { displayName?: string; password?: string; regionId?: string } }>("/api/auth/login", async (request, reply) => {
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
    broadcastRegion(session.regionId, { type: "avatar:updated", sequence: nextRegionSequence(session.regionId), avatar });
  }

  return reply.send({ avatar });
});

app.post<{ Body: { token?: string; itemId?: string } }>("/api/inventory/equip", async (request, reply) => {
  const { token, itemId } = request.body;

  if (!token || !itemId) {
    return reply.code(400).send({ error: "token and itemId are required" });
  }

  const result = await equipInventoryItem(token, itemId);
  const session = getSession(token);

  if (!session || !result.avatar) {
    return reply.code(404).send({ error: "unable to equip item" });
  }

  broadcastRegion(session.regionId, { type: "avatar:updated", sequence: nextRegionSequence(session.regionId), avatar: result.avatar });
  return reply.send(result);
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

  const session = getSession(token);

  if (session) {
    broadcastRegion(session.regionId, { type: "parcel:updated", sequence: nextRegionSequence(session.regionId), parcel });
    await appendAuditLog(token, "parcel.claim", "parcel", parcel.id, `claimed ${parcel.name}`, session.regionId);
  }

  return reply.send({ parcel });
});

app.post<{ Body: { token?: string; parcelId?: string } }>("/api/parcels/release", async (request, reply) => {
  const token = request.body.token;
  const parcelId = request.body.parcelId;

  if (!token || !parcelId) {
    return reply.code(400).send({ error: "token and parcelId are required" });
  }

  const parcel = await releaseParcel(token, parcelId);

  if (!parcel) {
    return reply.code(409).send({ error: "parcel unavailable" });
  }

  const session = getSession(token);

  if (session) {
    broadcastRegion(session.regionId, { type: "parcel:updated", sequence: nextRegionSequence(session.regionId), parcel });
    await appendAuditLog(token, "parcel.release", "parcel", parcel.id, `released ${parcel.name}`, session.regionId);
  }

  return reply.send({ parcel });
});

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
    broadcastRegion(session.regionId, { type: "parcel:updated", sequence: nextRegionSequence(session.regionId), parcel });
    await appendAuditLog(token, "admin.parcel.assign", "parcel", parcel.id, `assigned ${parcel.name} to ${ownerAccountId ?? "none"}`, session.regionId);
  }

  return reply.send({ parcel });
});

app.post<{ Body: { token?: string; parcelId?: string; collaboratorAccountId?: string } }>("/api/parcels/collaborators/add", async (request, reply) => {
  const { token, parcelId, collaboratorAccountId } = request.body;
  if (!token || !parcelId || !collaboratorAccountId) {
    return reply.code(400).send({ error: "token, parcelId and collaboratorAccountId are required" });
  }
  const parcel = await addParcelCollaborator(token, parcelId, collaboratorAccountId);
  if (!parcel) {
    return reply.code(403).send({ error: "unable to add collaborator" });
  }
  const session = getSession(token);
  if (session) {
    broadcastRegion(session.regionId, { type: "parcel:updated", sequence: nextRegionSequence(session.regionId), parcel });
    await appendAuditLog(token, "parcel.collaborator.add", "parcel", parcel.id, `added collaborator ${collaboratorAccountId}`, session.regionId);
  }
  return reply.send({ parcel });
});

app.post<{ Body: { token?: string; parcelId?: string; collaboratorAccountId?: string } }>("/api/parcels/collaborators/remove", async (request, reply) => {
  const { token, parcelId, collaboratorAccountId } = request.body;
  if (!token || !parcelId || !collaboratorAccountId) {
    return reply.code(400).send({ error: "token, parcelId and collaboratorAccountId are required" });
  }
  const parcel = await removeParcelCollaborator(token, parcelId, collaboratorAccountId);
  if (!parcel) {
    return reply.code(403).send({ error: "unable to remove collaborator" });
  }
  const session = getSession(token);
  if (session) {
    broadcastRegion(session.regionId, { type: "parcel:updated", sequence: nextRegionSequence(session.regionId), parcel });
    await appendAuditLog(token, "parcel.collaborator.remove", "parcel", parcel.id, `removed collaborator ${collaboratorAccountId}`, session.regionId);
  }
  return reply.send({ parcel });
});

app.post<{ Body: { token?: string; parcelId?: string; ownerAccountId?: string | null } }>("/api/parcels/transfer", async (request, reply) => {
  const { token, parcelId, ownerAccountId = null } = request.body;
  if (!token || !parcelId) {
    return reply.code(400).send({ error: "token and parcelId are required" });
  }
  const parcel = await transferParcel(token, parcelId, ownerAccountId);
  if (!parcel) {
    return reply.code(403).send({ error: "unable to transfer parcel" });
  }
  const session = getSession(token);
  if (session) {
    broadcastRegion(session.regionId, { type: "parcel:updated", sequence: nextRegionSequence(session.regionId), parcel });
    await appendAuditLog(token, "parcel.transfer", "parcel", parcel.id, `transferred parcel to ${ownerAccountId ?? "none"}`, session.regionId);
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

  broadcastRegion(session.regionId, { type: "object:deleted", sequence: nextRegionSequence(session.regionId), objectId });
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

app.post<{
  Params: { regionId: string };
  Body: { token?: string; asset?: string; x?: number; y?: number; z?: number; rotationY?: number; scale?: number };
}>("/api/regions/:regionId/objects", async (request, reply) => {
  const { token, asset, x, y, z, rotationY, scale } = request.body;
  const session = token ? getSession(token) : undefined;

  if (!token || !asset || x === undefined || y === undefined || z === undefined) {
    return reply.code(400).send({ error: "token, asset, x, y, and z are required" });
  }

  if (!session || session.regionId !== request.params.regionId) {
    return reply.code(403).send({ error: "session is not active in this region" });
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

  broadcastRegion(request.params.regionId, { type: "object:created", sequence: nextRegionSequence(request.params.regionId), object: object.object });

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

  broadcastRegion(object.object.regionId, { type: "object:updated", sequence: nextRegionSequence(object.object.regionId), object: object.object });

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
    broadcastRegion(session.regionId, { type: "object:deleted", sequence: nextRegionSequence(session.regionId), objectId: request.params.objectId });
  }

  return reply.send({ ok: true });
});

app.post<{ Body: { token?: string; targetRegionId?: string; x?: number; y?: number; z?: number } }>("/api/avatar/teleport", async (request, reply) => {
  const { token, targetRegionId, x = 0, y = 0, z = 0 } = request.body;

  if (!token || !targetRegionId) {
    return reply.code(400).send({ error: "token and targetRegionId are required" });
  }

  const result = await teleportToRegion(token, targetRegionId, x, y, z);

  if (!result.ok) {
    return reply.code(403).send({ error: result.reason });
  }

  await appendAuditLog(token, "avatar.teleport", "account", result.session?.accountId ?? "", `teleported to ${targetRegionId}`, targetRegionId);

  return reply.send({
    session: result.session,
    avatar: result.avatar,
    regionId: targetRegionId
  });
});

app.get<{ Querystring: { token?: string } }>("/api/avatar/teleport-points", async (request, reply) => {
  const token = request.query.token;

  if (!token) {
    return reply.code(400).send({ error: "token is required" });
  }

  const points = await listTeleportPoints(token);
  return reply.send({ points });
});

app.post<{ Body: { token?: string; name?: string; regionId?: string; x?: number; y?: number; z?: number; rotationY?: number } }>("/api/avatar/teleport-points", async (request, reply) => {
  const { token, name, regionId, x, y, z, rotationY = 0 } = request.body;

  if (!token || !name || !regionId || x === undefined || y === undefined || z === undefined) {
    return reply.code(400).send({ error: "token, name, regionId, x, y, z are required" });
  }

  const point = await createTeleportPoint(token, name, regionId, x, y, z, rotationY);

  if (!point) {
    return reply.code(403).send({ error: "failed to create teleport point" });
  }

  return reply.send({ point });
});

app.delete<{ Body: { token?: string; pointId?: string } }>("/api/avatar/teleport-points", async (request, reply) => {
  const { token, pointId } = request.body;

  if (!token || !pointId) {
    return reply.code(400).send({ error: "token and pointId are required" });
  }

  const deleted = await deleteTeleportPoint(token, pointId);

  if (!deleted) {
    return reply.code(404).send({ error: "teleport point not found" });
  }

  return reply.send({ ok: true });
});

app.get<{ Querystring: { token?: string } }>("/api/friends", async (request, reply) => {
  const token = request.query.token;

  if (!token) {
    return reply.code(400).send({ error: "token is required" });
  }

  const friends = await listFriends(token);
  return reply.send({ friends });
});

app.post<{ Body: { token?: string; friendAccountId?: string } }>("/api/friends", async (request, reply) => {
  const { token, friendAccountId } = request.body;

  if (!token || !friendAccountId) {
    return reply.code(400).send({ error: "token and friendAccountId are required" });
  }

  const friend = await addFriend(token, friendAccountId);

  if (!friend) {
    return reply.code(409).send({ error: "unable to add friend" });
  }

  return reply.send({ friend });
});

app.delete<{ Body: { token?: string; friendAccountId?: string } }>("/api/friends", async (request, reply) => {
  const { token, friendAccountId } = request.body;

  if (!token || !friendAccountId) {
    return reply.code(400).send({ error: "token and friendAccountId are required" });
  }

  const removed = await removeFriend(token, friendAccountId);

  if (!removed) {
    return reply.code(404).send({ error: "friend not found" });
  }

  return reply.send({ ok: true });
});

app.post<{ Body: { token?: string; blockedAccountId?: string } }>("/api/friends/block", async (request, reply) => {
  const { token, blockedAccountId } = request.body;

  if (!token || !blockedAccountId) {
    return reply.code(400).send({ error: "token and blockedAccountId are required" });
  }

  const blocked = await blockAccount(token, blockedAccountId);
  return reply.send({ blocked });
});

app.delete<{ Body: { token?: string; blockedAccountId?: string } }>("/api/friends/block", async (request, reply) => {
  const { token, blockedAccountId } = request.body;

  if (!token || !blockedAccountId) {
    return reply.code(400).send({ error: "token and blockedAccountId are required" });
  }

  const unblocked = await unblockAccount(token, blockedAccountId);
  return reply.send({ ok: unblocked });
});

app.get<{ Querystring: { token?: string } }>("/api/groups", async (request, reply) => {
  const token = request.query.token;

  if (!token) {
    return reply.code(400).send({ error: "token is required" });
  }

  const groups = await listGroups(token);
  return reply.send({ groups });
});

app.post<{ Body: { token?: string; name?: string; description?: string } }>("/api/groups", async (request, reply) => {
  const { token, name, description = "" } = request.body;

  if (!token || !name) {
    return reply.code(400).send({ error: "token and name are required" });
  }

  const group = await createGroup(token, name, description);

  if (!group) {
    return reply.code(403).send({ error: "failed to create group" });
  }

  return reply.send({ group });
});

app.get<{ Params: { groupId: string }; Querystring: { token?: string } }>("/api/groups/:groupId/members", async (request, reply) => {
  const token = request.query.token;

  if (!token) {
    return reply.code(400).send({ error: "token is required" });
  }

  const members = await getGroupMembers(token, request.params.groupId);
  return reply.send({ members });
});

app.post<{ Body: { token?: string; groupId?: string; memberAccountId?: string; role?: string } }>("/api/groups/members", async (request, reply) => {
  const { token, groupId, memberAccountId, role = "member" } = request.body;

  if (!token || !groupId || !memberAccountId) {
    return reply.code(400).send({ error: "token, groupId, and memberAccountId are required" });
  }

  await addGroupMember(token, groupId, memberAccountId, role as "member" | "officer" | "owner");
  return reply.send({ ok: true });
});

app.delete<{ Body: { token?: string; groupId?: string; memberAccountId?: string } }>("/api/groups/members", async (request, reply) => {
  const { token, groupId, memberAccountId } = request.body;

  if (!token || !groupId || !memberAccountId) {
    return reply.code(400).send({ error: "token, groupId, and memberAccountId are required" });
  }

  const removed = await removeGroupMember(token, groupId, memberAccountId);
  return reply.send({ ok: removed });
});

app.get<{ Querystring: { token?: string } }>("/api/currency/balance", async (request, reply) => {
  const token = request.query.token;

  if (!token) {
    return reply.code(400).send({ error: "token is required" });
  }

  const balance = await getCurrencyBalance(token);
  return reply.send({ balance });
});

app.post<{ Body: { token?: string; toAccountId?: string; amount?: number; description?: string } }>("/api/currency/send", async (request, reply) => {
  const { token, toAccountId, amount, description = "gift" } = request.body;

  if (!token || !toAccountId || !amount || amount <= 0) {
    return reply.code(400).send({ error: "token, toAccountId, and positive amount are required" });
  }

  const newBalance = await sendCurrency(token, toAccountId, amount, description);

  if (newBalance === undefined) {
    return reply.code(403).send({ error: "insufficient funds" });
  }

  return reply.send({ balance: newBalance });
});

app.get<{ Querystring: { token?: string; limit?: string } }>("/api/currency/transactions", async (request, reply) => {
  const token = request.query.token;
  const limit = Number(request.query.limit ?? 20);

  if (!token) {
    return reply.code(400).send({ error: "token is required" });
  }

  const transactions = await listCurrencyTransactions(token, Math.max(1, Math.min(100, limit)));
  return reply.send({ transactions });
});

app.get<{ Querystring: { token?: string; limit?: string } }>("/api/messages/offline", async (request, reply) => {
  const token = request.query.token;
  const limit = Number(request.query.limit ?? 50);

  if (!token) {
    return reply.code(400).send({ error: "token is required" });
  }

  const messages = await listOfflineMessages(token, Math.max(1, Math.min(100, limit)));
  return reply.send({ messages });
});

app.post<{ Body: { token?: string; toAccountId?: string; message?: string } }>("/api/messages/offline", async (request, reply) => {
  const { token, toAccountId, message } = request.body;

  if (!token || !toAccountId || !message) {
    return reply.code(400).send({ error: "token, toAccountId, and message are required" });
  }

  const sent = await sendOfflineMessage(token, toAccountId, message.slice(0, 1000));

  if (!sent) {
    return reply.code(403).send({ error: "failed to send message" });
  }

  return reply.send({ message: sent });
});

app.patch<{ Body: { token?: string; messageId?: string } }>("/api/messages/offline/read", async (request, reply) => {
  const { token, messageId } = request.body;

  if (!token || !messageId) {
    return reply.code(400).send({ error: "token and messageId are required" });
  }

  const marked = await markMessageRead(token, messageId);
  return reply.send({ ok: marked });
});

app.get<{ Querystring: { token?: string } }>("/api/avatar/profile", async (request, reply) => {
  const token = request.query.token;

  if (!token) {
    return reply.code(400).send({ error: "token is required" });
  }

  const profile = await getAvatarProfile(token);
  return reply.send({ profile });
});

app.patch<{ Body: { token?: string; bio?: string; imageUrl?: string } }>("/api/avatar/profile", async (request, reply) => {
  const { token, bio = "", imageUrl = null } = request.body;

  if (!token) {
    return reply.code(400).send({ error: "token is required" });
  }

  const profile = await saveAvatarProfile(token, bio, imageUrl);

  if (!profile) {
    return reply.code(403).send({ error: "failed to save profile" });
  }

  return reply.send({ profile });
});

app.get<{ Querystring: { token?: string } }>("/api/avatar/ban/status", async (request, reply) => {
  const token = request.query.token;

  if (!token) {
    return reply.code(400).send({ error: "token is required" });
  }

  const ban = await getActiveBan(token);
  return reply.send({ banned: !!ban, ban });
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

app.get<{ Querystring: { token?: string } }>("/api/regions/notices", async (request, reply) => {
  const token = request.query.token;

  if (!token) {
    return reply.code(400).send({ error: "token is required" });
  }

  const notices = await listRegionNotices(token);
  return reply.send({ notices });
});

app.post<{ Body: { token?: string; message?: string; parcelId?: string } }>("/api/regions/notices", async (request, reply) => {
  const { token, message, parcelId = null } = request.body;

  if (!token || !message) {
    return reply.code(400).send({ error: "token and message are required" });
  }

  const notice = await createRegionNotice(token, message, parcelId);

  if (!notice) {
    return reply.code(403).send({ error: "failed to create notice" });
  }

  return reply.send({ notice });
});

app.delete<{ Body: { token?: string; noticeId?: string } }>("/api/regions/notices", async (request, reply) => {
  const { token, noticeId } = request.body;

  if (!token || !noticeId) {
    return reply.code(400).send({ error: "token and noticeId are required" });
  }

  const deleted = await deleteRegionNotice(token, noticeId);

  if (!deleted) {
    return reply.code(404).send({ error: "notice not found" });
  }

  return reply.send({ ok: true });
});

app.get<{ Params: { objectId: string } }>("/api/objects/:objectId/permissions", async (request, reply) => {
  const perms = await getObjectPermissions(request.params.objectId);
  return reply.send({ permissions: perms ?? { objectId: request.params.objectId, allowCopy: true, allowModify: true, allowTransfer: true } });
});

app.patch<{ Params: { objectId: string }; Body: { token?: string; allowCopy?: boolean; allowModify?: boolean; allowTransfer?: boolean } }>("/api/objects/:objectId/permissions", async (request, reply) => {
  const { token, allowCopy = true, allowModify = true, allowTransfer = true } = request.body;

  if (!token) {
    return reply.code(400).send({ error: "token is required" });
  }

  const saved = await saveObjectPermissions(token, request.params.objectId, allowCopy, allowModify, allowTransfer);

  if (!saved) {
    return reply.code(403).send({ error: "failed to save permissions" });
  }

  return reply.send({ ok: true });
});

app.get<{ Params: { objectId: string }; Querystring: { token?: string } }>("/api/objects/:objectId/scripts", async (request, reply) => {
  const scripts = await listObjectScripts(request.params.objectId);
  return reply.send({ scripts });
});

app.post<{ Body: { token?: string; objectId?: string; scriptName?: string; scriptCode?: string } }>("/api/objects/scripts", async (request, reply) => {
  const { token, objectId, scriptName, scriptCode = "" } = request.body;

  if (!token || !objectId || !scriptName) {
    return reply.code(400).send({ error: "token, objectId, and scriptName are required" });
  }

  const script = await createObjectScript(token, objectId, scriptName, scriptCode);

  if (!script) {
    return reply.code(403).send({ error: "failed to create script" });
  }

  return reply.send({ script });
});

app.patch<{ Body: { token?: string; scriptId?: string; scriptCode?: string; enabled?: boolean } }>("/api/objects/scripts", async (request, reply) => {
  const { token, scriptId, scriptCode, enabled = true } = request.body;

  if (!token || !scriptId) {
    return reply.code(400).send({ error: "token and scriptId are required" });
  }

  const script = await updateObjectScript(token, scriptId, scriptCode ?? "", enabled);

  if (!script) {
    return reply.code(403).send({ error: "failed to update script" });
  }

  return reply.send({ script });
});

app.delete<{ Body: { token?: string; scriptId?: string } }>("/api/objects/scripts", async (request, reply) => {
  const { token, scriptId } = request.body;

  if (!token || !scriptId) {
    return reply.code(400).send({ error: "token and scriptId are required" });
  }

  const deleted = await deleteObjectScript(token, scriptId);

  if (!deleted) {
    return reply.code(404).send({ error: "script not found" });
  }

  return reply.send({ ok: true });
});

app.get<{ Querystring: { token?: string } }>("/api/assets", async (request, reply) => {
  const token = request.query.token;

  if (!token) {
    return reply.code(400).send({ error: "token is required" });
  }

  const assets = await listAssets(token);
  return reply.send({ assets });
});

app.post<{ Body: { token?: string; name?: string; description?: string; assetType?: string; url?: string; thumbnailUrl?: string; price?: number } }>("/api/assets", async (request, reply) => {
  const { token, name, description = "", assetType, url, thumbnailUrl = null, price = 0 } = request.body;

  if (!token || !name || !assetType || !url) {
    return reply.code(400).send({ error: "token, name, assetType, and url are required" });
  }

  const asset = await createAsset(token, name, description, assetType, url, thumbnailUrl, price);

  if (!asset) {
    return reply.code(403).send({ error: "failed to create asset" });
  }

  return reply.send({ asset });
});

app.delete<{ Body: { token?: string; assetId?: string } }>("/api/assets", async (request, reply) => {
  const { token, assetId } = request.body;

  if (!token || !assetId) {
    return reply.code(400).send({ error: "token and assetId are required" });
  }

  const deleted = await deleteAsset(token, assetId);

  if (!deleted) {
    return reply.code(404).send({ error: "asset not found" });
  }

  return reply.send({ ok: true });
});

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

  socket.send(JSON.stringify({
    type: "snapshot",
    sequence: getRegionSequence(regionId),
    avatars: getRegionPopulation(regionId),
    objects: await listRegionObjects(regionId),
    parcels: await listParcels(regionId)
  }));

  if (lastSequence) {
    socket.send(JSON.stringify({
      type: "chat",
      sequence: nextRegionSequence(regionId),
      avatarId: "system",
      displayName: "System",
      message: `Resynced after sequence ${lastSequence}.`,
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

      if (message.type === "move") {
        const avatar = await moveAvatar(
          token,
          Math.max(-28, Math.min(28, message.x)),
          Math.max(-28, Math.min(28, message.z)),
          Math.max(0, Math.min(4, message.y ?? 0))
        );

        if (avatar) {
          broadcastRegion(regionId, { type: "avatar:moved", sequence: nextRegionSequence(regionId), avatar });
        }
      }

      if (message.type === "chat") {
        broadcastRegion(regionId, {
          type: "chat",
          sequence: nextRegionSequence(regionId),
          avatarId: session.avatarId,
          displayName: session.displayName,
          message: message.message.slice(0, 180),
          createdAt: new Date().toISOString()
        });
      }
    } catch {
      socket.send(JSON.stringify({
        type: "chat",
        sequence: nextRegionSequence(regionId),
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
        sequence: nextRegionSequence(regionId),
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
