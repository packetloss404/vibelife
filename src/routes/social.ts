import { FastifyInstance } from "fastify";
import {
  addFriend,
  addGroupMember,
  blockAccount,
  createGroup,
  getAvatarProfile,
  getGroupMembers,
  handleChatMessage,
  listFriends,
  listGroups,
  listOfflineMessages,
  markMessageRead,
  onChatMessage,
  removeFriend,
  removeGroupMember,
  saveAvatarProfile,
  sendOfflineMessage,
  unblockAccount
} from "../world/store.js";

export default async function socialRoutes(app: FastifyInstance) {
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

  // ── Paper bridge: chat persistence ─────────────────────────────────────

  app.post<{ Body: { accountId?: string; displayName?: string; regionId?: string; message?: string } }>("/api/chat/persist", async (request, reply) => {
    const { accountId, displayName, regionId, message } = request.body;

    if (!accountId || !displayName || !regionId || !message) {
      return reply.code(400).send({ error: "accountId, displayName, regionId, and message are required" });
    }

    // Create a minimal session-like object for the chat service
    const pseudoSession = {
      token: "",
      accountId,
      avatarId: accountId,
      displayName,
      regionId,
      role: "resident" as const,
      expiresAt: Date.now() + 60000
    };

    const entry = handleChatMessage(pseudoSession, message);
    const unlocked = onChatMessage(accountId);

    return reply.send({ entry, achievements: unlocked });
  });
}
