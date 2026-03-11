/**
 * Voice indicator service — tracks who is speaking per region and broadcasts state.
 * Integrates with the voice:speaking WebSocket event.
 *
 * NOTE: server.ts needs to import and use this service for voice:speaking WS events.
 */

export type SpeakingState = {
  accountId: string;
  avatarId: string;
  regionId: string;
  speaking: boolean;
  updatedAt: string;
};

// regionId -> Map<accountId, SpeakingState>
const speakingByRegion = new Map<string, Map<string, SpeakingState>>();

// Auto-expire speaking state after this many ms of no update
const SPEAKING_TIMEOUT_MS = 5000;

function getRegionSpeakers(regionId: string): Map<string, SpeakingState> {
  let speakers = speakingByRegion.get(regionId);

  if (!speakers) {
    speakers = new Map();
    speakingByRegion.set(regionId, speakers);
  }

  return speakers;
}

export function setSpeaking(
  accountId: string,
  avatarId: string,
  regionId: string,
  speaking: boolean
): SpeakingState {
  const speakers = getRegionSpeakers(regionId);
  const state: SpeakingState = {
    accountId,
    avatarId,
    regionId,
    speaking,
    updatedAt: new Date().toISOString(),
  };

  if (speaking) {
    speakers.set(accountId, state);
  } else {
    speakers.delete(accountId);
  }

  return state;
}

export function getSpeakingAvatars(regionId: string): SpeakingState[] {
  const speakers = getRegionSpeakers(regionId);
  const now = Date.now();
  const expired: string[] = [];

  for (const [accountId, state] of speakers.entries()) {
    const age = now - new Date(state.updatedAt).getTime();

    if (age > SPEAKING_TIMEOUT_MS) {
      expired.push(accountId);
    }
  }

  // Clean up expired entries
  for (const accountId of expired) {
    speakers.delete(accountId);
  }

  return [...speakers.values()];
}

export function removeAccountFromVoice(
  accountId: string,
  regionId: string
): void {
  const speakers = speakingByRegion.get(regionId);

  if (speakers) {
    speakers.delete(accountId);
  }
}

export function clearRegionVoice(regionId: string): void {
  speakingByRegion.delete(regionId);
}
