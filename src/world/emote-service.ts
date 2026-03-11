import type { EmoteContract } from "../contracts.js";
import { getSession, getRegionPopulation, type AvatarState } from "./_shared-state.js";

export const EMOTE_LIST: EmoteContract[] = [
  // Greetings
  { name: "wave", category: "greetings", duration_ms: 2000 },
  { name: "bow", category: "greetings", duration_ms: 2500 },
  { name: "salute", category: "greetings", duration_ms: 1500 },
  // Expressions
  { name: "dance", category: "expressions", duration_ms: 4000 },
  { name: "cheer", category: "expressions", duration_ms: 3000 },
  { name: "laugh", category: "expressions", duration_ms: 2500 },
  { name: "cry", category: "expressions", duration_ms: 3000 },
  // Actions
  { name: "sit", category: "actions", duration_ms: 0 },
  { name: "meditate", category: "actions", duration_ms: 0 },
  { name: "yoga", category: "actions", duration_ms: 5000 },
  { name: "stretch", category: "actions", duration_ms: 3000 },
  { name: "high-five", category: "actions", duration_ms: 2000 },
  // Fun
  { name: "dab", category: "fun", duration_ms: 1500 },
  { name: "backflip", category: "fun", duration_ms: 2000 },
  { name: "air-guitar", category: "fun", duration_ms: 4000 }
];

export function getEmoteList(): EmoteContract[] {
  return EMOTE_LIST;
}

export function handleEmote(token: string, emoteName: string): { avatarId: string; displayName: string; emote: EmoteContract } | undefined {
  const session = getSession(token);
  if (!session) return undefined;

  const emote = EMOTE_LIST.find((e) => e.name === emoteName);
  if (!emote) return undefined;

  return {
    avatarId: session.avatarId,
    displayName: session.displayName,
    emote
  };
}

// ── Emote Combo Detection ──────────────────────────────────────────────────

type RecentEmote = {
  avatarId: string;
  emote: string;
  regionId: string;
  timestamp: number;
};

const recentEmotes: RecentEmote[] = [];
const COMBO_WINDOW_MS = 3000;
const COMBO_DISTANCE = 3.0;

const COMBO_MAP: Record<string, string> = {
  "high-five": "combo:high-five",
  "dance": "combo:dance-sync",
  "bow": "combo:mutual-bow",
  "wave": "combo:wave-sync",
};

function avatarDistance(a: AvatarState, b: AvatarState): number {
  const dx = a.x - b.x;
  const dy = a.y - b.y;
  const dz = a.z - b.z;
  return Math.sqrt(dx * dx + dy * dy + dz * dz);
}

function pruneOldEmotes(): void {
  const cutoff = Date.now() - COMBO_WINDOW_MS;
  while (recentEmotes.length > 0 && recentEmotes[0].timestamp < cutoff) {
    recentEmotes.shift();
  }
}

export type EmoteComboResult = {
  comboName: string;
  avatarIds: [string, string];
  position: { x: number; y: number; z: number };
} | null;

export function recordEmote(avatarId: string, emote: string, regionId: string): EmoteComboResult {
  pruneOldEmotes();

  const comboName = COMBO_MAP[emote];
  if (comboName) {
    const now = Date.now();
    const avatars = getRegionPopulation(regionId);
    const performer = avatars.find((a) => a.avatarId === avatarId);

    if (performer) {
      for (const recent of recentEmotes) {
        if (
          recent.regionId === regionId &&
          recent.avatarId !== avatarId &&
          recent.emote === emote &&
          now - recent.timestamp <= COMBO_WINDOW_MS
        ) {
          const partner = avatars.find((a) => a.avatarId === recent.avatarId);
          if (partner && avatarDistance(performer, partner) <= COMBO_DISTANCE) {
            const matchIndex = recentEmotes.indexOf(recent);
            if (matchIndex !== -1) recentEmotes.splice(matchIndex, 1);

            return {
              comboName,
              avatarIds: [avatarId, recent.avatarId],
              position: {
                x: (performer.x + partner.x) / 2,
                y: (performer.y + partner.y) / 2,
                z: (performer.z + partner.z) / 2
              }
            };
          }
        }
      }
    }
  }

  recentEmotes.push({ avatarId, emote, regionId, timestamp: Date.now() });
  return null;
}
