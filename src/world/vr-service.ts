// VR Service — Feature 20: VR Support
//
// Integration notes for server.ts / store.ts:
//   - server.ts: import and register vrRoutes from "../routes/vr.js"
//     await app.register(vrRoutes);
//   - store.ts: no changes required — this service imports getSession from store.js

import { randomUUID } from "node:crypto";
import { getSession, type Session } from "./store.js";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export type VRDeviceType = "meta_quest_2" | "meta_quest_3" | "meta_quest_pro" | "generic_6dof" | "unknown";

export type VRLocomotionMode = "teleport" | "smooth" | "hybrid";

export type VRTurnMode = "snap" | "smooth";

export type VRHandedness = "left" | "right" | "ambidextrous";

export type VRComfortPreferences = {
  locomotionMode: VRLocomotionMode;
  turnMode: VRTurnMode;
  snapTurnDegrees: number;
  smoothTurnSpeed: number;
  vignetteEnabled: boolean;
  vignetteIntensity: number;
  heightOffset: number;
  seatedMode: boolean;
  dominantHand: VRHandedness;
  personalSpaceBubble: boolean;
  personalSpaceRadius: number;
  movementSpeed: number;
  teleportMaxDistance: number;
  showFloorMarker: boolean;
};

export type VRHandState = {
  position: { x: number; y: number; z: number };
  rotation: { x: number; y: number; z: number; w: number };
  fingers: {
    thumb: number;
    index: number;
    middle: number;
    ring: number;
    pinky: number;
  };
  gesture: VRGestureType;
  pinchStrength: number;
  gripStrength: number;
};

export type VRGestureType =
  | "none"
  | "open_hand"
  | "fist"
  | "point"
  | "pinch"
  | "thumbs_up"
  | "peace"
  | "grab";

export type VRHeadState = {
  position: { x: number; y: number; z: number };
  rotation: { x: number; y: number; z: number; w: number };
};

export type VRAvatarState = {
  accountId: string;
  headState: VRHeadState;
  leftHand: VRHandState;
  rightHand: VRHandState;
  isVRUser: boolean;
  updatedAt: string;
};

export type VRSession = {
  id: string;
  accountId: string;
  deviceType: VRDeviceType;
  deviceName: string;
  ipd: number;
  refreshRate: number;
  guardianBounds: { width: number; depth: number } | null;
  preferences: VRComfortPreferences;
  calibrationData: VRCalibrationData | null;
  avatarState: VRAvatarState;
  createdAt: string;
  updatedAt: string;
};

export type VRCalibrationData = {
  floorHeight: number;
  eyeHeight: number;
  armSpan: number;
  handOffsetLeft: { x: number; y: number; z: number };
  handOffsetRight: { x: number; y: number; z: number };
  calibratedAt: string;
};

export type VRInteractionType = "grab" | "point" | "manipulate" | "ui_interact" | "teleport_aim";

export type VRInteraction = {
  id: string;
  accountId: string;
  interactionType: VRInteractionType;
  hand: "left" | "right";
  targetObjectId: string | null;
  position: { x: number; y: number; z: number };
  rotation: { x: number; y: number; z: number; w: number };
  strength: number;
  timestamp: string;
};

export type VRBuildAction = {
  id: string;
  accountId: string;
  actionType: "place" | "move" | "rotate" | "scale" | "delete" | "duplicate";
  objectId: string | null;
  asset: string | null;
  position: { x: number; y: number; z: number };
  rotation: { x: number; y: number; z: number; w: number };
  scale: number;
  hand: "left" | "right";
  timestamp: string;
};

export type HapticFeedback = {
  hand: "left" | "right";
  intensity: number;
  duration: number;
  pattern: "pulse" | "buzz" | "click" | "rumble";
};

// ---------------------------------------------------------------------------
// In-memory stores
// ---------------------------------------------------------------------------

const vrSessions = new Map<string, VRSession>();
const vrAvatarStates = new Map<string, VRAvatarState>();
const activeInteractions = new Map<string, VRInteraction>();

const DEFAULT_PREFERENCES: VRComfortPreferences = {
  locomotionMode: "teleport",
  turnMode: "snap",
  snapTurnDegrees: 45,
  smoothTurnSpeed: 1.0,
  vignetteEnabled: true,
  vignetteIntensity: 0.6,
  heightOffset: 0.0,
  seatedMode: false,
  dominantHand: "right",
  personalSpaceBubble: true,
  personalSpaceRadius: 1.0,
  movementSpeed: 1.0,
  teleportMaxDistance: 10.0,
  showFloorMarker: true,
};

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function makeDefaultHandState(): VRHandState {
  return {
    position: { x: 0, y: 0, z: 0 },
    rotation: { x: 0, y: 0, z: 0, w: 1 },
    fingers: { thumb: 0, index: 0, middle: 0, ring: 0, pinky: 0 },
    gesture: "none",
    pinchStrength: 0,
    gripStrength: 0,
  };
}

function makeDefaultHeadState(): VRHeadState {
  return {
    position: { x: 0, y: 1.6, z: 0 },
    rotation: { x: 0, y: 0, z: 0, w: 1 },
  };
}

function clampFloat(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}

function isValidQuaternion(q: { x: number; y: number; z: number; w: number }): boolean {
  if (!Number.isFinite(q.x) || !Number.isFinite(q.y) || !Number.isFinite(q.z) || !Number.isFinite(q.w)) {
    return false;
  }
  const lenSq = q.x * q.x + q.y * q.y + q.z * q.z + q.w * q.w;
  return lenSq > 0.5 && lenSq < 1.5;
}

function isValidPosition(p: { x: number; y: number; z: number }): boolean {
  return Number.isFinite(p.x) && Number.isFinite(p.y) && Number.isFinite(p.z);
}

function sanitizePosition(p: { x: number; y: number; z: number }): { x: number; y: number; z: number } {
  return {
    x: clampFloat(p.x, -100, 100),
    y: clampFloat(p.y, -5, 50),
    z: clampFloat(p.z, -100, 100),
  };
}

function detectGesture(fingers: VRHandState["fingers"], pinch: number, grip: number): VRGestureType {
  const allCurled = fingers.thumb > 0.7 && fingers.index > 0.7 && fingers.middle > 0.7 && fingers.ring > 0.7 && fingers.pinky > 0.7;
  const allOpen = fingers.thumb < 0.3 && fingers.index < 0.3 && fingers.middle < 0.3 && fingers.ring < 0.3 && fingers.pinky < 0.3;

  if (grip > 0.8 && allCurled) return "grab";
  if (allCurled && grip < 0.3) return "fist";
  if (allOpen) return "open_hand";
  if (pinch > 0.8) return "pinch";
  if (fingers.index < 0.3 && fingers.middle > 0.6 && fingers.ring > 0.6 && fingers.pinky > 0.6) return "point";
  if (fingers.thumb < 0.3 && fingers.index > 0.6 && fingers.middle > 0.6 && fingers.ring > 0.6 && fingers.pinky > 0.6) return "thumbs_up";
  if (fingers.index < 0.3 && fingers.middle < 0.3 && fingers.ring > 0.6 && fingers.pinky > 0.6) return "peace";

  return "none";
}

// ---------------------------------------------------------------------------
// VR Session Management
// ---------------------------------------------------------------------------

export function createVRSession(
  token: string,
  deviceType: VRDeviceType,
  deviceName: string,
  ipd: number,
  refreshRate: number,
  guardianWidth: number | null,
  guardianDepth: number | null
): VRSession | undefined {
  const session = getSession(token);
  if (!session) return undefined;

  // Remove any existing VR session for this account
  for (const [id, vrs] of vrSessions.entries()) {
    if (vrs.accountId === session.accountId) {
      vrSessions.delete(id);
      break;
    }
  }

  const id = randomUUID();
  const now = new Date().toISOString();

  const guardianBounds = (guardianWidth !== null && guardianDepth !== null)
    ? { width: clampFloat(guardianWidth, 0.5, 20), depth: clampFloat(guardianDepth, 0.5, 20) }
    : null;

  const avatarState: VRAvatarState = {
    accountId: session.accountId,
    headState: makeDefaultHeadState(),
    leftHand: makeDefaultHandState(),
    rightHand: makeDefaultHandState(),
    isVRUser: true,
    updatedAt: now,
  };

  const vrSession: VRSession = {
    id,
    accountId: session.accountId,
    deviceType,
    deviceName: deviceName.slice(0, 128),
    ipd: clampFloat(ipd, 50, 80),
    refreshRate: clampFloat(refreshRate, 60, 144),
    guardianBounds,
    preferences: { ...DEFAULT_PREFERENCES },
    calibrationData: null,
    avatarState,
    createdAt: now,
    updatedAt: now,
  };

  vrSessions.set(id, vrSession);
  vrAvatarStates.set(session.accountId, avatarState);

  return vrSession;
}

export function getVRSession(token: string): VRSession | undefined {
  const session = getSession(token);
  if (!session) return undefined;

  for (const vrs of vrSessions.values()) {
    if (vrs.accountId === session.accountId) {
      return vrs;
    }
  }
  return undefined;
}

export function endVRSession(token: string): boolean {
  const session = getSession(token);
  if (!session) return false;

  for (const [id, vrs] of vrSessions.entries()) {
    if (vrs.accountId === session.accountId) {
      vrSessions.delete(id);
      vrAvatarStates.delete(session.accountId);

      // Clear active interactions
      for (const [intId, interaction] of activeInteractions.entries()) {
        if (interaction.accountId === session.accountId) {
          activeInteractions.delete(intId);
        }
      }
      return true;
    }
  }
  return false;
}

// ---------------------------------------------------------------------------
// Comfort Preferences
// ---------------------------------------------------------------------------

export function getVRPreferences(token: string): VRComfortPreferences | undefined {
  const vrSession = getVRSession(token);
  if (!vrSession) return undefined;
  return vrSession.preferences;
}

export function updateVRPreferences(token: string, updates: Partial<VRComfortPreferences>): VRComfortPreferences | undefined {
  const session = getSession(token);
  if (!session) return undefined;

  let vrSession: VRSession | undefined;
  for (const vrs of vrSessions.values()) {
    if (vrs.accountId === session.accountId) {
      vrSession = vrs;
      break;
    }
  }
  if (!vrSession) return undefined;

  const prefs = vrSession.preferences;

  if (updates.locomotionMode !== undefined) {
    const modes: VRLocomotionMode[] = ["teleport", "smooth", "hybrid"];
    if (modes.includes(updates.locomotionMode)) prefs.locomotionMode = updates.locomotionMode;
  }
  if (updates.turnMode !== undefined) {
    const turns: VRTurnMode[] = ["snap", "smooth"];
    if (turns.includes(updates.turnMode)) prefs.turnMode = updates.turnMode;
  }
  if (updates.snapTurnDegrees !== undefined) {
    prefs.snapTurnDegrees = clampFloat(updates.snapTurnDegrees, 15, 90);
  }
  if (updates.smoothTurnSpeed !== undefined) {
    prefs.smoothTurnSpeed = clampFloat(updates.smoothTurnSpeed, 0.1, 3.0);
  }
  if (updates.vignetteEnabled !== undefined) {
    prefs.vignetteEnabled = Boolean(updates.vignetteEnabled);
  }
  if (updates.vignetteIntensity !== undefined) {
    prefs.vignetteIntensity = clampFloat(updates.vignetteIntensity, 0.0, 1.0);
  }
  if (updates.heightOffset !== undefined) {
    prefs.heightOffset = clampFloat(updates.heightOffset, -1.0, 1.0);
  }
  if (updates.seatedMode !== undefined) {
    prefs.seatedMode = Boolean(updates.seatedMode);
  }
  if (updates.dominantHand !== undefined) {
    const hands: VRHandedness[] = ["left", "right", "ambidextrous"];
    if (hands.includes(updates.dominantHand)) prefs.dominantHand = updates.dominantHand;
  }
  if (updates.personalSpaceBubble !== undefined) {
    prefs.personalSpaceBubble = Boolean(updates.personalSpaceBubble);
  }
  if (updates.personalSpaceRadius !== undefined) {
    prefs.personalSpaceRadius = clampFloat(updates.personalSpaceRadius, 0.3, 3.0);
  }
  if (updates.movementSpeed !== undefined) {
    prefs.movementSpeed = clampFloat(updates.movementSpeed, 0.2, 3.0);
  }
  if (updates.teleportMaxDistance !== undefined) {
    prefs.teleportMaxDistance = clampFloat(updates.teleportMaxDistance, 2.0, 30.0);
  }
  if (updates.showFloorMarker !== undefined) {
    prefs.showFloorMarker = Boolean(updates.showFloorMarker);
  }

  vrSession.updatedAt = new Date().toISOString();
  return prefs;
}

// ---------------------------------------------------------------------------
// Hand Tracking Data Relay
// ---------------------------------------------------------------------------

export function updateHandTracking(
  token: string,
  headState: VRHeadState,
  leftHand: Partial<VRHandState>,
  rightHand: Partial<VRHandState>
): VRAvatarState | undefined {
  const session = getSession(token);
  if (!session) return undefined;

  const avatarState = vrAvatarStates.get(session.accountId);
  if (!avatarState) return undefined;

  // Validate and update head state
  if (isValidPosition(headState.position) && isValidQuaternion(headState.rotation)) {
    avatarState.headState = {
      position: sanitizePosition(headState.position),
      rotation: headState.rotation,
    };
  }

  // Update left hand
  if (leftHand.position && isValidPosition(leftHand.position)) {
    avatarState.leftHand.position = sanitizePosition(leftHand.position);
  }
  if (leftHand.rotation && isValidQuaternion(leftHand.rotation)) {
    avatarState.leftHand.rotation = leftHand.rotation;
  }
  if (leftHand.fingers) {
    avatarState.leftHand.fingers = {
      thumb: clampFloat(leftHand.fingers.thumb, 0, 1),
      index: clampFloat(leftHand.fingers.index, 0, 1),
      middle: clampFloat(leftHand.fingers.middle, 0, 1),
      ring: clampFloat(leftHand.fingers.ring, 0, 1),
      pinky: clampFloat(leftHand.fingers.pinky, 0, 1),
    };
  }
  if (leftHand.pinchStrength !== undefined) {
    avatarState.leftHand.pinchStrength = clampFloat(leftHand.pinchStrength, 0, 1);
  }
  if (leftHand.gripStrength !== undefined) {
    avatarState.leftHand.gripStrength = clampFloat(leftHand.gripStrength, 0, 1);
  }
  avatarState.leftHand.gesture = detectGesture(
    avatarState.leftHand.fingers,
    avatarState.leftHand.pinchStrength,
    avatarState.leftHand.gripStrength
  );

  // Update right hand
  if (rightHand.position && isValidPosition(rightHand.position)) {
    avatarState.rightHand.position = sanitizePosition(rightHand.position);
  }
  if (rightHand.rotation && isValidQuaternion(rightHand.rotation)) {
    avatarState.rightHand.rotation = rightHand.rotation;
  }
  if (rightHand.fingers) {
    avatarState.rightHand.fingers = {
      thumb: clampFloat(rightHand.fingers.thumb, 0, 1),
      index: clampFloat(rightHand.fingers.index, 0, 1),
      middle: clampFloat(rightHand.fingers.middle, 0, 1),
      ring: clampFloat(rightHand.fingers.ring, 0, 1),
      pinky: clampFloat(rightHand.fingers.pinky, 0, 1),
    };
  }
  if (rightHand.pinchStrength !== undefined) {
    avatarState.rightHand.pinchStrength = clampFloat(rightHand.pinchStrength, 0, 1);
  }
  if (rightHand.gripStrength !== undefined) {
    avatarState.rightHand.gripStrength = clampFloat(rightHand.gripStrength, 0, 1);
  }
  avatarState.rightHand.gesture = detectGesture(
    avatarState.rightHand.fingers,
    avatarState.rightHand.pinchStrength,
    avatarState.rightHand.gripStrength
  );

  avatarState.updatedAt = new Date().toISOString();
  vrAvatarStates.set(session.accountId, avatarState);

  return avatarState;
}

export function getVRAvatarState(accountId: string): VRAvatarState | undefined {
  return vrAvatarStates.get(accountId);
}

export function getAllVRAvatarStates(): VRAvatarState[] {
  return [...vrAvatarStates.values()];
}

// ---------------------------------------------------------------------------
// VR Interaction Validation
// ---------------------------------------------------------------------------

export function startInteraction(
  token: string,
  interactionType: VRInteractionType,
  hand: "left" | "right",
  targetObjectId: string | null,
  position: { x: number; y: number; z: number },
  rotation: { x: number; y: number; z: number; w: number }
): VRInteraction | undefined {
  const session = getSession(token);
  if (!session) return undefined;

  if (!isValidPosition(position)) return undefined;
  if (!isValidQuaternion(rotation)) return undefined;

  const validTypes: VRInteractionType[] = ["grab", "point", "manipulate", "ui_interact", "teleport_aim"];
  if (!validTypes.includes(interactionType)) return undefined;

  const validHands = ["left", "right"];
  if (!validHands.includes(hand)) return undefined;

  // End any existing interaction for this hand
  for (const [id, existing] of activeInteractions.entries()) {
    if (existing.accountId === session.accountId && existing.hand === hand) {
      activeInteractions.delete(id);
      break;
    }
  }

  const interaction: VRInteraction = {
    id: randomUUID(),
    accountId: session.accountId,
    interactionType,
    hand,
    targetObjectId,
    position: sanitizePosition(position),
    rotation,
    strength: 0,
    timestamp: new Date().toISOString(),
  };

  activeInteractions.set(interaction.id, interaction);
  return interaction;
}

export function updateInteraction(
  token: string,
  interactionId: string,
  position: { x: number; y: number; z: number },
  rotation: { x: number; y: number; z: number; w: number },
  strength: number
): VRInteraction | undefined {
  const session = getSession(token);
  if (!session) return undefined;

  const interaction = activeInteractions.get(interactionId);
  if (!interaction || interaction.accountId !== session.accountId) return undefined;

  if (isValidPosition(position)) {
    interaction.position = sanitizePosition(position);
  }
  if (isValidQuaternion(rotation)) {
    interaction.rotation = rotation;
  }
  interaction.strength = clampFloat(strength, 0, 1);
  interaction.timestamp = new Date().toISOString();

  return interaction;
}

export function endInteraction(token: string, interactionId: string): boolean {
  const session = getSession(token);
  if (!session) return false;

  const interaction = activeInteractions.get(interactionId);
  if (!interaction || interaction.accountId !== session.accountId) return false;

  activeInteractions.delete(interactionId);
  return true;
}

export function getActiveInteractions(token: string): VRInteraction[] {
  const session = getSession(token);
  if (!session) return [];

  const result: VRInteraction[] = [];
  for (const interaction of activeInteractions.values()) {
    if (interaction.accountId === session.accountId) {
      result.push(interaction);
    }
  }
  return result;
}

// ---------------------------------------------------------------------------
// VR Build Mode (hand-based object placement / manipulation)
// ---------------------------------------------------------------------------

export function validateVRBuildAction(
  token: string,
  actionType: VRBuildAction["actionType"],
  hand: "left" | "right",
  objectId: string | null,
  asset: string | null,
  position: { x: number; y: number; z: number },
  rotation: { x: number; y: number; z: number; w: number },
  scale: number
): VRBuildAction | undefined {
  const session = getSession(token);
  if (!session) return undefined;

  if (!isValidPosition(position)) return undefined;
  if (!isValidQuaternion(rotation)) return undefined;

  const validActions: VRBuildAction["actionType"][] = ["place", "move", "rotate", "scale", "delete", "duplicate"];
  if (!validActions.includes(actionType)) return undefined;

  if (actionType === "place" && !asset) return undefined;
  if ((actionType === "move" || actionType === "rotate" || actionType === "scale" || actionType === "delete" || actionType === "duplicate") && !objectId) {
    return undefined;
  }

  const buildAction: VRBuildAction = {
    id: randomUUID(),
    accountId: session.accountId,
    actionType,
    objectId,
    asset,
    position: sanitizePosition(position),
    rotation,
    scale: clampFloat(scale, 0.1, 10.0),
    hand,
    timestamp: new Date().toISOString(),
  };

  return buildAction;
}

// ---------------------------------------------------------------------------
// Calibration
// ---------------------------------------------------------------------------

export function saveCalibrationData(
  token: string,
  floorHeight: number,
  eyeHeight: number,
  armSpan: number,
  handOffsetLeft: { x: number; y: number; z: number },
  handOffsetRight: { x: number; y: number; z: number }
): VRCalibrationData | undefined {
  const session = getSession(token);
  if (!session) return undefined;

  let vrSession: VRSession | undefined;
  for (const vrs of vrSessions.values()) {
    if (vrs.accountId === session.accountId) {
      vrSession = vrs;
      break;
    }
  }
  if (!vrSession) return undefined;

  if (!isValidPosition(handOffsetLeft) || !isValidPosition(handOffsetRight)) return undefined;

  const calibration: VRCalibrationData = {
    floorHeight: clampFloat(floorHeight, -2, 2),
    eyeHeight: clampFloat(eyeHeight, 0.5, 2.5),
    armSpan: clampFloat(armSpan, 0.3, 3.0),
    handOffsetLeft: sanitizePosition(handOffsetLeft),
    handOffsetRight: sanitizePosition(handOffsetRight),
    calibratedAt: new Date().toISOString(),
  };

  vrSession.calibrationData = calibration;
  vrSession.updatedAt = new Date().toISOString();

  // Apply eye height to preferences height offset if seated mode
  if (vrSession.preferences.seatedMode) {
    vrSession.preferences.heightOffset = calibration.eyeHeight - 1.6;
  }

  return calibration;
}

export function getCalibrationData(token: string): VRCalibrationData | undefined {
  const vrSession = getVRSession(token);
  return vrSession?.calibrationData ?? undefined;
}

// ---------------------------------------------------------------------------
// Haptic Feedback Suggestions
// ---------------------------------------------------------------------------

export function suggestHapticFeedback(interactionType: VRInteractionType, strength: number): HapticFeedback[] {
  const haptics: HapticFeedback[] = [];

  switch (interactionType) {
    case "grab":
      haptics.push({
        hand: "right",
        intensity: clampFloat(strength * 0.5, 0.1, 0.8),
        duration: 0.05,
        pattern: "click",
      });
      break;
    case "point":
      haptics.push({
        hand: "right",
        intensity: 0.1,
        duration: 0.02,
        pattern: "pulse",
      });
      break;
    case "manipulate":
      haptics.push({
        hand: "right",
        intensity: clampFloat(strength * 0.3, 0.05, 0.5),
        duration: 0.1,
        pattern: "rumble",
      });
      break;
    case "ui_interact":
      haptics.push({
        hand: "right",
        intensity: 0.2,
        duration: 0.03,
        pattern: "click",
      });
      break;
    case "teleport_aim":
      haptics.push({
        hand: "left",
        intensity: 0.15,
        duration: 0.08,
        pattern: "buzz",
      });
      break;
  }

  return haptics;
}

// ---------------------------------------------------------------------------
// Spatial Audio Helpers
// ---------------------------------------------------------------------------

export type SpatialAudioConfig = {
  listenerPosition: { x: number; y: number; z: number };
  listenerForward: { x: number; y: number; z: number };
  listenerUp: { x: number; y: number; z: number };
  hrtfEnabled: boolean;
  roomSize: "small" | "medium" | "large" | "outdoor";
  reverbLevel: number;
  occlusionEnabled: boolean;
};

export function getDefaultSpatialAudioConfig(): SpatialAudioConfig {
  return {
    listenerPosition: { x: 0, y: 1.6, z: 0 },
    listenerForward: { x: 0, y: 0, z: -1 },
    listenerUp: { x: 0, y: 1, z: 0 },
    hrtfEnabled: true,
    roomSize: "medium",
    reverbLevel: 0.3,
    occlusionEnabled: true,
  };
}

export function computeSpatialAudioParams(
  listenerHead: VRHeadState,
  sourcePosition: { x: number; y: number; z: number }
): { distance: number; azimuth: number; elevation: number; attenuation: number } {
  const dx = sourcePosition.x - listenerHead.position.x;
  const dy = sourcePosition.y - listenerHead.position.y;
  const dz = sourcePosition.z - listenerHead.position.z;

  const distance = Math.sqrt(dx * dx + dy * dy + dz * dz);
  const azimuth = Math.atan2(dx, -dz) * (180 / Math.PI);
  const horizontalDist = Math.sqrt(dx * dx + dz * dz);
  const elevation = Math.atan2(dy, horizontalDist) * (180 / Math.PI);

  // Inverse-square falloff with a minimum distance of 0.5m to prevent infinite gain
  const effectiveDistance = Math.max(distance, 0.5);
  const attenuation = Math.min(1.0, 1.0 / (effectiveDistance * effectiveDistance));

  return { distance, azimuth, elevation, attenuation };
}
