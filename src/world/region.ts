import type { AvatarState, Parcel, RegionObject } from "./store.js";
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

export function broadcastRegion(regionId: string, event: RegionEvent) {
  const payload = JSON.stringify(event);

  for (const [avatarId, peer] of getPeers(regionId).entries()) {
    if (!peer.socket || typeof peer.socket.send !== "function") {
      getPeers(regionId).delete(avatarId);
      continue;
    }

    if (peer.socket.readyState === peer.socket.OPEN) {
      peer.socket.send(payload);
    }
  }
}
