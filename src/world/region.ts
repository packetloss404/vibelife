import type { AvatarState, Parcel, RegionObject } from "./store.js";

type RegionSocket = {
  OPEN: number;
  readyState: number;
  send(payload: string): void;
};

type RegionEvent =
  | { type: "snapshot"; avatars: AvatarState[]; objects: RegionObject[]; parcels: Parcel[] }
  | { type: "avatar:joined"; avatar: AvatarState }
  | { type: "avatar:moved"; avatar: AvatarState }
  | { type: "avatar:updated"; avatar: AvatarState }
  | { type: "avatar:left"; avatarId: string }
  | { type: "chat"; avatarId: string; displayName: string; message: string; createdAt: string }
  | { type: "object:created"; object: RegionObject }
  | { type: "object:updated"; object: RegionObject }
  | { type: "object:deleted"; objectId: string }
  | { type: "parcel:updated"; parcel: Parcel };

type RegionPeer = {
  avatarId: string;
  socket: RegionSocket;
};

const peersByRegion = new Map<string, Map<string, RegionPeer>>();

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
