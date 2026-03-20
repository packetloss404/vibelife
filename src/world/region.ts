// ── Region broadcasting stubs ────────────────────────────────────────────────
// These are no-ops now that Paper handles real-time broadcasting.
// Kept as stubs so deferred services (interactives, NPCs) still compile.

const regionSequences = new Map<string, number>();

export function joinRegion(_regionId: string, _avatarId: string, _socket: unknown): void {}
export function leaveRegion(_regionId: string, _avatarId: string): void {}

export function nextRegionSequence(regionId: string): number {
  const seq = (regionSequences.get(regionId) ?? 0) + 1;
  regionSequences.set(regionId, seq);
  return seq;
}

export function getRegionSequence(regionId: string): number {
  return regionSequences.get(regionId) ?? 0;
}

export function broadcastRegion(_regionId: string, _event: unknown, _excludeSocket?: unknown): void {}
export function broadcastRegionLocal(_regionId: string, _event: unknown, _x: number, _z: number, _radius: number): void {}
export function sendToAvatar(_regionId: string, _avatarId: string, _event: unknown): void {}
export function sendToAvatars(_avatarIds: Set<string>, _event: unknown): void {}
