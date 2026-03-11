import { getSession, listParcels, listRegions, getRegionPopulation } from "./store.js";
import type { Session } from "./store.js";

export type HomeRating = {
  accountId: string;
  displayName: string;
  rating: number;
  createdAt: string;
};

export type HomeRatingsSummary = {
  averageRating: number;
  totalRatings: number;
  ratings: HomeRating[];
};

export type FeaturedHome = {
  parcelId: string;
  parcelName: string;
  ownerDisplayName: string;
  regionId: string;
  averageRating: number;
  totalRatings: number;
  visitorCount: number;
};

// parcelId -> ratings[]
const ratingsByParcel = new Map<string, HomeRating[]>();

// accountId -> Set<parcelId>
const favoritesByAccount = new Map<string, Set<string>>();

// parcelId -> visitor count
const visitorCountByParcel = new Map<string, number>();

export function rateHome(
  token: string,
  parcelId: string,
  rating: number
): HomeRatingsSummary | undefined {
  const session = getSession(token);
  if (!session) return undefined;

  const clampedRating = Math.max(1, Math.min(5, Math.round(rating)));

  let ratings = ratingsByParcel.get(parcelId);
  if (!ratings) {
    ratings = [];
    ratingsByParcel.set(parcelId, ratings);
  }

  const existing = ratings.find((r) => r.accountId === session.accountId);
  if (existing) {
    existing.rating = clampedRating;
    existing.createdAt = new Date().toISOString();
  } else {
    ratings.push({
      accountId: session.accountId,
      displayName: session.displayName,
      rating: clampedRating,
      createdAt: new Date().toISOString(),
    });
  }

  return getHomeRatings(parcelId);
}

export function favoriteHome(
  token: string,
  parcelId: string
): { favorited: boolean } | undefined {
  const session = getSession(token);
  if (!session) return undefined;

  let favorites = favoritesByAccount.get(session.accountId);
  if (!favorites) {
    favorites = new Set<string>();
    favoritesByAccount.set(session.accountId, favorites);
  }

  if (favorites.has(parcelId)) {
    favorites.delete(parcelId);
    return { favorited: false };
  }

  favorites.add(parcelId);
  return { favorited: true };
}

export function getHomeRatings(parcelId: string): HomeRatingsSummary {
  const ratings = ratingsByParcel.get(parcelId) ?? [];
  const total = ratings.length;
  const average =
    total > 0
      ? ratings.reduce((sum, r) => sum + r.rating, 0) / total
      : 0;

  return {
    averageRating: Math.round(average * 100) / 100,
    totalRatings: total,
    ratings,
  };
}

export function getHomeVisitorCount(parcelId: string): number {
  return visitorCountByParcel.get(parcelId) ?? 0;
}

export function incrementVisitorCount(parcelId: string): void {
  const current = visitorCountByParcel.get(parcelId) ?? 0;
  visitorCountByParcel.set(parcelId, current + 1);
}

export function getFavoriteHomes(token: string): string[] {
  const session = getSession(token);
  if (!session) return [];

  const favorites = favoritesByAccount.get(session.accountId);
  if (!favorites) return [];

  return [...favorites];
}

export async function getFeaturedHomes(limit: number = 10): Promise<FeaturedHome[]> {
  const allParcels: FeaturedHome[] = [];
  const regions = listRegions();

  for (const region of regions) {
    const parcels = await listParcels(region.id);

    for (const parcel of parcels) {
      if (!parcel.ownerAccountId) continue;

      const summary = getHomeRatings(parcel.id);
      if (summary.totalRatings === 0) continue;

      allParcels.push({
        parcelId: parcel.id,
        parcelName: parcel.name,
        ownerDisplayName: parcel.ownerDisplayName ?? "Unknown",
        regionId: region.id,
        averageRating: summary.averageRating,
        totalRatings: summary.totalRatings,
        visitorCount: getHomeVisitorCount(parcel.id),
      });
    }
  }

  allParcels.sort((a, b) => b.averageRating - a.averageRating);
  return allParcels.slice(0, Math.max(1, Math.min(50, limit)));
}

export async function getShowcaseHomes(): Promise<FeaturedHome[]> {
  return getFeaturedHomes(5);
}
