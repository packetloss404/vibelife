import { getRegionPopulation, type AvatarState, type Parcel, type RegionObject } from "./store.js";
import type { RegionEvent } from "../contracts.js";

type RegionSocket = {
  OPEN: number;
  readyState: number;
  send(payload: string): void;
};

type RegionPeer = {
  avatarId: string;
  socket: RegionSocket;
};

const peersByRegion = new Map<string, Map<string, RegionPeer>>();
const regionSequences = new Map<string, number>();

function getPeers(regionId: string) {
  let peers = peersByRegion.get(regionId);

  if (!peers) {
    peers = new Map();
    peersByRegion.set(regionId, peers);
  }

  return peers;
}

export function joinRegion(regionId: string, avatarId: string, socket: RegionSocket) {
  getPeers(regionId).set(avatarId, { avatarId, socket });
}

export function leaveRegion(regionId: string, avatarId: string) {
  getPeers(regionId).delete(avatarId);
}

export function nextRegionSequence(regionId: string) {
  const next = (regionSequences.get(regionId) ?? 0) + 1;
  regionSequences.set(regionId, next);
  return next;
}

export function getRegionSequence(regionId: string) {
  return regionSequences.get(regionId) ?? 0;
}

export function broadcastRegion(regionId: string, event: RegionEvent | Record<string, unknown>, excludeSocket?: RegionSocket) {
  const payload = JSON.stringify(event);

  for (const [avatarId, peer] of getPeers(regionId).entries()) {
    if (!peer.socket || typeof peer.socket.send !== "function") {
      getPeers(regionId).delete(avatarId);
      continue;
    }

    if (excludeSocket && peer.socket === excludeSocket) {
      continue;
    }

    if (peer.socket.readyState === peer.socket.OPEN) {
      peer.socket.send(payload);
    }
  }
}

export function sendToAvatar(regionId: string, avatarId: string, event: RegionEvent) {
  const peer = getPeers(regionId).get(avatarId);
  if (!peer || !peer.socket || typeof peer.socket.send !== "function") return;
  if (peer.socket.readyState === peer.socket.OPEN) {
    peer.socket.send(JSON.stringify(event));
  }
}

/**
 * Send an event to a specific set of avatar IDs across all regions.
 * Used for group chat where members may be in different regions.
 */
export function sendToAvatars(avatarIds: Set<string>, event: RegionEvent | Record<string, unknown>) {
  const payload = JSON.stringify(event);

  for (const [, peers] of peersByRegion) {
    for (const [avatarId, peer] of peers) {
      if (!avatarIds.has(avatarId)) continue;
      if (!peer.socket || typeof peer.socket.send !== "function") {
        peers.delete(avatarId);
        continue;
      }
      if (peer.socket.readyState === peer.socket.OPEN) {
        peer.socket.send(payload);
      }
    }
  }
}

export function broadcastRegionLocal(regionId: string, event: RegionEvent | Record<string, unknown>, senderX: number, senderZ: number, radius: number) {
  const payload = JSON.stringify(event);
  const population = getRegionPopulation(regionId);
  const nearbyAvatarIds = new Set<string>();

  for (const avatar of population) {
    const dx = avatar.x - senderX;
    const dz = avatar.z - senderZ;
    if (Math.sqrt(dx * dx + dz * dz) <= radius) {
      nearbyAvatarIds.add(avatar.avatarId);
    }
  }

  for (const [avatarId, peer] of getPeers(regionId).entries()) {
    if (!nearbyAvatarIds.has(avatarId)) continue;

    if (!peer.socket || typeof peer.socket.send !== "function") {
      getPeers(regionId).delete(avatarId);
      continue;
    }

    if (peer.socket.readyState === peer.socket.OPEN) {
      peer.socket.send(payload);
    }
  }
}
