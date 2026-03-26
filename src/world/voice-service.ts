// ---------------------------------------------------------------------------
// Voice Chat Signaling Service
// ---------------------------------------------------------------------------
//
// ## REST endpoint / plugin message channel types needed in server.ts:
//   - "voice:offer"         — relay SDP offer from sender to recipient
//   - "voice:answer"        — relay SDP answer back
//   - "voice:ice-candidate" — relay ICE candidate
//   - "voice:speaking"      — broadcast speaking state to nearby avatars
//
// ## contracts.ts additions needed:
//   Types:
//     VoiceParticipantContract, VoiceChannelContract
//   RegionEvent additions:
//     | { type: "voice:participant_joined"; sequence: number; participant: VoiceParticipantContract }
//     | { type: "voice:participant_left";   sequence: number; accountId: string; regionId: string }
//     | { type: "voice:speaking_changed";   sequence: number; accountId: string; speaking: boolean }
//   RegionCommand additions:
//     | { type: "voice:offer";         sdp: string; toAccountId: string }
//     | { type: "voice:answer";        sdp: string; toAccountId: string }
//     | { type: "voice:ice_candidate"; candidate: unknown; toAccountId: string }
//     | { type: "voice:speaking";      speaking: boolean }
// ---------------------------------------------------------------------------

import { getSession } from "./store.js";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export type VoiceParticipant = {
  accountId: string;
  avatarId: string;
  displayName: string;
  regionId: string;
  muted: boolean;
  deafened: boolean;
  speaking: boolean;
  position: { x: number; y: number; z: number };
  joinedAt: string;
};

export type VoiceChannel = {
  id: string;
  regionId: string;
  parcelId: string | null;
  participants: Map<string, VoiceParticipant>;
  maxParticipants: number;
};

export type ICEServer = {
  urls: string | string[];
  username?: string;
  credential?: string;
};

// ---------------------------------------------------------------------------
// In-memory state — keyed by regionId (one voice channel per region)
// ---------------------------------------------------------------------------

const voiceChannels = new Map<string, VoiceChannel>();

const DEFAULT_MAX_PARTICIPANTS = 32;
const SPATIAL_MAX_RANGE = 30; // units

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function getOrCreateChannel(regionId: string, parcelId: string | null = null): VoiceChannel {
  let channel = voiceChannels.get(regionId);

  if (!channel) {
    channel = {
      id: `voice-${regionId}`,
      regionId,
      parcelId,
      participants: new Map(),
      maxParticipants: DEFAULT_MAX_PARTICIPANTS,
    };
    voiceChannels.set(regionId, channel);
  }

  return channel;
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/**
 * Join the voice channel for a region. Returns channel info + ICE servers.
 */
export function joinVoiceChannel(
  token: string,
  regionId: string,
  parcelId: string | null = null,
): { channel: VoiceChannel; iceServers: ICEServer[]; participant: VoiceParticipant } | undefined {
  const session = getSession(token);

  if (!session) {
    return undefined;
  }

  const channel = getOrCreateChannel(regionId, parcelId);

  if (channel.participants.size >= channel.maxParticipants) {
    return undefined;
  }

  // Prevent duplicate joins
  if (channel.participants.has(session.accountId)) {
    const existing = channel.participants.get(session.accountId)!;
    return { channel, iceServers: getICEServers(), participant: existing };
  }

  const participant: VoiceParticipant = {
    accountId: session.accountId,
    avatarId: session.avatarId,
    displayName: session.displayName,
    regionId,
    muted: false,
    deafened: false,
    speaking: false,
    position: { x: 0, y: 0, z: 0 },
    joinedAt: new Date().toISOString(),
  };

  channel.participants.set(session.accountId, participant);

  return { channel, iceServers: getICEServers(), participant };
}

/**
 * Leave the voice channel for a region.
 */
export function leaveVoiceChannel(
  token: string,
  regionId: string,
): { accountId: string; regionId: string } | undefined {
  const session = getSession(token);

  if (!session) {
    return undefined;
  }

  const channel = voiceChannels.get(regionId);

  if (!channel) {
    return undefined;
  }

  if (!channel.participants.has(session.accountId)) {
    return undefined;
  }

  channel.participants.delete(session.accountId);

  // Clean up empty channels
  if (channel.participants.size === 0) {
    voiceChannels.delete(regionId);
  }

  return { accountId: session.accountId, regionId };
}

/**
 * Toggle mute state for a participant.
 */
export function setVoiceMuted(
  token: string,
  regionId: string,
  muted: boolean,
): VoiceParticipant | undefined {
  const session = getSession(token);

  if (!session) {
    return undefined;
  }

  const channel = voiceChannels.get(regionId);
  const participant = channel?.participants.get(session.accountId);

  if (!participant) {
    return undefined;
  }

  participant.muted = muted;
  return participant;
}

/**
 * Toggle deafen state for a participant.
 */
export function setVoiceDeafened(
  token: string,
  regionId: string,
  deafened: boolean,
): VoiceParticipant | undefined {
  const session = getSession(token);

  if (!session) {
    return undefined;
  }

  const channel = voiceChannels.get(regionId);
  const participant = channel?.participants.get(session.accountId);

  if (!participant) {
    return undefined;
  }

  participant.deafened = deafened;

  // Deafening also mutes
  if (deafened) {
    participant.muted = true;
  }

  return participant;
}

/**
 * Update a participant's avatar position for spatial audio calculations.
 * Does not require token — called internally when avatar moves.
 */
export function updateVoicePosition(
  accountId: string,
  regionId: string,
  position: { x: number; y: number; z: number },
): VoiceParticipant | undefined {
  const channel = voiceChannels.get(regionId);
  const participant = channel?.participants.get(accountId);

  if (!participant) {
    return undefined;
  }

  participant.position = position;
  return participant;
}

/**
 * Get all voice participants in a region.
 */
export function getVoiceParticipants(regionId: string): VoiceParticipant[] {
  const channel = voiceChannels.get(regionId);

  if (!channel) {
    return [];
  }

  return [...channel.participants.values()];
}

/**
 * Calculate spatial audio volume (0.0 - 1.0) based on distance between
 * listener and speaker. Uses inverse-square-ish falloff with a max range
 * of 30 units.
 */
export function calculateSpatialVolume(
  listenerPos: { x: number; y: number; z: number },
  speakerPos: { x: number; y: number; z: number },
): number {
  const dx = listenerPos.x - speakerPos.x;
  const dy = listenerPos.y - speakerPos.y;
  const dz = listenerPos.z - speakerPos.z;
  const distance = Math.sqrt(dx * dx + dy * dy + dz * dz);

  if (distance <= 0) {
    return 1.0;
  }

  if (distance >= SPATIAL_MAX_RANGE) {
    return 0.0;
  }

  // Smooth falloff curve: 1 - (d / max)^2
  const ratio = distance / SPATIAL_MAX_RANGE;
  return Math.max(0.0, 1.0 - ratio * ratio);
}

/**
 * Return ICE (STUN/TURN) server configuration from environment variables.
 */
export function getICEServers(): ICEServer[] {
  const servers: ICEServer[] = [];

  const stunServer = process.env.STUN_SERVER ?? "stun:stun.l.google.com:19302";

  if (stunServer) {
    servers.push({ urls: stunServer });
  }

  const turnServer = process.env.TURN_SERVER;
  const turnUsername = process.env.TURN_USERNAME;
  const turnPassword = process.env.TURN_PASSWORD;

  if (turnServer && turnUsername && turnPassword) {
    servers.push({
      urls: turnServer,
      username: turnUsername,
      credential: turnPassword,
    });
  }

  return servers;
}

/**
 * Clean up all voice state for a given account (e.g. on disconnect).
 * Removes the account from every channel they are in.
 */
export function cleanupVoiceForAccount(accountId: string): { regionId: string }[] {
  const removedFrom: { regionId: string }[] = [];

  for (const [regionId, channel] of voiceChannels.entries()) {
    if (channel.participants.has(accountId)) {
      channel.participants.delete(accountId);
      removedFrom.push({ regionId });

      if (channel.participants.size === 0) {
        voiceChannels.delete(regionId);
      }
    }
  }

  return removedFrom;
}
