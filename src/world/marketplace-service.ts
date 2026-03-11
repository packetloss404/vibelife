import { randomUUID } from "node:crypto";

export type MarketListing = {
  id: string;
  sellerAccountId: string;
  sellerDisplayName: string;
  itemId: string;
  itemName: string;
  itemKind: string;
  price: number;
  listingType: "fixed" | "auction";
  currentBid?: number;
  currentBidder?: string;
  currentBidderName?: string;
  minBid?: number;
  auctionEndTime?: string;
  createdAt: string;
  status: "active" | "sold" | "expired" | "cancelled";
};

export type TradeOffer = {
  id: string;
  fromAccountId: string;
  fromDisplayName: string;
  toAccountId: string;
  toDisplayName: string;
  offeredItems: string[];
  offeredCurrency: number;
  requestedItems: string[];
  requestedCurrency: number;
  status: "pending" | "accepted" | "declined" | "cancelled";
  createdAt: string;
};

type PriceHistoryEntry = {
  itemName: string;
  price: number;
  soldAt: string;
};

const listings = new Map<string, MarketListing>();
const trades = new Map<string, TradeOffer>();
const priceHistory: PriceHistoryEntry[] = [];
const heldCurrency = new Map<string, number>();

function holdCurrency(accountId: string, amount: number): void {
  const current = heldCurrency.get(accountId) ?? 0;
  heldCurrency.set(accountId, current + amount);
}

function releaseHeldCurrency(accountId: string, amount: number): void {
  const current = heldCurrency.get(accountId) ?? 0;
  heldCurrency.set(accountId, Math.max(0, current - amount));
}

function getAvailableBalance(balance: number, accountId: string): number {
  const held = heldCurrency.get(accountId) ?? 0;
  return balance - held;
}

// These will be set by initMarketplace() to avoid circular imports
let _getSession: (token: string) => { accountId: string; displayName: string } | undefined;
let _getCurrencyBalance: (token: string) => Promise<number>;
let _sendCurrency: (token: string, toAccountId: string, amount: number, description: string) => Promise<number | undefined>;
let _getInventory: (accountId: string) => Promise<{ id: string; name: string; kind: string }[]>;

export function initMarketplace(deps: {
  getSession: (token: string) => { accountId: string; displayName: string } | undefined;
  getCurrencyBalance: (token: string) => Promise<number>;
  sendCurrency: (token: string, toAccountId: string, amount: number, description: string) => Promise<number | undefined>;
  getInventory: (accountId: string) => Promise<{ id: string; name: string; kind: string }[]>;
}) {
  _getSession = deps.getSession;
  _getCurrencyBalance = deps.getCurrencyBalance;
  _sendCurrency = deps.sendCurrency;
  _getInventory = deps.getInventory;
}

export async function createListing(
  token: string,
  itemId: string,
  price: number,
  listingType: "fixed" | "auction",
  auctionEndTime?: string
): Promise<MarketListing | undefined> {
  const session = _getSession(token);
  if (!session) return undefined;
  if (price <= 0) return undefined;

  const inventory = await _getInventory(session.accountId);
  const item = inventory.find((i) => i.id === itemId);
  if (!item) return undefined;

  // Check item is not already listed
  for (const listing of listings.values()) {
    if (listing.itemId === itemId && listing.status === "active") return undefined;
  }

  const listing: MarketListing = {
    id: randomUUID(),
    sellerAccountId: session.accountId,
    sellerDisplayName: session.displayName,
    itemId,
    itemName: item.name,
    itemKind: item.kind,
    price,
    listingType,
    createdAt: new Date().toISOString(),
    status: "active",
  };

  if (listingType === "auction") {
    listing.minBid = price;
    listing.currentBid = 0;
    listing.auctionEndTime = auctionEndTime ?? new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
  }

  listings.set(listing.id, listing);
  return listing;
}

export async function listMarketplace(filters?: {
  kind?: string;
  minPrice?: number;
  maxPrice?: number;
  sort?: string;
}): Promise<MarketListing[]> {
  let results = [...listings.values()].filter((l) => l.status === "active");

  // Expire auctions
  const now = new Date();
  for (const listing of results) {
    if (listing.listingType === "auction" && listing.auctionEndTime && new Date(listing.auctionEndTime) < now) {
      listing.status = "expired";
      if (listing.currentBidder && listing.currentBid && listing.currentBid > 0) {
        releaseHeldCurrency(listing.currentBidder, listing.currentBid);
      }
    }
  }

  results = results.filter((l) => l.status === "active");

  if (filters?.kind) {
    results = results.filter((l) => l.itemKind === filters.kind);
  }
  if (filters?.minPrice !== undefined) {
    results = results.filter((l) => {
      const effectivePrice = l.listingType === "auction" ? (l.currentBid && l.currentBid > 0 ? l.currentBid : l.minBid ?? l.price) : l.price;
      return effectivePrice >= filters.minPrice!;
    });
  }
  if (filters?.maxPrice !== undefined) {
    results = results.filter((l) => {
      const effectivePrice = l.listingType === "auction" ? (l.currentBid && l.currentBid > 0 ? l.currentBid : l.minBid ?? l.price) : l.price;
      return effectivePrice <= filters.maxPrice!;
    });
  }

  if (filters?.sort === "price_asc") {
    results.sort((a, b) => a.price - b.price);
  } else if (filters?.sort === "price_desc") {
    results.sort((a, b) => b.price - a.price);
  } else {
    results.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
  }

  return results;
}

export async function buyListing(token: string, listingId: string): Promise<{ ok: boolean; reason?: string }> {
  const session = _getSession(token);
  if (!session) return { ok: false, reason: "invalid session" };

  const listing = listings.get(listingId);
  if (!listing) return { ok: false, reason: "listing not found" };
  if (listing.status !== "active") return { ok: false, reason: "listing is no longer active" };
  if (listing.listingType !== "fixed") return { ok: false, reason: "cannot buy auction listing directly" };
  if (listing.sellerAccountId === session.accountId) return { ok: false, reason: "cannot buy your own listing" };

  const balance = await _getCurrencyBalance(token);
  const available = getAvailableBalance(balance, session.accountId);
  if (available < listing.price) return { ok: false, reason: "insufficient funds" };

  const result = await _sendCurrency(token, listing.sellerAccountId, listing.price, `Marketplace purchase: ${listing.itemName}`);
  if (result === undefined) return { ok: false, reason: "currency transfer failed" };

  listing.status = "sold";

  priceHistory.push({
    itemName: listing.itemName,
    price: listing.price,
    soldAt: new Date().toISOString(),
  });

  return { ok: true };
}

export async function placeBid(token: string, listingId: string, amount: number): Promise<{ ok: boolean; reason?: string }> {
  const session = _getSession(token);
  if (!session) return { ok: false, reason: "invalid session" };

  const listing = listings.get(listingId);
  if (!listing) return { ok: false, reason: "listing not found" };
  if (listing.status !== "active") return { ok: false, reason: "listing is no longer active" };
  if (listing.listingType !== "auction") return { ok: false, reason: "listing is not an auction" };
  if (listing.sellerAccountId === session.accountId) return { ok: false, reason: "cannot bid on your own listing" };

  if (listing.auctionEndTime && new Date(listing.auctionEndTime) < new Date()) {
    listing.status = "expired";
    return { ok: false, reason: "auction has ended" };
  }

  const minRequired = listing.currentBid && listing.currentBid > 0 ? listing.currentBid + 1 : (listing.minBid ?? listing.price);
  if (amount < minRequired) return { ok: false, reason: `bid must be at least ${minRequired}` };

  const balance = await _getCurrencyBalance(token);
  const available = getAvailableBalance(balance, session.accountId);
  if (available < amount) return { ok: false, reason: "insufficient funds" };

  // Release previous bidder's held currency
  if (listing.currentBidder && listing.currentBid && listing.currentBid > 0) {
    releaseHeldCurrency(listing.currentBidder, listing.currentBid);
  }

  holdCurrency(session.accountId, amount);

  listing.currentBid = amount;
  listing.currentBidder = session.accountId;
  listing.currentBidderName = session.displayName;

  return { ok: true };
}

export async function cancelListing(token: string, listingId: string): Promise<{ ok: boolean; reason?: string }> {
  const session = _getSession(token);
  if (!session) return { ok: false, reason: "invalid session" };

  const listing = listings.get(listingId);
  if (!listing) return { ok: false, reason: "listing not found" };
  if (listing.sellerAccountId !== session.accountId) return { ok: false, reason: "not your listing" };
  if (listing.status !== "active") return { ok: false, reason: "listing is no longer active" };

  if (listing.currentBidder && listing.currentBid && listing.currentBid > 0) {
    releaseHeldCurrency(listing.currentBidder, listing.currentBid);
  }

  listing.status = "cancelled";
  return { ok: true };
}

export async function getListingHistory(token: string): Promise<MarketListing[]> {
  const session = _getSession(token);
  if (!session) return [];

  return [...listings.values()]
    .filter((l) => l.sellerAccountId === session.accountId)
    .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
}

export async function getPriceHistory(itemName: string): Promise<PriceHistoryEntry[]> {
  return priceHistory
    .filter((e) => e.itemName === itemName)
    .sort((a, b) => new Date(b.soldAt).getTime() - new Date(a.soldAt).getTime())
    .slice(0, 50);
}

export async function createTradeOffer(
  token: string,
  toAccountId: string,
  offeredItems: string[],
  offeredCurrency: number,
  requestedItems: string[],
  requestedCurrency: number
): Promise<TradeOffer | undefined> {
  const session = _getSession(token);
  if (!session) return undefined;
  if (session.accountId === toAccountId) return undefined;
  if (offeredCurrency < 0 || requestedCurrency < 0) return undefined;

  if (offeredCurrency > 0) {
    const balance = await _getCurrencyBalance(token);
    const available = getAvailableBalance(balance, session.accountId);
    if (available < offeredCurrency) return undefined;
  }

  const trade: TradeOffer = {
    id: randomUUID(),
    fromAccountId: session.accountId,
    fromDisplayName: session.displayName,
    toAccountId,
    toDisplayName: "",
    offeredItems,
    offeredCurrency,
    requestedItems,
    requestedCurrency,
    status: "pending",
    createdAt: new Date().toISOString(),
  };

  trades.set(trade.id, trade);
  return trade;
}

export async function acceptTrade(token: string, tradeId: string): Promise<{ ok: boolean; reason?: string }> {
  const session = _getSession(token);
  if (!session) return { ok: false, reason: "invalid session" };

  const trade = trades.get(tradeId);
  if (!trade) return { ok: false, reason: "trade not found" };
  if (trade.toAccountId !== session.accountId) return { ok: false, reason: "not your trade to accept" };
  if (trade.status !== "pending") return { ok: false, reason: "trade is no longer pending" };

  if (trade.requestedCurrency > 0) {
    const balance = await _getCurrencyBalance(token);
    const available = getAvailableBalance(balance, session.accountId);
    if (available < trade.requestedCurrency) return { ok: false, reason: "you have insufficient funds" };
  }

  if (trade.requestedCurrency > 0) {
    const result = await _sendCurrency(token, trade.fromAccountId, trade.requestedCurrency, `Trade accepted: ${tradeId}`);
    if (result === undefined) return { ok: false, reason: "currency transfer failed" };
  }

  trade.status = "accepted";
  trade.toDisplayName = session.displayName;
  return { ok: true };
}

export async function declineTrade(token: string, tradeId: string): Promise<{ ok: boolean; reason?: string }> {
  const session = _getSession(token);
  if (!session) return { ok: false, reason: "invalid session" };

  const trade = trades.get(tradeId);
  if (!trade) return { ok: false, reason: "trade not found" };
  if (trade.toAccountId !== session.accountId && trade.fromAccountId !== session.accountId) {
    return { ok: false, reason: "not your trade" };
  }
  if (trade.status !== "pending") return { ok: false, reason: "trade is no longer pending" };

  trade.status = trade.fromAccountId === session.accountId ? "cancelled" : "declined";
  return { ok: true };
}

export async function listTradeOffers(token: string): Promise<TradeOffer[]> {
  const session = _getSession(token);
  if (!session) return [];

  return [...trades.values()]
    .filter((t) => (t.fromAccountId === session.accountId || t.toAccountId === session.accountId) && t.status === "pending")
    .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
}
