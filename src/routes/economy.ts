import { FastifyInstance } from "fastify";
import {
  equipInventoryItem,
  getCurrencyBalance,
  getBalanceByAccount,
  hasBalanceByAccount,
  getSession,
  listCurrencyTransactions,
  sendCurrency,
  serverTransfer
} from "../world/store.js";

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

    return reply.send(result);
  });

  // ── Spigot bridge endpoints (accountId-based, API key auth) ─────────────

  app.get<{ Params: { accountId: string } }>("/api/economy/balance/:accountId", async (request, reply) => {
    const balance = await getBalanceByAccount(request.params.accountId);
    return reply.send({ balance });
  });

  app.get<{ Params: { accountId: string }; Querystring: { amount?: string } }>("/api/economy/has/:accountId", async (request, reply) => {
    const amount = Number(request.query.amount ?? 0);
    const has = await hasBalanceByAccount(request.params.accountId, amount);
    return reply.send({ has });
  });

  app.get<{ Params: { accountId: string }; Querystring: { limit?: string } }>("/api/economy/transactions/:accountId", async (request, reply) => {
    const limit = Math.max(1, Math.min(100, Number(request.query.limit ?? 20)));
    const transactions = await listCurrencyTransactions("__bypass__", limit);
    // For server calls, get by accountId directly
    const { persistence } = await import("../world/_shared-state.js");
    const txns = await persistence.listCurrencyTransactions(request.params.accountId, limit);
    return reply.send({ transactions: txns });
  });

  app.post<{ Body: { fromAccountId?: string | null; toAccountId?: string | null; amount?: number; type?: string; description?: string } }>("/api/economy/server-transfer", async (request, reply) => {
    const { fromAccountId = null, toAccountId = null, amount, type = "bonus", description = "server transfer" } = request.body;

    if (!amount || amount <= 0) {
      return reply.code(400).send({ error: "positive amount is required" });
    }

    if (!fromAccountId && !toAccountId) {
      return reply.code(400).send({ error: "fromAccountId or toAccountId is required" });
    }

    const validTypes = ["gift", "purchase", "sale", "bonus", "region_tax", "loot", "death_penalty"] as const;
    const txType = validTypes.includes(type as any) ? (type as typeof validTypes[number]) : "bonus";

    const result = await serverTransfer(fromAccountId ?? null, toAccountId ?? null, amount, txType, description);

    if (!result.success) {
      return reply.code(403).send({ error: result.reason });
    }

    return reply.send({ success: true, balance: result.balance });
  });
}
