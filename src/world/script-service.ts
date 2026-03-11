// ----- Changes needed in other files (DO NOT apply automatically) -----
// src/contracts.ts — add: VisualScriptContract, ScriptNodeContract, TriggerZoneContract,
//   and add `| { type: "script:triggered"; sequence: number; scriptId: string; actions: ScriptActionResult[] }` to RegionEvent.
// src/server.ts — add: `import scriptsPlugin from "./routes/scripts.js";` and `await app.register(scriptsPlugin);`
// src/world/store.ts — re-export everything from this file at the bottom.
// -----------------------------------------------------------------------

import { randomUUID } from "node:crypto";
import { getSession, listParcels, type Session } from "./store.js";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export type ScriptNodeType =
  | "trigger_zone_enter"
  | "trigger_zone_exit"
  | "timer"
  | "click_interact"
  | "condition"
  | "action_chat"
  | "action_move_object"
  | "action_toggle"
  | "action_spawn_particles"
  | "delay";

export type ScriptNode = {
  id: string;
  type: ScriptNodeType;
  position: { x: number; y: number };
  config: Record<string, unknown>;
};

export type NodeConnection = {
  fromNodeId: string;
  fromPort: number;
  toNodeId: string;
  toPort: number;
};

export type VisualScript = {
  id: string;
  name: string;
  ownerAccountId: string;
  regionId: string;
  parcelId: string;
  nodes: ScriptNode[];
  connections: NodeConnection[];
  enabled: boolean;
  createdAt: string;
};

export type TriggerZoneShape = "sphere" | "box";

export type TriggerZone = {
  id: string;
  scriptId: string;
  regionId: string;
  position: { x: number; y: number; z: number };
  radius: number;
  shape: TriggerZoneShape;
  size: { x: number; y: number; z: number };
};

export type ScriptActionResult = {
  type: string;
  params: Record<string, unknown>;
};

export type TriggerEvent = {
  type: "zone_enter" | "zone_exit" | "timer" | "click_interact";
  avatarId?: string;
  objectId?: string;
  zoneId?: string;
  scriptId?: string;
};

// Simple per-script-instance state tracking
export type ScriptState = {
  scriptId: string;
  activeNodeIds: Set<string>;
  variables: Record<string, unknown>;
  lastTriggeredAt: string | null;
};

// ---------------------------------------------------------------------------
// In-memory stores
// ---------------------------------------------------------------------------

const scripts = new Map<string, VisualScript>();
const triggerZones = new Map<string, TriggerZone>();
const scriptStates = new Map<string, ScriptState>();

// Track which trigger zones each avatar is currently inside (for enter/exit detection)
const avatarZonePresence = new Map<string, Set<string>>();

// ---------------------------------------------------------------------------
// Permission helpers
// ---------------------------------------------------------------------------

async function hasParcelBuildPermission(session: Session, parcelId: string): Promise<boolean> {
  const parcels = await listParcels(session.regionId);
  const parcel = parcels.find((p) => p.id === parcelId);
  if (!parcel) return false;
  if (parcel.tier === "public") return true;
  if (parcel.ownerAccountId === session.accountId) return true;
  if (parcel.collaboratorAccountIds.includes(session.accountId)) return true;
  return false;
}

function isScriptOwnerOrAdmin(script: VisualScript, session: Session): boolean {
  return script.ownerAccountId === session.accountId || session.role === "admin";
}

// ---------------------------------------------------------------------------
// Script CRUD
// ---------------------------------------------------------------------------

export async function createScript(
  token: string,
  name: string,
  regionId: string,
  parcelId: string
): Promise<VisualScript | undefined> {
  const session = getSession(token);
  if (!session) return undefined;

  const allowed = await hasParcelBuildPermission(session, parcelId);
  if (!allowed) return undefined;

  const script: VisualScript = {
    id: randomUUID(),
    name: name.slice(0, 64),
    ownerAccountId: session.accountId,
    regionId,
    parcelId,
    nodes: [],
    connections: [],
    enabled: true,
    createdAt: new Date().toISOString(),
  };

  scripts.set(script.id, script);
  return script;
}

export function getScript(scriptId: string): VisualScript | undefined {
  return scripts.get(scriptId);
}

export async function updateScript(
  token: string,
  scriptId: string,
  nodes: ScriptNode[],
  connections: NodeConnection[]
): Promise<VisualScript | undefined> {
  const session = getSession(token);
  if (!session) return undefined;

  const script = scripts.get(scriptId);
  if (!script) return undefined;
  if (!isScriptOwnerOrAdmin(script, session)) return undefined;

  script.nodes = nodes;
  script.connections = connections;
  scripts.set(script.id, script);

  // Reset state machine when graph changes
  scriptStates.delete(scriptId);

  // Sync trigger zones from nodes
  syncTriggerZonesFromScript(script);

  return script;
}

export async function deleteScript(token: string, scriptId: string): Promise<boolean> {
  const session = getSession(token);
  if (!session) return false;

  const script = scripts.get(scriptId);
  if (!script) return false;
  if (!isScriptOwnerOrAdmin(script, session)) return false;

  // Remove associated trigger zones
  for (const [zoneId, zone] of triggerZones.entries()) {
    if (zone.scriptId === scriptId) {
      triggerZones.delete(zoneId);
    }
  }

  scriptStates.delete(scriptId);
  scripts.delete(scriptId);
  return true;
}

export function listScriptsForParcel(regionId: string, parcelId: string): VisualScript[] {
  const result: VisualScript[] = [];
  for (const script of scripts.values()) {
    if (script.regionId === regionId && script.parcelId === parcelId) {
      result.push(script);
    }
  }
  return result;
}

export function listScriptsForRegion(regionId: string): VisualScript[] {
  const result: VisualScript[] = [];
  for (const script of scripts.values()) {
    if (script.regionId === regionId) {
      result.push(script);
    }
  }
  return result;
}

export async function toggleScript(token: string, scriptId: string): Promise<VisualScript | undefined> {
  const session = getSession(token);
  if (!session) return undefined;

  const script = scripts.get(scriptId);
  if (!script) return undefined;
  if (!isScriptOwnerOrAdmin(script, session)) return undefined;

  script.enabled = !script.enabled;
  scripts.set(script.id, script);

  if (!script.enabled) {
    scriptStates.delete(scriptId);
  }

  return script;
}

// ---------------------------------------------------------------------------
// Trigger Zones
// ---------------------------------------------------------------------------

function syncTriggerZonesFromScript(script: VisualScript): void {
  // Remove old zones for this script
  for (const [zoneId, zone] of triggerZones.entries()) {
    if (zone.scriptId === script.id) {
      triggerZones.delete(zoneId);
    }
  }

  // Create zones from trigger nodes
  for (const node of script.nodes) {
    if (node.type === "trigger_zone_enter" || node.type === "trigger_zone_exit") {
      const config = node.config;
      const zone: TriggerZone = {
        id: randomUUID(),
        scriptId: script.id,
        regionId: script.regionId,
        position: {
          x: (config.posX as number) ?? 0,
          y: (config.posY as number) ?? 0,
          z: (config.posZ as number) ?? 0,
        },
        radius: (config.radius as number) ?? 3,
        shape: ((config.shape as string) === "box" ? "box" : "sphere") as TriggerZoneShape,
        size: {
          x: (config.sizeX as number) ?? 3,
          y: (config.sizeY as number) ?? 3,
          z: (config.sizeZ as number) ?? 3,
        },
      };
      triggerZones.set(zone.id, zone);
    }
  }
}

export async function createTriggerZone(
  token: string,
  scriptId: string,
  position: { x: number; y: number; z: number },
  radius: number,
  shape: TriggerZoneShape,
  size: { x: number; y: number; z: number }
): Promise<TriggerZone | undefined> {
  const session = getSession(token);
  if (!session) return undefined;

  const script = scripts.get(scriptId);
  if (!script) return undefined;
  if (!isScriptOwnerOrAdmin(script, session)) return undefined;

  const zone: TriggerZone = {
    id: randomUUID(),
    scriptId,
    regionId: script.regionId,
    position,
    radius,
    shape,
    size,
  };

  triggerZones.set(zone.id, zone);
  return zone;
}

export async function deleteTriggerZone(token: string, zoneId: string): Promise<boolean> {
  const session = getSession(token);
  if (!session) return false;

  const zone = triggerZones.get(zoneId);
  if (!zone) return false;

  const script = scripts.get(zone.scriptId);
  if (!script) return false;
  if (!isScriptOwnerOrAdmin(script, session)) return false;

  triggerZones.delete(zoneId);
  return true;
}

export function listTriggerZones(regionId: string): TriggerZone[] {
  const result: TriggerZone[] = [];
  for (const zone of triggerZones.values()) {
    if (zone.regionId === regionId) {
      result.push(zone);
    }
  }
  return result;
}

function isInsideZone(
  pos: { x: number; y: number; z: number },
  zone: TriggerZone
): boolean {
  if (zone.shape === "sphere") {
    const dx = pos.x - zone.position.x;
    const dy = pos.y - zone.position.y;
    const dz = pos.z - zone.position.z;
    return dx * dx + dy * dy + dz * dz <= zone.radius * zone.radius;
  }
  // box
  const halfX = zone.size.x / 2;
  const halfY = zone.size.y / 2;
  const halfZ = zone.size.z / 2;
  return (
    Math.abs(pos.x - zone.position.x) <= halfX &&
    Math.abs(pos.y - zone.position.y) <= halfY &&
    Math.abs(pos.z - zone.position.z) <= halfZ
  );
}

export function checkTriggerZoneEntry(
  avatarId: string,
  position: { x: number; y: number; z: number },
  regionId: string
): TriggerEvent[] {
  const events: TriggerEvent[] = [];
  const previousZones = avatarZonePresence.get(avatarId) ?? new Set<string>();
  const currentZones = new Set<string>();

  for (const zone of triggerZones.values()) {
    if (zone.regionId !== regionId) continue;

    const inside = isInsideZone(position, zone);
    if (inside) {
      currentZones.add(zone.id);
    }

    const wasInside = previousZones.has(zone.id);

    if (inside && !wasInside) {
      events.push({
        type: "zone_enter",
        avatarId,
        zoneId: zone.id,
        scriptId: zone.scriptId,
      });
    } else if (!inside && wasInside) {
      events.push({
        type: "zone_exit",
        avatarId,
        zoneId: zone.id,
        scriptId: zone.scriptId,
      });
    }
  }

  avatarZonePresence.set(avatarId, currentZones);
  return events;
}

// ---------------------------------------------------------------------------
// Script execution engine
// ---------------------------------------------------------------------------

function getOrCreateState(scriptId: string): ScriptState {
  let state = scriptStates.get(scriptId);
  if (!state) {
    state = {
      scriptId,
      activeNodeIds: new Set(),
      variables: {},
      lastTriggeredAt: null,
    };
    scriptStates.set(scriptId, state);
  }
  return state;
}

function triggerMatchesNode(trigger: TriggerEvent, node: ScriptNode): boolean {
  switch (trigger.type) {
    case "zone_enter":
      return node.type === "trigger_zone_enter";
    case "zone_exit":
      return node.type === "trigger_zone_exit";
    case "timer":
      return node.type === "timer";
    case "click_interact":
      return node.type === "click_interact";
    default:
      return false;
  }
}

function getOutgoingConnections(script: VisualScript, nodeId: string): NodeConnection[] {
  return script.connections.filter((c) => c.fromNodeId === nodeId);
}

function evaluateCondition(node: ScriptNode, _state: ScriptState, trigger: TriggerEvent): boolean {
  const field = (node.config.field as string) ?? "";
  const op = (node.config.operator as string) ?? "eq";
  const value = node.config.value;

  // Simple condition evaluation based on trigger context
  let actual: unknown;
  if (field === "avatarId") actual = trigger.avatarId;
  else if (field === "objectId") actual = trigger.objectId;
  else actual = _state.variables[field];

  switch (op) {
    case "eq":
      return actual === value;
    case "neq":
      return actual !== value;
    case "gt":
      return typeof actual === "number" && typeof value === "number" && actual > value;
    case "lt":
      return typeof actual === "number" && typeof value === "number" && actual < value;
    default:
      return true;
  }
}

function nodeToAction(node: ScriptNode): ScriptActionResult | null {
  switch (node.type) {
    case "action_chat":
      return {
        type: "chat",
        params: { message: (node.config.message as string) ?? "" },
      };
    case "action_move_object":
      return {
        type: "move_object",
        params: {
          objectId: (node.config.objectId as string) ?? "",
          x: (node.config.x as number) ?? 0,
          y: (node.config.y as number) ?? 0,
          z: (node.config.z as number) ?? 0,
        },
      };
    case "action_toggle":
      return {
        type: "toggle",
        params: {
          objectId: (node.config.objectId as string) ?? "",
          property: (node.config.property as string) ?? "visible",
        },
      };
    case "action_spawn_particles":
      return {
        type: "spawn_particles",
        params: {
          effect: (node.config.effect as string) ?? "sparkle",
          x: (node.config.x as number) ?? 0,
          y: (node.config.y as number) ?? 0,
          z: (node.config.z as number) ?? 0,
          duration: (node.config.duration as number) ?? 2,
        },
      };
    default:
      return null;
  }
}

export function executeScript(
  scriptId: string,
  trigger: TriggerEvent
): ScriptActionResult[] {
  const script = scripts.get(scriptId);
  if (!script || !script.enabled) return [];

  const state = getOrCreateState(scriptId);
  state.lastTriggeredAt = new Date().toISOString();

  const actions: ScriptActionResult[] = [];

  // Find entry nodes that match this trigger
  const entryNodes = script.nodes.filter((node) => triggerMatchesNode(trigger, node));

  // BFS through the graph from each matching entry node
  const visited = new Set<string>();
  const queue: string[] = entryNodes.map((n) => n.id);

  while (queue.length > 0) {
    const nodeId = queue.shift()!;
    if (visited.has(nodeId)) continue;
    visited.add(nodeId);

    const node = script.nodes.find((n) => n.id === nodeId);
    if (!node) continue;

    state.activeNodeIds.add(nodeId);

    // Condition node — only follow outgoing connections if condition passes
    if (node.type === "condition") {
      if (!evaluateCondition(node, state, trigger)) {
        continue; // Don't follow outgoing edges
      }
    }

    // Delay node — record the action but continue the walk
    if (node.type === "delay") {
      actions.push({
        type: "delay",
        params: { seconds: (node.config.seconds as number) ?? 1 },
      });
    }

    // Action nodes — collect actions
    const action = nodeToAction(node);
    if (action) {
      actions.push(action);
    }

    // Follow outgoing connections
    const outgoing = getOutgoingConnections(script, nodeId);
    for (const conn of outgoing) {
      if (!visited.has(conn.toNodeId)) {
        queue.push(conn.toNodeId);
      }
    }
  }

  return actions;
}
