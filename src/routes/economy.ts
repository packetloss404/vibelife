import { FastifyInstance } from "fastify";
import {
  equipInventoryItem,
  getCurrencyBalance,
  getSession,
  listCurrencyTransactions,
  sendCurrency
} from "../world/store.js";
import { broadcastRegion, nextRegionSequence } from "../world/region.js";

export default async function economyRoutes(app: FastifyInstance) {
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
}
