// NPC Routes — Feature 19: AI NPCs for VibeLife
//
// INTEGRATION NOTES (do NOT auto-apply):
// - server.ts: Register this plugin:
//     import npcRoutes from "./routes/npcs.js";
//     await app.register(npcRoutes);
//
// - server.ts: Start the tick loop after initializeWorldStore():
//     import { startNpcTickLoop } from "./world/npc-service.js";
//     startNpcTickLoop();

import type { FastifyInstance } from "fastify";
import { getSession } from "../world/store.js";
import {
  listNpcsByRegion,
  getNpc,
  spawnNpc,
  despawnNpc,
  startDialogue,
  advanceDialogue,
  getPlayerQuests,
  listAvailableQuests,
  completeQuest,
  updateQuestProgress,
  addNpcScript,
  updateNpcScript,
  removeNpcScript,
  serializeNpc,
  serializeDialogueNode,
  type NpcType
} from "../world/npc-service.js";

export default async function npcRoutes(app: FastifyInstance) {

  // -----------------------------------------------------------------------
  // GET /api/npcs — List NPCs in a region
  // -----------------------------------------------------------------------
  app.get<{ Querystring: { token?: string; regionId?: string } }>("/api/npcs", async (request, reply) => {
    const { token, regionId } = request.query;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const session = getSession(token);
    if (!session) {
      return reply.code(401).send({ error: "invalid session" });
    }

    const targetRegion = regionId ?? session.regionId;
    const npcs = listNpcsByRegion(targetRegion);

    return reply.send({
      npcs: npcs.map(serializeNpc)
    });
  });

  // -----------------------------------------------------------------------
  // GET /api/npcs/:id — Get a single NPC's details
  // -----------------------------------------------------------------------
  app.get<{ Params: { id: string }; Querystring: { token?: string } }>("/api/npcs/:id", async (request, reply) => {
    const { token } = request.query;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const session = getSession(token);
    if (!session) {
      return reply.code(401).send({ error: "invalid session" });
    }

    const npc = getNpc(request.params.id);
    if (!npc) {
      return reply.code(404).send({ error: "NPC not found" });
    }

    return reply.send({ npc: serializeNpc(npc) });
  });

  // -----------------------------------------------------------------------
  // POST /api/npcs/:id/interact — Begin interaction with an NPC
  // -----------------------------------------------------------------------
  app.post<{ Params: { id: string }; Body: { token?: string } }>("/api/npcs/:id/interact", async (request, reply) => {
    const { token } = request.body;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const npc = getNpc(request.params.id);
    if (!npc) {
      return reply.code(404).send({ error: "NPC not found" });
    }

    const result = startDialogue(token, request.params.id);
    if (!result) {
      return reply.code(403).send({ error: "unable to start dialogue" });
    }

    return reply.send({
      npcId: npc.id,
      displayName: npc.displayName,
      npcType: npc.npcType,
      dialogue: serializeDialogueNode(result.npcText, result.options)
    });
  });

  // -----------------------------------------------------------------------
  // POST /api/npcs/:id/dialogue — Advance a dialogue with an option choice
  // -----------------------------------------------------------------------
  app.post<{ Params: { id: string }; Body: { token?: string; optionId?: string } }>("/api/npcs/:id/dialogue", async (request, reply) => {
    const { token, optionId } = request.body;

    if (!token || !optionId) {
      return reply.code(400).send({ error: "token and optionId are required" });
    }

    const result = advanceDialogue(token, request.params.id, optionId);
    if (!result) {
      return reply.code(403).send({ error: "no active conversation with this NPC" });
    }

    return reply.send({
      npcId: request.params.id,
      dialogue: serializeDialogueNode(result.npcText, result.options),
      action: result.action ? { type: result.action.type, payload: result.action.payload } : null,
      ended: result.ended
    });
  });

  // -----------------------------------------------------------------------
  // GET /api/npcs/quests — List player's active and completed quests
  // -----------------------------------------------------------------------
  app.get<{ Querystring: { token?: string } }>("/api/npcs/quests", async (request, reply) => {
    const { token } = request.query;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const quests = getPlayerQuests(token);
    if (!quests) {
      return reply.code(401).send({ error: "invalid session" });
    }

    return reply.send({ quests });
  });

  // -----------------------------------------------------------------------
  // GET /api/npcs/quests/available — List all quests available in region
  // -----------------------------------------------------------------------
  app.get<{ Querystring: { token?: string; regionId?: string } }>("/api/npcs/quests/available", async (request, reply) => {
    const { token, regionId } = request.query;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const session = getSession(token);
    if (!session) {
      return reply.code(401).send({ error: "invalid session" });
    }

    const targetRegion = regionId ?? session.regionId;
    const quests = listAvailableQuests(targetRegion);

    return reply.send({
      quests: quests.map((q) => ({
        id: q.id,
        npcId: q.npcId,
        title: q.title,
        description: q.description,
        frequency: q.frequency,
        objectives: q.objectives.map((o) => ({
          id: o.id,
          description: o.description,
          type: o.type,
          required: o.required
        })),
        rewards: q.rewards,
        expiresAt: q.expiresAt
      }))
    });
  });

  // -----------------------------------------------------------------------
  // POST /api/npcs/quests/:id/complete — Complete a quest
  // -----------------------------------------------------------------------
  app.post<{ Params: { id: string }; Body: { token?: string } }>("/api/npcs/quests/:id/complete", async (request, reply) => {
    const { token } = request.body;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const result = completeQuest(token, request.params.id);

    if (!result.success) {
      return reply.code(403).send({ error: result.reason ?? "quest completion failed" });
    }

    return reply.send({
      success: true,
      rewards: result.rewards
    });
  });

  // -----------------------------------------------------------------------
  // POST /api/npcs/quests/progress — Update quest objective progress
  // -----------------------------------------------------------------------
  app.post<{ Body: { token?: string; objectiveType?: string; target?: string; increment?: number } }>("/api/npcs/quests/progress", async (request, reply) => {
    const { token, objectiveType, target, increment = 1 } = request.body;

    if (!token || !objectiveType || !target) {
      return reply.code(400).send({ error: "token, objectiveType, and target are required" });
    }

    const session = getSession(token);
    if (!session) {
      return reply.code(401).send({ error: "invalid session" });
    }

    updateQuestProgress(
      session.accountId,
      objectiveType as "visit_region" | "talk_to_npc" | "collect_item" | "spend_currency" | "explore_parcels" | "chat_count",
      target,
      increment
    );

    return reply.send({ ok: true });
  });

  // -----------------------------------------------------------------------
  // POST /api/npcs/spawn — Admin: spawn an NPC
  // -----------------------------------------------------------------------
  app.post<{
    Body: {
      token?: string;
      regionId?: string;
      displayName?: string;
      npcType?: NpcType;
      x?: number;
      y?: number;
      z?: number;
      patrolRadius?: number;
      interactRadius?: number;
      appearance?: Record<string, string>;
    }
  }>("/api/npcs/spawn", async (request, reply) => {
    const { token, regionId, displayName, npcType, x, y, z, patrolRadius, interactRadius, appearance } = request.body;

    if (!token || !regionId || !displayName || !npcType) {
      return reply.code(400).send({ error: "token, regionId, displayName, and npcType are required" });
    }

    const session = getSession(token);
    if (!session || session.role !== "admin") {
      return reply.code(403).send({ error: "admin access required" });
    }

    const validTypes: NpcType[] = ["ambient", "shopkeeper", "quest-giver", "tour-guide"];
    if (!validTypes.includes(npcType)) {
      return reply.code(400).send({ error: `npcType must be one of: ${validTypes.join(", ")}` });
    }

    const npc = spawnNpc(
      regionId,
      displayName.trim().slice(0, 32),
      npcType,
      x ?? 0,
      y ?? 0,
      z ?? 0,
      { patrolRadius, interactRadius, appearance }
    );

    return reply.send({ npc: serializeNpc(npc) });
  });

  // -----------------------------------------------------------------------
  // DELETE /api/npcs/:id — Admin: despawn an NPC
  // -----------------------------------------------------------------------
  app.delete<{ Params: { id: string }; Body: { token?: string } }>("/api/npcs/:id", async (request, reply) => {
    const { token } = request.body;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const session = getSession(token);
    if (!session || session.role !== "admin") {
      return reply.code(403).send({ error: "admin access required" });
    }

    const removed = despawnNpc(request.params.id);

    if (!removed) {
      return reply.code(404).send({ error: "NPC not found" });
    }

    return reply.send({ ok: true });
  });

  // -----------------------------------------------------------------------
  // POST /api/npcs/:id/script — Admin: add a behavior script to an NPC
  // -----------------------------------------------------------------------
  app.post<{ Params: { id: string }; Body: { token?: string; name?: string; code?: string } }>("/api/npcs/:id/script", async (request, reply) => {
    const { token, name, code } = request.body;

    if (!token || !name || !code) {
      return reply.code(400).send({ error: "token, name, and code are required" });
    }

    const script = addNpcScript(token, request.params.id, name, code);

    if (!script) {
      return reply.code(403).send({ error: "failed to add script (admin required)" });
    }

    return reply.send({ script });
  });

  // -----------------------------------------------------------------------
  // PATCH /api/npcs/script/:scriptId — Admin: update an NPC script
  // -----------------------------------------------------------------------
  app.patch<{ Params: { scriptId: string }; Body: { token?: string; code?: string; enabled?: boolean } }>("/api/npcs/script/:scriptId", async (request, reply) => {
    const { token, code = "", enabled = true } = request.body;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const script = updateNpcScript(token, request.params.scriptId, code, enabled);

    if (!script) {
      return reply.code(403).send({ error: "failed to update script (admin required)" });
    }

    return reply.send({ script });
  });

  // -----------------------------------------------------------------------
  // DELETE /api/npcs/script/:scriptId — Admin: remove an NPC script
  // -----------------------------------------------------------------------
  app.delete<{ Params: { scriptId: string }; Body: { token?: string } }>("/api/npcs/script/:scriptId", async (request, reply) => {
    const { token } = request.body;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const removed = removeNpcScript(token, request.params.scriptId);

    if (!removed) {
      return reply.code(403).send({ error: "failed to remove script (admin required)" });
    }

    return reply.send({ ok: true });
  });
}
