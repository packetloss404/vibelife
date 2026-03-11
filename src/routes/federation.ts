import type { FastifyInstance } from "fastify";
import { getSession } from "../world/store.js";
import {
  registerFederatedServer,
  removeFederatedServer,
  listFederatedServers,
  getFederatedServer,
  heartbeat,
  initiateHandshake,
  completeHandshake,
  isServerTrusted,
  issueIdentityToken,
  verifyIdentityToken,
  prepareCrossServerTeleport,
  handleTeleportArrival,
  listLocalMarketplaceListings,
  publishMarketplaceListing,
  removeMarketplaceListing,
  searchFederatedMarketplace,
  getServerDirectory,
  getLocalServerStats,
  getLocalServerId,
  getLocalServerName,
  getLocalServerUrl,
  type FederatedIdentityToken,
} from "../world/federation-service.js";

export async function federationRoutes(app: FastifyInstance) {
  // --------------------------------------------------------------------------
  // Server Directory & Discovery
  // --------------------------------------------------------------------------

  /** List all known servers (local + federated). Public. */
  app.get("/api/federation/servers", async () => ({
    servers: getServerDirectory(),
  }));

  /** Get local server stats */
  app.get("/api/federation/stats", async () => ({
    stats: getLocalServerStats(),
  }));

  /** Register a new federated server */
  app.post<{
    Body: {
      token?: string;
      name?: string;
      url?: string;
      description?: string;
      ownerDisplayName?: string;
      publicKey?: string;
      tags?: string[];
    };
  }>("/api/federation/servers/register", async (request, reply) => {
    const { token, name, url, description, ownerDisplayName, publicKey, tags } = request.body;

    if (!token || !name || !url) {
      return reply.code(400).send({ error: "token, name, and url are required" });
    }

    const session = getSession(token);
    if (!session || session.role !== "admin") {
      return reply.code(403).send({ error: "admin access required" });
    }

    const server = registerFederatedServer({
      name,
      url,
      description,
      ownerDisplayName,
      publicKey,
      tags,
    });

    return reply.send({ server });
  });

  /** Remove a federated server (admin only) */
  app.delete<{
    Body: { token?: string; serverId?: string };
  }>("/api/federation/servers", async (request, reply) => {
    const { token, serverId } = request.body;

    if (!token || !serverId) {
      return reply.code(400).send({ error: "token and serverId are required" });
    }

    const session = getSession(token);
    if (!session || session.role !== "admin") {
      return reply.code(403).send({ error: "admin access required" });
    }

    const removed = removeFederatedServer(serverId);
    if (!removed) {
      return reply.code(404).send({ error: "server not found" });
    }

    return reply.send({ ok: true });
  });

  // --------------------------------------------------------------------------
  // Heartbeat
  // --------------------------------------------------------------------------

  /** Server heartbeat — updates status and stats */
  app.post<{
    Body: {
      serverId?: string;
      regions?: number;
      population?: number;
    };
  }>("/api/federation/heartbeat", async (request, reply) => {
    const { serverId, regions, population } = request.body;

    if (!serverId) {
      return reply.code(400).send({ error: "serverId is required" });
    }

    const server = heartbeat(serverId, { regions, population });
    if (!server) {
      return reply.code(404).send({ error: "server not found" });
    }

    return reply.send({ server });
  });

  // --------------------------------------------------------------------------
  // Handshake (mutual trust)
  // --------------------------------------------------------------------------

  /** Initiate a handshake with a registered server */
  app.post<{
    Body: { token?: string; serverId?: string };
  }>("/api/federation/handshake/initiate", async (request, reply) => {
    const { token, serverId } = request.body;

    if (!token || !serverId) {
      return reply.code(400).send({ error: "token and serverId are required" });
    }

    const session = getSession(token);
    if (!session || session.role !== "admin") {
      return reply.code(403).send({ error: "admin access required to initiate handshake" });
    }

    const handshake = initiateHandshake(serverId);
    if (!handshake) {
      return reply.code(404).send({ error: "server not found" });
    }

    return reply.send({ handshake });
  });

  /** Complete a handshake — the remote server responds to the challenge */
  app.post<{
    Body: { challenge?: string; response?: string };
  }>("/api/federation/handshake/complete", async (request, reply) => {
    const { challenge, response } = request.body;

    if (!challenge || !response) {
      return reply.code(400).send({ error: "challenge and response are required" });
    }

    const result = completeHandshake(challenge, response);
    if (!result.ok) {
      return reply.code(403).send({ error: result.reason });
    }

    return reply.send({ ok: true, serverId: result.serverId });
  });

  // --------------------------------------------------------------------------
  // Federated Identity
  // --------------------------------------------------------------------------

  /** Issue a portable identity token for the authenticated user */
  app.post<{
    Body: { token?: string };
  }>("/api/federation/identity/issue", async (request, reply) => {
    const { token } = request.body;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const identityToken = issueIdentityToken(token);
    if (!identityToken) {
      return reply.code(401).send({ error: "invalid session" });
    }

    return reply.send({ identityToken });
  });

  /** Verify a federated identity token (called by remote servers) */
  app.post<{
    Body: { identityToken?: FederatedIdentityToken };
  }>("/api/federation/identity/verify", async (request, reply) => {
    const { identityToken } = request.body;

    if (!identityToken) {
      return reply.code(400).send({ error: "identityToken is required" });
    }

    const result = verifyIdentityToken(identityToken);
    return reply.send({
      valid: result.valid,
      reason: result.reason,
      serverId: getLocalServerId(),
      serverName: getLocalServerName(),
    });
  });

  // --------------------------------------------------------------------------
  // Cross-Server Teleportation
  // --------------------------------------------------------------------------

  /** Request a cross-server teleport — returns a redirect URL for the client */
  app.post<{
    Body: {
      token?: string;
      targetServerUrl?: string;
      targetRegionId?: string;
      x?: number;
      y?: number;
      z?: number;
    };
  }>("/api/federation/teleport", async (request, reply) => {
    const { token, targetServerUrl, targetRegionId, x = 0, y = 0, z = 0 } = request.body;

    if (!token || !targetServerUrl || !targetRegionId) {
      return reply.code(400).send({ error: "token, targetServerUrl, and targetRegionId are required" });
    }

    const result = await prepareCrossServerTeleport(token, targetServerUrl, targetRegionId, x, y, z);

    if (!result.ok) {
      return reply.code(403).send({ error: result.reason });
    }

    return reply.send({
      ok: true,
      redirectUrl: result.redirectUrl,
      sessionHint: result.sessionHint,
    });
  });

  /** Handle arrival from a cross-server teleport */
  app.post<{
    Body: {
      identityToken?: FederatedIdentityToken;
      regionId?: string;
      x?: number;
      y?: number;
      z?: number;
    };
  }>("/api/federation/teleport/arrive", async (request, reply) => {
    const { identityToken, regionId, x = 0, y = 0, z = 0 } = request.body;

    if (!identityToken || !regionId) {
      return reply.code(400).send({ error: "identityToken and regionId are required" });
    }

    const result = handleTeleportArrival(identityToken, regionId, x, y, z);

    if (!result.ok) {
      return reply.code(403).send({ error: result.reason });
    }

    return reply.send({
      ok: true,
      displayName: result.displayName,
      accountId: result.accountId,
      homeServerUrl: result.homeServerUrl,
      regionId: result.regionId,
      serverName: getLocalServerName(),
      serverUrl: getLocalServerUrl(),
    });
  });

  // --------------------------------------------------------------------------
  // Federated Marketplace
  // --------------------------------------------------------------------------

  /** Search local marketplace listings (called by remote servers and local clients) */
  app.get<{
    Querystring: { query?: string };
  }>("/api/federation/marketplace/search", async (request) => {
    const query = request.query.query ?? "";
    const listings = await listLocalMarketplaceListings(query || undefined);

    return {
      listings,
      serverName: getLocalServerName(),
      serverUrl: getLocalServerUrl(),
    };
  });

  /** Search across all federated servers' marketplaces */
  app.post<{
    Body: { token?: string; query?: string };
  }>("/api/federation/marketplace/search", async (request, reply) => {
    const { token, query = "" } = request.body;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const session = getSession(token);
    if (!session) {
      return reply.code(401).send({ error: "invalid session" });
    }

    const results = await searchFederatedMarketplace(query);

    return reply.send({ results });
  });

  /** Publish an asset to the federated marketplace */
  app.post<{
    Body: {
      token?: string;
      assetId?: string;
      name?: string;
      description?: string;
      assetType?: string;
      url?: string;
      thumbnailUrl?: string | null;
      price?: number;
    };
  }>("/api/federation/marketplace/publish", async (request, reply) => {
    const { token, assetId, name, description = "", assetType, url, thumbnailUrl = null, price } = request.body;

    if (!token || !assetId || !name || !assetType || !url || !price || price <= 0) {
      return reply.code(400).send({ error: "token, assetId, name, assetType, url, and positive price are required" });
    }

    const listing = publishMarketplaceListing(token, {
      assetId,
      name,
      description,
      assetType,
      url,
      thumbnailUrl,
      price,
    });

    if (!listing) {
      return reply.code(403).send({ error: "failed to publish listing" });
    }

    return reply.send({ listing });
  });

  /** Remove an asset from the federated marketplace */
  app.delete<{
    Body: { token?: string; assetId?: string };
  }>("/api/federation/marketplace", async (request, reply) => {
    const { token, assetId } = request.body;

    if (!token || !assetId) {
      return reply.code(400).send({ error: "token and assetId are required" });
    }

    const removed = removeMarketplaceListing(token, assetId);
    if (!removed) {
      return reply.code(404).send({ error: "listing not found or not owned" });
    }

    return reply.send({ ok: true });
  });

  /** Get all marketplace listings on this server (browseable) */
  app.get("/api/federation/marketplace", async () => {
    const listings = await listLocalMarketplaceListings();
    return {
      listings,
      serverName: getLocalServerName(),
      serverUrl: getLocalServerUrl(),
    };
  });
}
