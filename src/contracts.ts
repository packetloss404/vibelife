export type AuthMode = "guest" | "register" | "login";

export type AccountRole = "resident" | "admin";

export type AccountKind = "guest" | "registered";

export type AvatarAppearanceContract = {
  accountId: string;
  bodyColor: string;
  accentColor: string;
  headColor: string;
  hairColor: string;
  outfit: string;
  accessory: string;
  updatedAt: string;
};

export type AvatarStateContract = {
  avatarId: string;
  accountId: string;
  displayName: string;
  appearance: AvatarAppearanceContract;
  x: number;
  y: number;
  z: number;
  updatedAt: string;
};

export type ParcelContract = {
  id: string;
  regionId: string;
  name: string;
  ownerAccountId: string | null;
  ownerDisplayName: string | null;
  collaboratorAccountIds: string[];
  collaboratorDisplayNames: string[];
  minX: number;
  maxX: number;
  minZ: number;
  maxZ: number;
  tier: string;
};

export type RegionObjectContract = {
  id: string;
  regionId: string;
  ownerAccountId: string;
  ownerDisplayName: string | null;
  asset: string;
  x: number;
  y: number;
  z: number;
  rotationY: number;
  scale: number;
  createdAt: string;
  updatedAt: string;
};

export type RegionSnapshotEvent = {
  type: "snapshot";
  sequence: number;
  avatars: AvatarStateContract[];
  objects: RegionObjectContract[];
  parcels: ParcelContract[];
};

export type RegionEvent =
  | RegionSnapshotEvent
  | { type: "avatar:joined"; sequence: number; avatar: AvatarStateContract }
  | { type: "avatar:moved"; sequence: number; avatar: AvatarStateContract }
  | { type: "avatar:updated"; sequence: number; avatar: AvatarStateContract }
  | { type: "avatar:left"; sequence: number; avatarId: string }
  | { type: "chat"; sequence: number; avatarId: string; displayName: string; message: string; createdAt: string }
  | { type: "object:created"; sequence: number; object: RegionObjectContract }
  | { type: "object:updated"; sequence: number; object: RegionObjectContract }
  | { type: "object:deleted"; sequence: number; objectId: string }
  | { type: "parcel:updated"; sequence: number; parcel: ParcelContract };

export type RegionCommand =
  | { type: "move"; x: number; y?: number; z: number }
  | { type: "chat"; message: string };

export const AUTH_MODES: AuthMode[] = ["guest", "register", "login"];

export function isRegionCommand(value: unknown): value is RegionCommand {
  if (!value || typeof value !== "object") {
    return false;
  }

  const candidate = value as Record<string, unknown>;

  if (candidate.type === "move") {
    return Number.isFinite(candidate.x) && Number.isFinite(candidate.z) && (candidate.y === undefined || Number.isFinite(candidate.y));
  }

  if (candidate.type === "chat") {
    return typeof candidate.message === "string";
  }

  return false;
}
