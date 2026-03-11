import type { FastifyInstance } from "fastify";
import {
  createStorefront,
  getStorefront,
  updateStorefront,
  listStorefronts,
  rateStorefront,
  getTrendingItems,
  createCommission,
  acceptCommission,
  updateCommissionStatus,
  completeCommission,
  listCommissions,
} from "../world/storefront-service.js";

export async function registerStorefrontRoutes(app: FastifyInstance) {
  // --- Storefronts ---

  app.post<{
    Body: { token?: string; shopName?: string; description?: string; bannerColor?: string };
  }>("/api/storefronts", async (request, reply) => {
    const { token, shopName, description = "", bannerColor = "#3366ff" } = request.body;

    if (!token || !shopName) {
      return reply.code(400).send({ error: "token and shopName are required" });
    }

    const storefront = createStorefront(token, shopName, description, bannerColor);

    if (!storefront) {
      return reply.code(409).send({ error: "storefront already exists or invalid session" });
    }

    return reply.send({ storefront });
  });

  app.get<{ Querystring: { sort?: string } }>("/api/storefronts", async (request, reply) => {
    const storefronts = listStorefronts(request.query.sort);
    return reply.send({ storefronts });
  });

  app.get<{ Params: { accountId: string } }>(
    "/api/storefronts/:accountId",
    async (request, reply) => {
      const storefront = getStorefront(request.params.accountId);

      if (!storefront) {
        return reply.code(404).send({ error: "storefront not found" });
      }

      return reply.send({ storefront });
    }
  );

  app.patch<{
    Body: { token?: string; shopName?: string; description?: string; bannerColor?: string };
  }>("/api/storefronts", async (request, reply) => {
    const { token, shopName, description, bannerColor } = request.body;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const storefront = updateStorefront(token, { shopName, description, bannerColor });

    if (!storefront) {
      return reply.code(404).send({ error: "storefront not found or invalid session" });
    }

    return reply.send({ storefront });
  });

  app.post<{ Params: { accountId: string }; Body: { token?: string; rating?: number } }>(
    "/api/storefronts/:accountId/rate",
    async (request, reply) => {
      const { token, rating } = request.body;

      if (!token || rating === undefined) {
        return reply.code(400).send({ error: "token and rating are required" });
      }

      const storefront = rateStorefront(token, request.params.accountId, rating);

      if (!storefront) {
        return reply.code(400).send({ error: "unable to rate storefront" });
      }

      return reply.send({ storefront });
    }
  );

  // --- Trending ---

  app.get<{ Querystring: { limit?: string } }>(
    "/api/marketplace/trending",
    async (request, reply) => {
      const limit = Number(request.query.limit ?? 10);
      const items = getTrendingItems(Math.max(1, Math.min(50, limit)));
      return reply.send({ items });
    }
  );

  // --- Commissions ---

  app.post<{
    Body: { token?: string; builderAccountId?: string; description?: string; budget?: number };
  }>("/api/commissions", async (request, reply) => {
    const { token, builderAccountId, description = "", budget } = request.body;

    if (!token || !builderAccountId || !budget || budget <= 0) {
      return reply.code(400).send({ error: "token, builderAccountId, and positive budget are required" });
    }

    const commission = createCommission(token, builderAccountId, description, budget);

    if (!commission) {
      return reply.code(400).send({ error: "unable to create commission" });
    }

    return reply.send({ commission });
  });

  app.post<{ Params: { id: string }; Body: { token?: string } }>(
    "/api/commissions/:id/accept",
    async (request, reply) => {
      const { token } = request.body;

      if (!token) {
        return reply.code(400).send({ error: "token is required" });
      }

      const commission = acceptCommission(token, request.params.id);

      if (!commission) {
        return reply.code(400).send({ error: "unable to accept commission" });
      }

      return reply.send({ commission });
    }
  );

  app.patch<{
    Params: { id: string };
    Body: { token?: string; status?: string };
  }>("/api/commissions/:id", async (request, reply) => {
    const { token, status } = request.body;

    if (!token || !status) {
      return reply.code(400).send({ error: "token and status are required" });
    }

    const commission = updateCommissionStatus(
      token,
      request.params.id,
      status as "in_progress" | "delivered" | "cancelled"
    );

    if (!commission) {
      return reply.code(400).send({ error: "unable to update commission status" });
    }

    return reply.send({ commission });
  });

  app.post<{ Params: { id: string }; Body: { token?: string } }>(
    "/api/commissions/:id/complete",
    async (request, reply) => {
      const { token } = request.body;

      if (!token) {
        return reply.code(400).send({ error: "token is required" });
      }

      const commission = completeCommission(token, request.params.id);

      if (!commission) {
        return reply.code(400).send({ error: "unable to complete commission" });
      }

      return reply.send({ commission });
    }
  );

  app.get<{ Querystring: { token?: string } }>("/api/commissions", async (request, reply) => {
    const token = request.query.token;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const commissionsList = listCommissions(token);
    return reply.send({ commissions: commissionsList });
  });
}
