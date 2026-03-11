// Federation Service — Feature 18: Federation / Multi-Server
//
// Integration notes for server.ts:
//   import { federationRoutes } from "./routes/federation.js";
//   await app.register(federationRoutes);
//
// Integration notes for store.ts:
//   Export the federation functions if you want them accessible through the barrel:
//   export { registerFederatedServer, listFederatedServers, ... } from "./federation-service.js";

import { randomUUID, createHmac, timingSafeEqual } from "node:crypto";
import { getSession, listRegions, getRegionPopulation } from "./store.js";
import type { Session } from "./store.js";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export type FederatedServer = {
  id: string;
  name: string;
  url: string;
  description: string;
  ownerDisplayName: string;
  publicKey: string;
  regions: number;
  population: number;
  status: "online" | "offline" | "degraded";
  tags: string[];
  lastHeartbeat: string;
  registeredAt: string;
};

export type FederationHandshake = {
  serverId: string;
  challenge: string;
  issuedAt: string;
  expiresAt: string;
};

export type FederatedIdentityToken = {
  tokenId: string;
  accountId: string;
  displayName: string;
  homeServerId: string;
  homeServerUrl: string;
  issuedAt: string;
  expiresAt: string;
  signature: string;
};

export type CrossServerTeleportRequest = {
  targetServerUrl: string;
  targetRegionId: string;
  identityToken: FederatedIdentityToken;
  x: number;
  y: number;
  z: number;
};

export type CrossServerTeleportResult = {
  ok: boolean;
  redirectUrl?: string;
  sessionHint?: string;
  reason?: string;
};

export type FederatedMarketplaceListing = {
  assetId: string;
  name: string;
  description: string;
  assetType: string;
  url: string;
  thumbnailUrl: string | null;
  price: number;
  sellerDisplayName: string;
  sellerAccountId: string;
  serverName: string;
  serverUrl: string;
};

export type FederatedMarketplaceSearchResult = {
  listings: FederatedMarketplaceListing[];
  serverName: string;
  serverUrl: string;
  searchedAt: string;
};

export type ServerDirectoryEntry = {
  id: string;
  name: string;
  url: string;
  description: string;
  ownerDisplayName: string;
  regions: number;
  population: number;
  status: "online" | "offline" | "degraded";
  tags: string[];
  lastHeartbeat: string;
};

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

const federatedServers = new Map<string, FederatedServer>();
const pendingHandshakes = new Map<string, FederationHandshake>();
const trustedServerIds = new Set<string>();

const HEARTBEAT_TIMEOUT_MS = 1000 * 60 * 5; // 5 minutes
const HANDSHAKE_TTL_MS = 1000 * 60 * 2; // 2 minutes
const IDENTITY_TOKEN_TTL_MS = 1000 * 60 * 10; // 10 minutes

// The local server identity. In production this would be loaded from config / env.
let localServerId = process.env.FEDERATION_SERVER_ID ?? randomUUID();
let localServerName = process.env.FEDERATION_SERVER_NAME ?? "VibeLife Server";
let localServerUrl = process.env.FEDERATION_SERVER_URL ?? "http://localhost:3000";
let localServerSecret = process.env.FEDERATION_SECRET ?? randomUUID();

// ---------------------------------------------------------------------------
// Initialisation helpers
// ---------------------------------------------------------------------------

export function getLocalServerId(): string {
  return localServerId;
}

export function getLocalServerName(): string {
  return localServerName;
}

export function getLocalServerUrl(): string {
  return localServerUrl;
}

export function configureFederation(opts: {
  serverId?: string;
  serverName?: string;
  serverUrl?: string;
  secret?: string;
}): void {
  if (opts.serverId) localServerId = opts.serverId;
  if (opts.serverName) localServerName = opts.serverName;
  if (opts.serverUrl) localServerUrl = opts.serverUrl;
  if (opts.secret) localServerSecret = opts.secret;
}

// ---------------------------------------------------------------------------
// HMAC signing / verification for identity tokens
// ---------------------------------------------------------------------------

function signPayload(payload: string): string {
  return createHmac("sha256", localServerSecret).update(payload).digest("hex");
}

function verifySignature(payload: string, signature: string): boolean {
  const expected = createHmac("sha256", localServerSecret).update(payload).digest("hex");
  if (expected.length !== signature.length) return false;
  return timingSafeEqual(Buffer.from(expected, "hex"), Buffer.from(signature, "hex"));
}

// ---------------------------------------------------------------------------
// Server Registry
// ---------------------------------------------------------------------------

export function registerFederatedServer(input: {
  name: string;
  url: string;
  description?: string;
  ownerDisplayName?: string;
  publicKey?: string;
  tags?: string[];
}): FederatedServer {
  // Prevent duplicate URLs
  for (const [, existing] of federatedServers) {
    if (existing.url === input.url) {
      // Update existing entry
      existing.name = input.name;
      existing.description = input.description ?? existing.description;
      existing.ownerDisplayName = input.ownerDisplayName ?? existing.ownerDisplayName;
      existing.publicKey = input.publicKey ?? existing.publicKey;
      existing.tags = input.tags ?? existing.tags;
      existing.lastHeartbeat = new Date().toISOString();
      existing.status = "online";
      return existing;
    }
  }

  const server: FederatedServer = {
    id: randomUUID(),
    name: input.name,
    url: input.url.replace(/\/+$/, ""),
    description: input.description ?? "",
    ownerDisplayName: input.ownerDisplayName ?? "",
    publicKey: input.publicKey ?? "",
    regions: 0,
    population: 0,
    status: "online",
    tags: input.tags ?? [],
    lastHeartbeat: new Date().toISOString(),
    registeredAt: new Date().toISOString(),
  };

  federatedServers.set(server.id, server);
  return server;
}

export function removeFederatedServer(serverId: string): boolean {
  trustedServerIds.delete(serverId);
  return federatedServers.delete(serverId);
}

export function listFederatedServers(): FederatedServer[] {
  pruneStaleServers();
  return [...federatedServers.values()];
}

export function getFederatedServer(serverId: string): FederatedServer | undefined {
  return federatedServers.get(serverId);
}

// ---------------------------------------------------------------------------
// Heartbeat
// ---------------------------------------------------------------------------

export function heartbeat(serverId: string, stats?: { regions?: number; population?: number }): FederatedServer | undefined {
  const server = federatedServers.get(serverId);
  if (!server) return undefined;

  server.lastHeartbeat = new Date().toISOString();
  server.status = "online";
  if (stats?.regions !== undefined) server.regions = stats.regions;
  if (stats?.population !== undefined) server.population = stats.population;

  return server;
}

function pruneStaleServers(): void {
  const cutoff = Date.now() - HEARTBEAT_TIMEOUT_MS;
  for (const [id, server] of federatedServers) {
    if (new Date(server.lastHeartbeat).getTime() < cutoff) {
      server.status = "offline";
    }
  }
}

// ---------------------------------------------------------------------------
// Handshake (mutual trust establishment)
// ---------------------------------------------------------------------------

export function initiateHandshake(serverId: string): FederationHandshake | undefined {
  const server = federatedServers.get(serverId);
  if (!server) return undefined;

  const handshake: FederationHandshake = {
    serverId,
    challenge: randomUUID(),
    issuedAt: new Date().toISOString(),
    expiresAt: new Date(Date.now() + HANDSHAKE_TTL_MS).toISOString(),
  };

  pendingHandshakes.set(handshake.challenge, handshake);
  return handshake;
}

export function completeHandshake(challenge: string, response: string): { ok: boolean; serverId?: string; reason?: string } {
  const handshake = pendingHandshakes.get(challenge);
  if (!handshake) {
    return { ok: false, reason: "unknown or expired challenge" };
  }

  if (new Date(handshake.expiresAt).getTime() < Date.now()) {
    pendingHandshakes.delete(challenge);
    return { ok: false, reason: "challenge expired" };
  }

  // The remote server should sign the challenge with the shared secret.
  // For simplicity we verify the challenge string echoed back matches.
  const expectedResponse = signPayload(challenge);
  if (response !== expectedResponse) {
    // Accept the raw challenge echo as a fallback for initial bootstrapping
    if (response !== challenge) {
      pendingHandshakes.delete(challenge);
      return { ok: false, reason: "invalid challenge response" };
    }
  }

  pendingHandshakes.delete(challenge);
  trustedServerIds.add(handshake.serverId);

  return { ok: true, serverId: handshake.serverId };
}

export function isServerTrusted(serverId: string): boolean {
  return trustedServerIds.has(serverId);
}

// ---------------------------------------------------------------------------
// Federated Identity — Portable Tokens
// ---------------------------------------------------------------------------

export function issueIdentityToken(token: string): FederatedIdentityToken | undefined {
  const session = getSession(token);
  if (!session) return undefined;

  const payload = JSON.stringify({
    accountId: session.accountId,
    displayName: session.displayName,
    homeServerId: localServerId,
    homeServerUrl: localServerUrl,
    issuedAt: new Date().toISOString(),
    expiresAt: new Date(Date.now() + IDENTITY_TOKEN_TTL_MS).toISOString(),
  });

  const signature = signPayload(payload);

  const identityToken: FederatedIdentityToken = {
    tokenId: randomUUID(),
    accountId: session.accountId,
    displayName: session.displayName,
    homeServerId: localServerId,
    homeServerUrl: localServerUrl,
    issuedAt: new Date().toISOString(),
    expiresAt: new Date(Date.now() + IDENTITY_TOKEN_TTL_MS).toISOString(),
    signature,
  };

  return identityToken;
}

export function verifyIdentityToken(identityToken: FederatedIdentityToken): { valid: boolean; reason?: string } {
  // Check expiry
  if (new Date(identityToken.expiresAt).getTime() < Date.now()) {
    return { valid: false, reason: "identity token expired" };
  }

  // If this token was issued by us, verify signature
  if (identityToken.homeServerId === localServerId) {
    const payload = JSON.stringify({
      accountId: identityToken.accountId,
      displayName: identityToken.displayName,
      homeServerId: identityToken.homeServerId,
      homeServerUrl: identityToken.homeServerUrl,
      issuedAt: identityToken.issuedAt,
      expiresAt: identityToken.expiresAt,
    });

    if (!verifySignature(payload, identityToken.signature)) {
      return { valid: false, reason: "invalid signature" };
    }
  }

  // For tokens from remote servers, we would call back to their
  // /api/federation/identity/verify endpoint. For now, we trust
  // tokens from servers in our trusted set.
  if (identityToken.homeServerId !== localServerId) {
    const remoteServer = [...federatedServers.values()].find(
      (s) => s.id === identityToken.homeServerId || s.url === identityToken.homeServerUrl
    );

    if (!remoteServer) {
      return { valid: false, reason: "unknown home server" };
    }

    if (remoteServer.status === "offline") {
      return { valid: false, reason: "home server is offline" };
    }

    // In production, we would make an HTTP callback here to verify.
    // For now we accept if the server is registered and trusted.
    if (!trustedServerIds.has(remoteServer.id)) {
      return { valid: false, reason: "home server is not trusted" };
    }
  }

  return { valid: true };
}

// ---------------------------------------------------------------------------
// Cross-Server Teleportation
// ---------------------------------------------------------------------------

export async function prepareCrossServerTeleport(
  token: string,
  targetServerUrl: string,
  targetRegionId: string,
  x: number,
  y: number,
  z: number
): Promise<CrossServerTeleportResult> {
  const session = getSession(token);
  if (!session) {
    return { ok: false, reason: "invalid session" };
  }

  // Find the target server in our registry
  const targetServer = [...federatedServers.values()].find(
    (s) => s.url === targetServerUrl.replace(/\/+$/, "")
  );

  if (!targetServer) {
    return { ok: false, reason: "target server not found in federation directory" };
  }

  if (targetServer.status === "offline") {
    return { ok: false, reason: "target server is offline" };
  }

  // Issue a portable identity token for the user
  const identityToken = issueIdentityToken(token);
  if (!identityToken) {
    return { ok: false, reason: "failed to issue identity token" };
  }

  // Build the redirect URL. The client will use this to connect to the remote server.
  const params = new URLSearchParams({
    identityToken: JSON.stringify(identityToken),
    regionId: targetRegionId,
    x: String(x),
    y: String(y),
    z: String(z),
  });

  const redirectUrl = `${targetServer.url}/api/federation/teleport/arrive?${params.toString()}`;

  return {
    ok: true,
    redirectUrl,
    sessionHint: identityToken.tokenId,
  };
}

export function handleTeleportArrival(identityToken: FederatedIdentityToken, regionId: string, x: number, y: number, z: number): {
  ok: boolean;
  displayName?: string;
  accountId?: string;
  homeServerUrl?: string;
  regionId?: string;
  reason?: string;
} {
  const verification = verifyIdentityToken(identityToken);
  if (!verification.valid) {
    return { ok: false, reason: verification.reason };
  }

  // Check that the target region exists locally
  const regions = listRegions();
  const region = regions.find((r) => r.id === regionId);
  if (!region) {
    return { ok: false, reason: "region not found on this server" };
  }

  // The client will need to create a guest session on this server using the
  // federated identity display name. We return the info needed for that.
  return {
    ok: true,
    displayName: identityToken.displayName,
    accountId: identityToken.accountId,
    homeServerUrl: identityToken.homeServerUrl,
    regionId,
  };
}

// ---------------------------------------------------------------------------
// Federated Marketplace
// ---------------------------------------------------------------------------

export async function listLocalMarketplaceListings(query?: string): Promise<FederatedMarketplaceListing[]> {
  // Gather all assets with a price > 0 from all sessions — in practice this
  // would query the persistence layer directly. We approximate by listing
  // assets visible to a system-level query. Since listAssets requires a token,
  // we expose a reduced set: all assets across known accounts. For the MVP
  // we return an empty list when there's no global asset query. A production
  // implementation would add persistence.listAllPublicAssets().
  //
  // For now, return listings from the in-memory federation cache of published
  // marketplace items (populated via publishMarketplaceListing).
  const results: FederatedMarketplaceListing[] = [];

  for (const listing of localMarketplaceListings.values()) {
    if (query) {
      const q = query.toLowerCase();
      if (
        !listing.name.toLowerCase().includes(q) &&
        !listing.description.toLowerCase().includes(q) &&
        !listing.assetType.toLowerCase().includes(q)
      ) {
        continue;
      }
    }
    results.push(listing);
  }

  return results;
}

const localMarketplaceListings = new Map<string, FederatedMarketplaceListing>();

export function publishMarketplaceListing(token: string, asset: {
  assetId: string;
  name: string;
  description: string;
  assetType: string;
  url: string;
  thumbnailUrl: string | null;
  price: number;
}): FederatedMarketplaceListing | undefined {
  const session = getSession(token);
  if (!session) return undefined;
  if (asset.price <= 0) return undefined;

  const listing: FederatedMarketplaceListing = {
    assetId: asset.assetId,
    name: asset.name,
    description: asset.description,
    assetType: asset.assetType,
    url: asset.url,
    thumbnailUrl: asset.thumbnailUrl,
    price: asset.price,
    sellerDisplayName: session.displayName,
    sellerAccountId: session.accountId,
    serverName: localServerName,
    serverUrl: localServerUrl,
  };

  localMarketplaceListings.set(asset.assetId, listing);
  return listing;
}

export function removeMarketplaceListing(token: string, assetId: string): boolean {
  const session = getSession(token);
  if (!session) return false;

  const listing = localMarketplaceListings.get(assetId);
  if (!listing) return false;
  if (listing.sellerAccountId !== session.accountId && session.role !== "admin") return false;

  return localMarketplaceListings.delete(assetId);
}

export async function searchFederatedMarketplace(query: string): Promise<FederatedMarketplaceSearchResult[]> {
  const results: FederatedMarketplaceSearchResult[] = [];

  // Always include local results
  const localListings = await listLocalMarketplaceListings(query);
  if (localListings.length > 0) {
    results.push({
      listings: localListings,
      serverName: localServerName,
      serverUrl: localServerUrl,
      searchedAt: new Date().toISOString(),
    });
  }

  // Query each federated server's marketplace endpoint
  pruneStaleServers();
  for (const [, server] of federatedServers) {
    if (server.status === "offline") continue;

    try {
      const url = `${server.url}/api/federation/marketplace/search?query=${encodeURIComponent(query)}`;
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 5000);

      const response = await fetch(url, {
        method: "GET",
        headers: { "Content-Type": "application/json" },
        signal: controller.signal,
      });

      clearTimeout(timeout);

      if (response.ok) {
        const data = (await response.json()) as { listings?: FederatedMarketplaceListing[] };
        if (data.listings && data.listings.length > 0) {
          results.push({
            listings: data.listings,
            serverName: server.name,
            serverUrl: server.url,
            searchedAt: new Date().toISOString(),
          });
        }
      }
    } catch {
      // Remote server unreachable — skip silently
    }
  }

  return results;
}

// ---------------------------------------------------------------------------
// Server Directory with health / population stats
// ---------------------------------------------------------------------------

export function getServerDirectory(): ServerDirectoryEntry[] {
  pruneStaleServers();

  const entries: ServerDirectoryEntry[] = [];

  // Include self
  const allRegions = listRegions();
  let totalPopulation = 0;
  for (const region of allRegions) {
    totalPopulation += getRegionPopulation(region.id).length;
  }

  entries.push({
    id: localServerId,
    name: localServerName,
    url: localServerUrl,
    description: "This server (local)",
    ownerDisplayName: "",
    regions: allRegions.length,
    population: totalPopulation,
    status: "online",
    tags: ["local"],
    lastHeartbeat: new Date().toISOString(),
  });

  // Include federated servers
  for (const [, server] of federatedServers) {
    entries.push({
      id: server.id,
      name: server.name,
      url: server.url,
      description: server.description,
      ownerDisplayName: server.ownerDisplayName,
      regions: server.regions,
      population: server.population,
      status: server.status,
      tags: server.tags,
      lastHeartbeat: server.lastHeartbeat,
    });
  }

  return entries;
}

export function getLocalServerStats(): {
  serverId: string;
  serverName: string;
  serverUrl: string;
  regions: number;
  population: number;
  federatedServers: number;
  trustedServers: number;
} {
  const allRegions = listRegions();
  let totalPopulation = 0;
  for (const region of allRegions) {
    totalPopulation += getRegionPopulation(region.id).length;
  }

  return {
    serverId: localServerId,
    serverName: localServerName,
    serverUrl: localServerUrl,
    regions: allRegions.length,
    population: totalPopulation,
    federatedServers: federatedServers.size,
    trustedServers: trustedServerIds.size,
  };
}
