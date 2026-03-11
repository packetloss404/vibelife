// NOTE for server.ts: register the interactives route plugin:
//   import interactivesRoutes from "./routes/interactives.js";
//   await app.register(interactivesRoutes);
//
// NOTE for store.ts: re-export this module at the bottom:
//   export * from "./interactive-service.js";

import { randomUUID } from "node:crypto";
import { getSession } from "./store.js";
import { broadcastRegion, nextRegionSequence } from "./region.js";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export type InteractionType =
  | "door"
  | "elevator"
  | "platform"
  | "button"
  | "switch"
  | "teleporter"
  | "chest";

export type DoorConfig = {
  openRotationY: number;
  closedRotationY: number;
  speed: number;
};

export type ElevatorConfig = {
  minY: number;
  maxY: number;
  speed: number;
  pauseTime: number;
};

export type PlatformConfig = {
  waypoints: { x: number; y: number; z: number }[];
  speed: number;
  loop: boolean;
};

export type ButtonConfig = {
  linkedObjectIds: string[];
  action: "toggle" | "activate" | "deactivate";
};

export type InteractiveObject = {
  id: string;
  objectId: string;
  regionId: string;
  interactionType: InteractionType;
  config: Record<string, unknown>;
  state: Record<string, unknown>;
  createdAt: string;
};

// ---------------------------------------------------------------------------
// In-memory store
// ---------------------------------------------------------------------------

const interactives = new Map<string, InteractiveObject>();

// ---------------------------------------------------------------------------
// CRUD helpers
// ---------------------------------------------------------------------------

export function registerInteractive(
  objectId: string,
  regionId: string,
  interactionType: InteractionType,
  config: Record<string, unknown>
): InteractiveObject {
  const existing = getInteractiveByObjectId(objectId);
  if (existing) {
    existing.interactionType = interactionType;
    existing.config = config;
    existing.state = buildDefaultState(interactionType, config);
    return existing;
  }

  const entry: InteractiveObject = {
    id: randomUUID(),
    objectId,
    regionId,
    interactionType,
    config,
    state: buildDefaultState(interactionType, config),
    createdAt: new Date().toISOString(),
  };

  interactives.set(entry.id, entry);
  return entry;
}

export function removeInteractive(objectId: string): boolean {
  const entry = getInteractiveByObjectId(objectId);
  if (!entry) return false;
  interactives.delete(entry.id);
  return true;
}

export function getInteractive(id: string): InteractiveObject | undefined {
  return interactives.get(id);
}

export function getInteractiveByObjectId(objectId: string): InteractiveObject | undefined {
  for (const entry of interactives.values()) {
    if (entry.objectId === objectId) return entry;
  }
  return undefined;
}

export function listInteractives(): InteractiveObject[] {
  return [...interactives.values()];
}

export function getInteractivesByRegion(regionId: string): InteractiveObject[] {
  return [...interactives.values()].filter((e) => e.regionId === regionId);
}

// ---------------------------------------------------------------------------
// Default state builders
// ---------------------------------------------------------------------------

function buildDefaultState(
  interactionType: InteractionType,
  config: Record<string, unknown>
): Record<string, unknown> {
  switch (interactionType) {
    case "door":
      return {
        open: false,
        currentRotationY: (config as unknown as DoorConfig).closedRotationY ?? 0,
      };
    case "elevator":
      return {
        moving: false,
        direction: "up" as const,
        currentY: (config as unknown as ElevatorConfig).minY ?? 0,
        pauseRemaining: 0,
      };
    case "platform":
      return {
        moving: false,
        waypointIndex: 0,
        forward: true,
        currentX: ((config as unknown as PlatformConfig).waypoints?.[0]?.x) ?? 0,
        currentY: ((config as unknown as PlatformConfig).waypoints?.[0]?.y) ?? 0,
        currentZ: ((config as unknown as PlatformConfig).waypoints?.[0]?.z) ?? 0,
      };
    case "button":
    case "switch":
      return { active: false };
    case "teleporter":
      return { active: true };
    case "chest":
      return { open: false };
    default:
      return {};
  }
}

// ---------------------------------------------------------------------------
// Interaction logic
// ---------------------------------------------------------------------------

export function interactWith(
  token: string,
  objectId: string
): InteractiveObject | undefined {
  const session = getSession(token);
  if (!session) return undefined;

  const entry = getInteractiveByObjectId(objectId);
  if (!entry) return undefined;

  switch (entry.interactionType) {
    case "door": {
      const wasOpen = entry.state.open as boolean;
      entry.state.open = !wasOpen;
      // Target rotation will be interpolated by updateInteractiveState
      break;
    }
    case "elevator": {
      entry.state.moving = !(entry.state.moving as boolean);
      break;
    }
    case "platform": {
      entry.state.moving = !(entry.state.moving as boolean);
      break;
    }
    case "button":
    case "switch": {
      const wasActive = entry.state.active as boolean;
      entry.state.active = !wasActive;
      const cfg = entry.config as unknown as ButtonConfig;
      if (cfg.linkedObjectIds) {
        for (const linkedId of cfg.linkedObjectIds) {
          applyButtonAction(linkedId, cfg.action, !wasActive);
        }
      }
      break;
    }
    case "teleporter": {
      // Teleporter interaction is handled client-side via config.targetRegionId etc.
      break;
    }
    case "chest": {
      entry.state.open = !(entry.state.open as boolean);
      break;
    }
  }

  // Broadcast the state change to the region
  broadcastRegion(entry.regionId, {
    type: "interactive:state_changed",
    sequence: nextRegionSequence(entry.regionId),
    objectId: entry.objectId,
    interactionType: entry.interactionType,
    newState: { ...entry.state },
  } as any); // eslint-disable-line @typescript-eslint/no-explicit-any

  return entry;
}

function applyButtonAction(
  linkedObjectId: string,
  action: "toggle" | "activate" | "deactivate",
  buttonActive: boolean
) {
  const linked = getInteractiveByObjectId(linkedObjectId);
  if (!linked) return;

  switch (action) {
    case "toggle":
      if (linked.interactionType === "door") {
        linked.state.open = !(linked.state.open as boolean);
      } else if (
        linked.interactionType === "elevator" ||
        linked.interactionType === "platform"
      ) {
        linked.state.moving = !(linked.state.moving as boolean);
      }
      break;
    case "activate":
      if (linked.interactionType === "door") {
        linked.state.open = true;
      } else if (
        linked.interactionType === "elevator" ||
        linked.interactionType === "platform"
      ) {
        linked.state.moving = true;
      }
      break;
    case "deactivate":
      if (linked.interactionType === "door") {
        linked.state.open = false;
      } else if (
        linked.interactionType === "elevator" ||
        linked.interactionType === "platform"
      ) {
        linked.state.moving = false;
      }
      break;
  }

  broadcastRegion(linked.regionId, {
    type: "interactive:state_changed",
    sequence: nextRegionSequence(linked.regionId),
    objectId: linked.objectId,
    interactionType: linked.interactionType,
    newState: { ...linked.state },
  } as any); // eslint-disable-line @typescript-eslint/no-explicit-any
}

// ---------------------------------------------------------------------------
// Tick update — called on a server interval for moving objects
// ---------------------------------------------------------------------------

export function updateInteractiveState(deltaSeconds: number): void {
  for (const entry of interactives.values()) {
    let changed = false;

    switch (entry.interactionType) {
      case "door": {
        const cfg = entry.config as unknown as DoorConfig;
        const targetY = (entry.state.open as boolean)
          ? cfg.openRotationY
          : cfg.closedRotationY;
        const current = entry.state.currentRotationY as number;
        if (Math.abs(current - targetY) > 0.01) {
          const step = cfg.speed * deltaSeconds;
          if (current < targetY) {
            entry.state.currentRotationY = Math.min(current + step, targetY);
          } else {
            entry.state.currentRotationY = Math.max(current - step, targetY);
          }
          changed = true;
        }
        break;
      }

      case "elevator": {
        if (!(entry.state.moving as boolean)) break;
        const cfg = entry.config as unknown as ElevatorConfig;
        let pauseRemaining = entry.state.pauseRemaining as number;

        if (pauseRemaining > 0) {
          pauseRemaining -= deltaSeconds;
          entry.state.pauseRemaining = Math.max(0, pauseRemaining);
          break;
        }

        const dir = entry.state.direction as "up" | "down";
        let currentY = entry.state.currentY as number;
        const step = cfg.speed * deltaSeconds;

        if (dir === "up") {
          currentY = Math.min(currentY + step, cfg.maxY);
          if (currentY >= cfg.maxY) {
            entry.state.direction = "down";
            entry.state.pauseRemaining = cfg.pauseTime;
          }
        } else {
          currentY = Math.max(currentY - step, cfg.minY);
          if (currentY <= cfg.minY) {
            entry.state.direction = "up";
            entry.state.pauseRemaining = cfg.pauseTime;
          }
        }

        entry.state.currentY = currentY;
        changed = true;
        break;
      }

      case "platform": {
        if (!(entry.state.moving as boolean)) break;
        const cfg = entry.config as unknown as PlatformConfig;
        const waypoints = cfg.waypoints;
        if (!waypoints || waypoints.length < 2) break;

        let idx = entry.state.waypointIndex as number;
        let forward = entry.state.forward as boolean;
        const target = waypoints[idx];
        let cx = entry.state.currentX as number;
        let cy = entry.state.currentY as number;
        let cz = entry.state.currentZ as number;

        const dx = target.x - cx;
        const dy = target.y - cy;
        const dz = target.z - cz;
        const dist = Math.sqrt(dx * dx + dy * dy + dz * dz);

        if (dist < 0.05) {
          // Reached waypoint — advance
          cx = target.x;
          cy = target.y;
          cz = target.z;

          if (forward) {
            if (idx < waypoints.length - 1) {
              idx++;
            } else if (cfg.loop) {
              idx = 0;
            } else {
              forward = false;
              idx = Math.max(0, idx - 1);
            }
          } else {
            if (idx > 0) {
              idx--;
            } else if (cfg.loop) {
              idx = waypoints.length - 1;
            } else {
              forward = true;
              idx = Math.min(waypoints.length - 1, idx + 1);
            }
          }

          entry.state.waypointIndex = idx;
          entry.state.forward = forward;
        } else {
          const step = cfg.speed * deltaSeconds;
          const ratio = Math.min(step / dist, 1);
          cx += dx * ratio;
          cy += dy * ratio;
          cz += dz * ratio;
        }

        entry.state.currentX = cx;
        entry.state.currentY = cy;
        entry.state.currentZ = cz;
        changed = true;
        break;
      }

      default:
        break;
    }

    if (changed) {
      broadcastRegion(entry.regionId, {
        type: "interactive:state_changed",
        sequence: nextRegionSequence(entry.regionId),
        objectId: entry.objectId,
        interactionType: entry.interactionType,
        newState: { ...entry.state },
      } as any); // eslint-disable-line @typescript-eslint/no-explicit-any
    }
  }
}
