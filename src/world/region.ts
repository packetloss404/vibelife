import type { AvatarState } from "./store.js";

type RegionSocket = {
  OPEN: number;
  readyState: number;
  send(payload: string): void;
};

type RegionEvent =
  | { type: "snapshot"; avatars: AvatarState[] }
  | { type: "avatar:joined"; avatar: AvatarState }
  | { type: "avatar:moved"; avatar: AvatarState }
  | { type: "avatar:left"; avatarId: string }
  | { type: "chat"; avatarId: string; displayName: string; message: string; createdAt: string };

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

  for (const peer of getPeers(regionId).values()) {
    if (peer.socket.readyState === peer.socket.OPEN) {
      peer.socket.send(payload);
    }
  }
}
