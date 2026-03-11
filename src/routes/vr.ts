import type { FastifyInstance, FastifyPluginOptions } from "fastify";
import { getRequestToken } from "../middleware/auth.js";
import { getSession } from "../world/store.js";
import {
  createVRSession,
  endVRSession,
  getVRSession,
  getVRPreferences,
  updateVRPreferences,
  updateHandTracking,
  getVRAvatarState,
  getAllVRAvatarStates,
  startInteraction,
  updateInteraction,
  endInteraction,
  getActiveInteractions,
  validateVRBuildAction,
  saveCalibrationData,
  getCalibrationData,
  suggestHapticFeedback,
  getDefaultSpatialAudioConfig,
  type VRDeviceType,
  type VRLocomotionMode,
  type VRTurnMode,
  type VRHandedness,
  type VRComfortPreferences,
  type VRHandState,
  type VRHeadState,
  type VRInteractionType,
} from "../world/vr-service.js";

// ---------------------------------------------------------------------------
// Helper: extract and validate auth token from request body or query
// ---------------------------------------------------------------------------

function extractToken(request: { body?: unknown; query?: unknown; headers: Record<string, unknown> }): string | undefined {
  return getRequestToken(request as never);
}

// ---------------------------------------------------------------------------
// Plugin
// ---------------------------------------------------------------------------

export default async function vrRoutes(app: FastifyInstance, _opts: FastifyPluginOptions) {

  // -----------------------------------------------------------------------
  // POST /api/vr/session — Initialize a VR session with device info
  // -----------------------------------------------------------------------
  app.post<{
    Body: {
      token?: string;
      deviceType?: string;
      deviceName?: string;
      ipd?: number;
      refreshRate?: number;
      guardianWidth?: number;
      guardianDepth?: number;
    };
  }>("/api/vr/session", async (request, reply) => {
    const token = extractToken(request);
    const { deviceType, deviceName, ipd, refreshRate, guardianWidth, guardianDepth } = request.body;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const session = getSession(token);
    if (!session) {
      return reply.code(401).send({ error: "invalid session" });
    }

    const validDeviceTypes: VRDeviceType[] = ["meta_quest_2", "meta_quest_3", "meta_quest_pro", "generic_6dof", "unknown"];
    const resolvedDeviceType: VRDeviceType = validDeviceTypes.includes(deviceType as VRDeviceType)
      ? (deviceType as VRDeviceType)
      : "unknown";

    const vrSession = createVRSession(
      token,
      resolvedDeviceType,
      (deviceName ?? "Unknown VR Device").slice(0, 128),
      ipd ?? 63,
      refreshRate ?? 72,
      guardianWidth ?? null,
      guardianDepth ?? null
    );

    if (!vrSession) {
      return reply.code(500).send({ error: "failed to create VR session" });
    }

    return reply.send({ vrSession });
  });

  // -----------------------------------------------------------------------
  // GET /api/vr/session — Retrieve current VR session
  // -----------------------------------------------------------------------
  app.get<{
    Querystring: { token?: string };
  }>("/api/vr/session", async (request, reply) => {
    const token = extractToken(request);
    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const vrSession = getVRSession(token);
    if (!vrSession) {
      return reply.code(404).send({ error: "no active VR session" });
    }

    return reply.send({ vrSession });
  });

  // -----------------------------------------------------------------------
  // DELETE /api/vr/session — End VR session
  // -----------------------------------------------------------------------
  app.delete<{
    Body: { token?: string };
  }>("/api/vr/session", async (request, reply) => {
    const token = extractToken(request);
    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const ended = endVRSession(token);
    if (!ended) {
      return reply.code(404).send({ error: "no active VR session to end" });
    }

    return reply.send({ ok: true });
  });

  // -----------------------------------------------------------------------
  // GET /api/vr/preferences — Get VR comfort preferences
  // -----------------------------------------------------------------------
  app.get<{
    Querystring: { token?: string };
  }>("/api/vr/preferences", async (request, reply) => {
    const token = extractToken(request);
    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const prefs = getVRPreferences(token);
    if (!prefs) {
      return reply.code(404).send({ error: "no active VR session" });
    }

    return reply.send({ preferences: prefs });
  });

  // -----------------------------------------------------------------------
  // PATCH /api/vr/preferences — Update VR comfort preferences
  // -----------------------------------------------------------------------
  app.patch<{
    Body: {
      token?: string;
      locomotionMode?: VRLocomotionMode;
      turnMode?: VRTurnMode;
      snapTurnDegrees?: number;
      smoothTurnSpeed?: number;
      vignetteEnabled?: boolean;
      vignetteIntensity?: number;
      heightOffset?: number;
      seatedMode?: boolean;
      dominantHand?: VRHandedness;
      personalSpaceBubble?: boolean;
      personalSpaceRadius?: number;
      movementSpeed?: number;
      teleportMaxDistance?: number;
      showFloorMarker?: boolean;
    };
  }>("/api/vr/preferences", async (request, reply) => {
    const token = extractToken(request);
    const { token: _token, ...updates } = request.body;
    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const prefs = updateVRPreferences(token, updates);
    if (!prefs) {
      return reply.code(404).send({ error: "no active VR session" });
    }

    return reply.send({ preferences: prefs });
  });

  // -----------------------------------------------------------------------
  // POST /api/vr/hand-tracking — Relay hand tracking data
  // -----------------------------------------------------------------------
  app.post<{
    Body: {
      token?: string;
      headState?: VRHeadState;
      leftHand?: Partial<VRHandState>;
      rightHand?: Partial<VRHandState>;
    };
  }>("/api/vr/hand-tracking", async (request, reply) => {
    const token = extractToken(request);
    const { headState, leftHand, rightHand } = request.body;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    if (!headState) {
      return reply.code(400).send({ error: "headState is required" });
    }

    const avatarState = updateHandTracking(
      token,
      headState,
      leftHand ?? {},
      rightHand ?? {}
    );

    if (!avatarState) {
      return reply.code(404).send({ error: "no active VR session or avatar" });
    }

    return reply.send({ avatarState });
  });

  // -----------------------------------------------------------------------
  // GET /api/vr/hand-tracking/states — Get all VR avatar states (for rendering remote VR users)
  // -----------------------------------------------------------------------
  app.get<{
    Querystring: { token?: string };
  }>("/api/vr/hand-tracking/states", async (request, reply) => {
    const token = extractToken(request);
    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const session = getSession(token);
    if (!session) {
      return reply.code(401).send({ error: "invalid session" });
    }

    const states = getAllVRAvatarStates();
    return reply.send({ states });
  });

  // -----------------------------------------------------------------------
  // POST /api/vr/interactions/start — Begin a VR interaction
  // -----------------------------------------------------------------------
  app.post<{
    Body: {
      token?: string;
      interactionType?: string;
      hand?: string;
      targetObjectId?: string;
      position?: { x: number; y: number; z: number };
      rotation?: { x: number; y: number; z: number; w: number };
    };
  }>("/api/vr/interactions/start", async (request, reply) => {
    const { token, interactionType, hand, targetObjectId, position, rotation } = request.body;

    if (!token || !interactionType || !hand || !position || !rotation) {
      return reply.code(400).send({ error: "token, interactionType, hand, position, and rotation are required" });
    }

    const interaction = startInteraction(
      token,
      interactionType as VRInteractionType,
      hand as "left" | "right",
      targetObjectId ?? null,
      position,
      rotation
    );

    if (!interaction) {
      return reply.code(403).send({ error: "failed to start interaction" });
    }

    const haptics = suggestHapticFeedback(interactionType as VRInteractionType, 0.5);
    return reply.send({ interaction, haptics });
  });

  // -----------------------------------------------------------------------
  // PATCH /api/vr/interactions/:interactionId — Update ongoing interaction
  // -----------------------------------------------------------------------
  app.patch<{
    Params: { interactionId: string };
    Body: {
      token?: string;
      position?: { x: number; y: number; z: number };
      rotation?: { x: number; y: number; z: number; w: number };
      strength?: number;
    };
  }>("/api/vr/interactions/:interactionId", async (request, reply) => {
    const { token, position, rotation, strength } = request.body;

    if (!token || !position || !rotation) {
      return reply.code(400).send({ error: "token, position, and rotation are required" });
    }

    const interaction = updateInteraction(
      token,
      request.params.interactionId,
      position,
      rotation,
      strength ?? 0
    );

    if (!interaction) {
      return reply.code(404).send({ error: "interaction not found" });
    }

    return reply.send({ interaction });
  });

  // -----------------------------------------------------------------------
  // DELETE /api/vr/interactions/:interactionId — End interaction
  // -----------------------------------------------------------------------
  app.delete<{
    Params: { interactionId: string };
    Body: { token?: string };
  }>("/api/vr/interactions/:interactionId", async (request, reply) => {
    const token = request.body.token;
    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const ended = endInteraction(token, request.params.interactionId);
    if (!ended) {
      return reply.code(404).send({ error: "interaction not found" });
    }

    return reply.send({ ok: true });
  });

  // -----------------------------------------------------------------------
  // GET /api/vr/interactions — Get active interactions for user
  // -----------------------------------------------------------------------
  app.get<{
    Querystring: { token?: string };
  }>("/api/vr/interactions", async (request, reply) => {
    const token = request.query.token;
    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const interactions = getActiveInteractions(token);
    return reply.send({ interactions });
  });

  // -----------------------------------------------------------------------
  // POST /api/vr/build — Hand-based building action
  // -----------------------------------------------------------------------
  app.post<{
    Body: {
      token?: string;
      actionType?: string;
      hand?: string;
      objectId?: string;
      asset?: string;
      position?: { x: number; y: number; z: number };
      rotation?: { x: number; y: number; z: number; w: number };
      scale?: number;
    };
  }>("/api/vr/build", async (request, reply) => {
    const { token, actionType, hand, objectId, asset, position, rotation, scale } = request.body;

    if (!token || !actionType || !hand || !position || !rotation) {
      return reply.code(400).send({ error: "token, actionType, hand, position, and rotation are required" });
    }

    const validActions = ["place", "move", "rotate", "scale", "delete", "duplicate"];
    if (!validActions.includes(actionType)) {
      return reply.code(400).send({ error: `actionType must be one of: ${validActions.join(", ")}` });
    }

    const validHands = ["left", "right"];
    if (!validHands.includes(hand)) {
      return reply.code(400).send({ error: "hand must be 'left' or 'right'" });
    }

    const buildAction = validateVRBuildAction(
      token,
      actionType as "place" | "move" | "rotate" | "scale" | "delete" | "duplicate",
      hand as "left" | "right",
      objectId ?? null,
      asset ?? null,
      position,
      rotation,
      scale ?? 1.0
    );

    if (!buildAction) {
      return reply.code(403).send({ error: "build action validation failed" });
    }

    const haptics = suggestHapticFeedback("manipulate", 0.7);
    return reply.send({ buildAction, haptics });
  });

  // -----------------------------------------------------------------------
  // POST /api/vr/calibrate — Save calibration data
  // -----------------------------------------------------------------------
  app.post<{
    Body: {
      token?: string;
      floorHeight?: number;
      eyeHeight?: number;
      armSpan?: number;
      handOffsetLeft?: { x: number; y: number; z: number };
      handOffsetRight?: { x: number; y: number; z: number };
    };
  }>("/api/vr/calibrate", async (request, reply) => {
    const { token, floorHeight, eyeHeight, armSpan, handOffsetLeft, handOffsetRight } = request.body;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    if (floorHeight === undefined || eyeHeight === undefined || armSpan === undefined || !handOffsetLeft || !handOffsetRight) {
      return reply.code(400).send({ error: "floorHeight, eyeHeight, armSpan, handOffsetLeft, and handOffsetRight are required" });
    }

    const calibration = saveCalibrationData(
      token,
      floorHeight,
      eyeHeight,
      armSpan,
      handOffsetLeft,
      handOffsetRight
    );

    if (!calibration) {
      return reply.code(404).send({ error: "no active VR session or invalid calibration data" });
    }

    return reply.send({ calibration });
  });

  // -----------------------------------------------------------------------
  // GET /api/vr/calibrate — Get current calibration data
  // -----------------------------------------------------------------------
  app.get<{
    Querystring: { token?: string };
  }>("/api/vr/calibrate", async (request, reply) => {
    const token = request.query.token;
    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const calibration = getCalibrationData(token);
    if (!calibration) {
      return reply.code(404).send({ error: "no calibration data found" });
    }

    return reply.send({ calibration });
  });

  // -----------------------------------------------------------------------
  // GET /api/vr/spatial-audio/config — Get default spatial audio config
  // -----------------------------------------------------------------------
  app.get<{
    Querystring: { token?: string };
  }>("/api/vr/spatial-audio/config", async (request, reply) => {
    const token = request.query.token;
    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const session = getSession(token);
    if (!session) {
      return reply.code(401).send({ error: "invalid session" });
    }

    const config = getDefaultSpatialAudioConfig();
    return reply.send({ config });
  });
}
