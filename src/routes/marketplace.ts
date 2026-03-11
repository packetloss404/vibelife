import type { FastifyInstance } from "fastify";
import {
  createListing,
  listMarketplace,
  buyListing,
  placeBid,
  cancelListing,
  getListingHistory,
  getPriceHistory,
  createTradeOffer,
  acceptTrade,
  declineTrade,
  listTradeOffers,
} from "../world/marketplace-service.js";

export async function registerMarketplaceRoutes(app: FastifyInstance) {
  // Create a marketplace listing
  app.post<{
    Body: { token?: string; itemId?: string; price?: number; listingType?: string; auctionEndTime?: string };
  }>("/api/marketplace/list", async (request, reply) => {
    const { token, itemId, price, listingType = "fixed", auctionEndTime } = request.body;

    if (!token || !itemId || !price || price <= 0) {
      return reply.code(400).send({ error: "token, itemId, and positive price are required" });
    }

    if (listingType !== "fixed" && listingType !== "auction") {
      return reply.code(400).send({ error: "listingType must be 'fixed' or 'auction'" });
    }

    const listing = await createListing(token, itemId, price, listingType, auctionEndTime);

    if (!listing) {
      return reply.code(403).send({ error: "failed to create listing" });
    }

    return reply.send({ listing });
  });

  // Browse marketplace listings
  app.get<{
    Querystring: { kind?: string; minPrice?: string; maxPrice?: string; sort?: string };
  }>("/api/marketplace", async (request, reply) => {
    const filters: { kind?: string; minPrice?: number; maxPrice?: number; sort?: string } = {};

    if (request.query.kind) filters.kind = request.query.kind;
    if (request.query.minPrice) filters.minPrice = Number(request.query.minPrice);
    if (request.query.maxPrice) filters.maxPrice = Number(request.query.maxPrice);
    if (request.query.sort) filters.sort = request.query.sort;

    const listings = await listMarketplace(filters);
    return reply.send({ listings });
  });

  // Buy a fixed-price listing
  app.post<{
    Params: { id: string };
    Body: { token?: string };
  }>("/api/marketplace/:id/buy", async (request, reply) => {
    const { token } = request.body;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const result = await buyListing(token, request.params.id);

    if (!result.ok) {
      return reply.code(403).send({ error: result.reason });
    }

    return reply.send({ ok: true });
  });

  // Place a bid on an auction listing
  app.post<{
    Params: { id: string };
    Body: { token?: string; amount?: number };
  }>("/api/marketplace/:id/bid", async (request, reply) => {
    const { token, amount } = request.body;

    if (!token || !amount || amount <= 0) {
      return reply.code(400).send({ error: "token and positive amount are required" });
    }

    const result = await placeBid(token, request.params.id, amount);

    if (!result.ok) {
      return reply.code(403).send({ error: result.reason });
    }

    return reply.send({ ok: true });
  });

  // Cancel a listing
  app.delete<{
    Params: { id: string };
    Body: { token?: string };
  }>("/api/marketplace/:id", async (request, reply) => {
    const { token } = request.body;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const result = await cancelListing(token, request.params.id);

    if (!result.ok) {
      return reply.code(403).send({ error: result.reason });
    }

    return reply.send({ ok: true });
  });

  // User's listing history
  app.get<{
    Querystring: { token?: string };
  }>("/api/marketplace/history", async (request, reply) => {
    const token = request.query.token;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const history = await getListingHistory(token);
    return reply.send({ listings: history });
  });

  // Price history for an item name
  app.get<{
    Params: { itemName: string };
  }>("/api/marketplace/prices/:itemName", async (request, reply) => {
    const history = await getPriceHistory(request.params.itemName);
    return reply.send({ prices: history });
  });

  // Create a trade offer
  app.post<{
    Body: {
      token?: string;
      toAccountId?: string;
      offeredItems?: string[];
      offeredCurrency?: number;
      requestedItems?: string[];
      requestedCurrency?: number;
    };
  }>("/api/trades", async (request, reply) => {
    const {
      token,
      toAccountId,
      offeredItems = [],
      offeredCurrency = 0,
      requestedItems = [],
      requestedCurrency = 0,
    } = request.body;

    if (!token || !toAccountId) {
      return reply.code(400).send({ error: "token and toAccountId are required" });
    }

    const trade = await createTradeOffer(token, toAccountId, offeredItems, offeredCurrency, requestedItems, requestedCurrency);

    if (!trade) {
      return reply.code(403).send({ error: "failed to create trade offer" });
    }

    return reply.send({ trade });
  });

  // Accept a trade offer
  app.post<{
    Params: { id: string };
    Body: { token?: string };
  }>("/api/trades/:id/accept", async (request, reply) => {
    const { token } = request.body;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const result = await acceptTrade(token, request.params.id);

    if (!result.ok) {
      return reply.code(403).send({ error: result.reason });
    }

    return reply.send({ ok: true });
  });

  // Decline a trade offer
  app.post<{
    Params: { id: string };
    Body: { token?: string };
  }>("/api/trades/:id/decline", async (request, reply) => {
    const { token } = request.body;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const result = await declineTrade(token, request.params.id);

    if (!result.ok) {
      return reply.code(403).send({ error: result.reason });
    }

    return reply.send({ ok: true });
  });

  // List pending trade offers for user
  app.get<{
    Querystring: { token?: string };
  }>("/api/trades", async (request, reply) => {
    const token = request.query.token;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const trades = await listTradeOffers(token);
    return reply.send({ trades });
  });
}
