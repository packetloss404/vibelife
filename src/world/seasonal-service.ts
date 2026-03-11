import { randomUUID } from "node:crypto";
import { getSession } from "./store.js";

// --- Types ---

export type Season = "spring" | "summer" | "autumn" | "winter";

export type Holiday = {
  id: string;
  name: string;
  season: Season;
  startDate: string; // MM-DD
  endDate: string;   // MM-DD
  decorationType: string;
  specialItems: string[];
  description: string;
};

export type SeasonalItem = {
  id: string;
  name: string;
  description: string;
  season: Season;
  holiday?: string;
  rarity: "common" | "uncommon" | "rare" | "legendary";
  type: "decoration" | "wearable" | "emote" | "pet_accessory" | "consumable";
  available: boolean;
  expiresAt?: string;
};

export type SeasonalDecoration = {
  id: string;
  regionId: string;
  objectId: string;
  decorationType: string;
  season: Season;
  holiday?: string;
  placedAt: string;
};

export type SeasonalAchievement = {
  id: string;
  name: string;
  description: string;
  season: Season;
  requirement: { type: string; count: number };
  xpReward: number;
  badgeIcon: string;
};

export type PlayerSeasonalProgress = {
  accountId: string;
  season: Season;
  itemsCollected: string[];
  achievementsUnlocked: string[];
  eventParticipations: number;
};

export type SeasonalTheme = {
  season: Season;
  fogColor: string;
  sunColor: string;
  skyTint: string;
  ambientParticles: string;
  ambientIntensity: number;
};

// --- Predefined Data ---

const HOLIDAYS: Holiday[] = [
  {
    id: "valentines",
    name: "Valentine's Day",
    season: "winter",
    startDate: "02-10",
    endDate: "02-16",
    decorationType: "hearts",
    specialItems: ["heart_bouquet", "love_letter_emote"],
    description: "Celebrate love and friendship with heart decorations and special emotes."
  },
  {
    id: "spring_festival",
    name: "Spring Festival",
    season: "spring",
    startDate: "03-20",
    endDate: "04-05",
    decorationType: "blossoms",
    specialItems: ["cherry_blossom_crown", "spring_lantern"],
    description: "Welcome spring with blooming flowers and festive lanterns."
  },
  {
    id: "summer_beach",
    name: "Summer Beach Party",
    season: "summer",
    startDate: "07-01",
    endDate: "07-21",
    decorationType: "tropical",
    specialItems: ["surfboard_accessory", "beach_ball_emote", "tiki_torch"],
    description: "Hit the beach with tropical decorations and summer vibes."
  },
  {
    id: "halloween",
    name: "Halloween",
    season: "autumn",
    startDate: "10-20",
    endDate: "11-02",
    decorationType: "spooky",
    specialItems: ["witch_hat", "ghost_pet", "jack_o_lantern"],
    description: "Spooky season arrives with costumes, ghosts, and jack-o-lanterns."
  },
  {
    id: "harvest_festival",
    name: "Harvest Festival",
    season: "autumn",
    startDate: "11-15",
    endDate: "11-30",
    decorationType: "harvest",
    specialItems: ["cornucopia_hat", "harvest_wreath"],
    description: "Celebrate the bountiful harvest with rustic decorations."
  },
  {
    id: "winter_wonderland",
    name: "Winter Wonderland",
    season: "winter",
    startDate: "12-15",
    endDate: "12-31",
    decorationType: "winter_lights",
    specialItems: ["snowflake_crown", "ice_crystal_pet", "holiday_sweater"],
    description: "A winter celebration with twinkling lights and falling snow."
  },
  {
    id: "new_year",
    name: "New Year's Celebration",
    season: "winter",
    startDate: "12-30",
    endDate: "01-03",
    decorationType: "fireworks",
    specialItems: ["party_hat", "firework_emote", "confetti_popper"],
    description: "Ring in the new year with fireworks and celebration."
  }
];

const SEASONAL_ITEMS: SeasonalItem[] = [
  // Spring
  { id: "cherry_blossom_crown", name: "Cherry Blossom Crown", description: "A delicate crown of pink petals", season: "spring", holiday: "spring_festival", rarity: "rare", type: "wearable", available: true },
  { id: "spring_lantern", name: "Spring Lantern", description: "A glowing paper lantern", season: "spring", holiday: "spring_festival", rarity: "uncommon", type: "decoration", available: true },
  { id: "butterfly_emote", name: "Butterfly Dance", description: "Summon butterflies around you", season: "spring", rarity: "common", type: "emote", available: true },
  { id: "garden_bouquet", name: "Garden Bouquet", description: "A fresh bunch of wildflowers", season: "spring", rarity: "common", type: "consumable", available: true },
  // Summer
  { id: "surfboard_accessory", name: "Surfboard", description: "Carry a rad surfboard on your back", season: "summer", holiday: "summer_beach", rarity: "rare", type: "wearable", available: true },
  { id: "beach_ball_emote", name: "Beach Ball Toss", description: "Toss a beach ball into the air", season: "summer", holiday: "summer_beach", rarity: "common", type: "emote", available: true },
  { id: "tiki_torch", name: "Tiki Torch", description: "A tropical flaming torch", season: "summer", holiday: "summer_beach", rarity: "uncommon", type: "decoration", available: true },
  { id: "sunglasses", name: "Cool Sunglasses", description: "Stylish shades for sunny days", season: "summer", rarity: "common", type: "wearable", available: true },
  // Autumn
  { id: "witch_hat", name: "Witch Hat", description: "A pointy purple witch hat", season: "autumn", holiday: "halloween", rarity: "uncommon", type: "wearable", available: true },
  { id: "ghost_pet", name: "Ghost Companion", description: "A friendly floating ghost follows you", season: "autumn", holiday: "halloween", rarity: "legendary", type: "pet_accessory", available: true },
  { id: "jack_o_lantern", name: "Jack-o-Lantern", description: "A glowing carved pumpkin", season: "autumn", holiday: "halloween", rarity: "common", type: "decoration", available: true },
  { id: "cornucopia_hat", name: "Cornucopia Hat", description: "A hat overflowing with fall produce", season: "autumn", holiday: "harvest_festival", rarity: "rare", type: "wearable", available: true },
  { id: "harvest_wreath", name: "Harvest Wreath", description: "A decorative wreath of autumn leaves", season: "autumn", holiday: "harvest_festival", rarity: "uncommon", type: "decoration", available: true },
  // Winter
  { id: "snowflake_crown", name: "Snowflake Crown", description: "An icy crown that sparkles", season: "winter", holiday: "winter_wonderland", rarity: "rare", type: "wearable", available: true },
  { id: "ice_crystal_pet", name: "Ice Crystal Companion", description: "A floating ice crystal follows you", season: "winter", holiday: "winter_wonderland", rarity: "legendary", type: "pet_accessory", available: true },
  { id: "holiday_sweater", name: "Holiday Sweater", description: "A cozy festive sweater", season: "winter", holiday: "winter_wonderland", rarity: "common", type: "wearable", available: true },
  { id: "heart_bouquet", name: "Heart Bouquet", description: "A bouquet of red roses shaped like a heart", season: "winter", holiday: "valentines", rarity: "uncommon", type: "consumable", available: true },
  { id: "love_letter_emote", name: "Love Letter", description: "Send a floating love letter", season: "winter", holiday: "valentines", rarity: "common", type: "emote", available: true },
  { id: "party_hat", name: "Party Hat", description: "A sparkly New Year's party hat", season: "winter", holiday: "new_year", rarity: "uncommon", type: "wearable", available: true },
  { id: "firework_emote", name: "Firework Burst", description: "Launch a firework above your head", season: "winter", holiday: "new_year", rarity: "rare", type: "emote", available: true },
  { id: "confetti_popper", name: "Confetti Popper", description: "Pop confetti into the air", season: "winter", holiday: "new_year", rarity: "common", type: "consumable", available: true }
];

const SEASONAL_ACHIEVEMENTS: SeasonalAchievement[] = [
  { id: "spring_collector", name: "Spring Collector", description: "Collect 3 spring items", season: "spring", requirement: { type: "collect", count: 3 }, xpReward: 100, badgeIcon: "spring_badge" },
  { id: "summer_collector", name: "Summer Collector", description: "Collect 3 summer items", season: "summer", requirement: { type: "collect", count: 3 }, xpReward: 100, badgeIcon: "summer_badge" },
  { id: "autumn_collector", name: "Autumn Collector", description: "Collect 3 autumn items", season: "autumn", requirement: { type: "collect", count: 3 }, xpReward: 100, badgeIcon: "autumn_badge" },
  { id: "winter_collector", name: "Winter Collector", description: "Collect 3 winter items", season: "winter", requirement: { type: "collect", count: 3 }, xpReward: 100, badgeIcon: "winter_badge" },
  { id: "spring_decorator", name: "Spring Decorator", description: "Place 5 spring decorations", season: "spring", requirement: { type: "decorate", count: 5 }, xpReward: 150, badgeIcon: "spring_deco_badge" },
  { id: "summer_decorator", name: "Summer Decorator", description: "Place 5 summer decorations", season: "summer", requirement: { type: "decorate", count: 5 }, xpReward: 150, badgeIcon: "summer_deco_badge" },
  { id: "autumn_decorator", name: "Autumn Decorator", description: "Place 5 autumn decorations", season: "autumn", requirement: { type: "decorate", count: 5 }, xpReward: 150, badgeIcon: "autumn_deco_badge" },
  { id: "winter_decorator", name: "Winter Decorator", description: "Place 5 winter decorations", season: "winter", requirement: { type: "decorate", count: 5 }, xpReward: 150, badgeIcon: "winter_deco_badge" },
  { id: "event_enthusiast", name: "Event Enthusiast", description: "Participate in 3 seasonal events", season: "spring", requirement: { type: "participate", count: 3 }, xpReward: 200, badgeIcon: "enthusiast_badge" },
  { id: "legendary_finder", name: "Legendary Finder", description: "Collect a legendary seasonal item", season: "summer", requirement: { type: "collect_legendary", count: 1 }, xpReward: 300, badgeIcon: "legendary_badge" }
];

const SEASONAL_THEMES: Record<Season, SeasonalTheme> = {
  spring: {
    season: "spring",
    fogColor: "#c8e6c9",
    sunColor: "#fff9c4",
    skyTint: "#e1f5fe",
    ambientParticles: "cherry_blossoms",
    ambientIntensity: 0.7
  },
  summer: {
    season: "summer",
    fogColor: "#fff3e0",
    sunColor: "#ffecb3",
    skyTint: "#bbdefb",
    ambientParticles: "fireflies",
    ambientIntensity: 0.5
  },
  autumn: {
    season: "autumn",
    fogColor: "#efebe9",
    sunColor: "#ffe0b2",
    skyTint: "#ffccbc",
    ambientParticles: "falling_leaves",
    ambientIntensity: 0.8
  },
  winter: {
    season: "winter",
    fogColor: "#eceff1",
    sunColor: "#e0e0e0",
    skyTint: "#cfd8dc",
    ambientParticles: "snowflakes",
    ambientIntensity: 0.9
  }
};

// --- In-memory stores ---

const playerProgress = new Map<string, PlayerSeasonalProgress>();
const seasonalDecorations = new Map<string, SeasonalDecoration[]>();

// --- Helper ---

function todayMMDD(): string {
  const now = new Date();
  const mm = String(now.getMonth() + 1).padStart(2, "0");
  const dd = String(now.getDate()).padStart(2, "0");
  return `${mm}-${dd}`;
}

function isDateInRange(today: string, start: string, end: string): boolean {
  // Handle wrap-around (e.g. 12-30 to 01-03)
  if (start <= end) {
    return today >= start && today <= end;
  }
  // Wraps across year boundary
  return today >= start || today <= end;
}

function getOrCreateProgress(accountId: string, season: Season): PlayerSeasonalProgress {
  const key = `${accountId}:${season}`;
  let progress = playerProgress.get(key);
  if (!progress) {
    progress = {
      accountId,
      season,
      itemsCollected: [],
      achievementsUnlocked: [],
      eventParticipations: 0
    };
    playerProgress.set(key, progress);
  }
  return progress;
}

// --- Public Functions ---

export function getCurrentSeason(): Season {
  const month = new Date().getMonth() + 1; // 1-12
  if (month >= 3 && month <= 5) return "spring";
  if (month >= 6 && month <= 8) return "summer";
  if (month >= 9 && month <= 11) return "autumn";
  return "winter";
}

export function getActiveHolidays(): Holiday[] {
  const today = todayMMDD();
  return HOLIDAYS.filter((h) => isDateInRange(today, h.startDate, h.endDate));
}

export function getSeasonalItems(season?: Season): SeasonalItem[] {
  const currentSeason = season ?? getCurrentSeason();
  return SEASONAL_ITEMS.filter((item) => item.season === currentSeason && item.available);
}

export function collectSeasonalItem(token: string, itemId: string): { ok: boolean; reason?: string } {
  const session = getSession(token);
  if (!session) return { ok: false, reason: "invalid session" };

  const item = SEASONAL_ITEMS.find((i) => i.id === itemId);
  if (!item) return { ok: false, reason: "item not found" };
  if (!item.available) return { ok: false, reason: "item not available" };

  const season = getCurrentSeason();
  if (item.season !== season) return { ok: false, reason: "item is not in the current season" };

  const progress = getOrCreateProgress(session.accountId, season);
  if (progress.itemsCollected.includes(itemId)) {
    return { ok: false, reason: "item already collected" };
  }

  progress.itemsCollected.push(itemId);
  progress.eventParticipations += 1;
  return { ok: true };
}

export function getSeasonalProgress(token: string): PlayerSeasonalProgress | undefined {
  const session = getSession(token);
  if (!session) return undefined;
  const season = getCurrentSeason();
  return getOrCreateProgress(session.accountId, season);
}

export function placeSeasonalDecoration(token: string, regionId: string, decorationType: string): SeasonalDecoration | undefined {
  const session = getSession(token);
  if (!session) return undefined;

  const season = getCurrentSeason();
  const decoration: SeasonalDecoration = {
    id: randomUUID(),
    regionId,
    objectId: randomUUID(),
    decorationType,
    season,
    holiday: getActiveHolidays().find((h) => h.decorationType === decorationType)?.id,
    placedAt: new Date().toISOString()
  };

  const regionDecos = seasonalDecorations.get(regionId) ?? [];
  regionDecos.push(decoration);
  seasonalDecorations.set(regionId, regionDecos);

  // Track decoration placement for achievements
  const progress = getOrCreateProgress(session.accountId, season);
  progress.eventParticipations += 1;

  return decoration;
}

export function removeSeasonalDecorations(regionId: string, season: Season): number {
  const regionDecos = seasonalDecorations.get(regionId);
  if (!regionDecos) return 0;

  const before = regionDecos.length;
  const remaining = regionDecos.filter((d) => d.season !== season);
  seasonalDecorations.set(regionId, remaining);
  return before - remaining.length;
}

export function getSeasonalDecorations(regionId: string): SeasonalDecoration[] {
  return seasonalDecorations.get(regionId) ?? [];
}

export function getSeasonalAchievements(season?: Season): SeasonalAchievement[] {
  if (season) {
    return SEASONAL_ACHIEVEMENTS.filter((a) => a.season === season);
  }
  return [...SEASONAL_ACHIEVEMENTS];
}

export function checkSeasonalAchievements(accountId: string): SeasonalAchievement[] {
  const season = getCurrentSeason();
  const progress = getOrCreateProgress(accountId, season);
  const newlyUnlocked: SeasonalAchievement[] = [];

  for (const achievement of SEASONAL_ACHIEVEMENTS) {
    if (progress.achievementsUnlocked.includes(achievement.id)) continue;

    let earned = false;

    if (achievement.requirement.type === "collect") {
      const seasonItems = progress.itemsCollected.filter((itemId) => {
        const item = SEASONAL_ITEMS.find((i) => i.id === itemId);
        return item && item.season === achievement.season;
      });
      earned = seasonItems.length >= achievement.requirement.count;
    }

    if (achievement.requirement.type === "decorate") {
      // Count decorations placed by checking event participations as a proxy
      // In a real system this would track per-account decoration counts
      earned = progress.eventParticipations >= achievement.requirement.count;
    }

    if (achievement.requirement.type === "participate") {
      earned = progress.eventParticipations >= achievement.requirement.count;
    }

    if (achievement.requirement.type === "collect_legendary") {
      const legendaryCount = progress.itemsCollected.filter((itemId) => {
        const item = SEASONAL_ITEMS.find((i) => i.id === itemId);
        return item && item.rarity === "legendary";
      }).length;
      earned = legendaryCount >= achievement.requirement.count;
    }

    if (earned) {
      progress.achievementsUnlocked.push(achievement.id);
      newlyUnlocked.push(achievement);
    }
  }

  return newlyUnlocked;
}

export function getSeasonalLeaderboard(season: Season): Array<{ accountId: string; itemsCollected: number; achievementsUnlocked: number }> {
  const entries: Array<{ accountId: string; itemsCollected: number; achievementsUnlocked: number }> = [];

  for (const [key, progress] of playerProgress.entries()) {
    if (!key.endsWith(`:${season}`)) continue;
    entries.push({
      accountId: progress.accountId,
      itemsCollected: progress.itemsCollected.length,
      achievementsUnlocked: progress.achievementsUnlocked.length
    });
  }

  entries.sort((a, b) => b.itemsCollected - a.itemsCollected || b.achievementsUnlocked - a.achievementsUnlocked);
  return entries.slice(0, 50);
}

export function getRegionSeasonalTheme(regionId: string): SeasonalTheme {
  const season = getCurrentSeason();
  return SEASONAL_THEMES[season];
}
