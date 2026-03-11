import { FastifyInstance } from "fastify";
import {
  addParcelCollaborator,
  appendAuditLog,
  claimParcel,
  getSession,
  releaseParcel,
  removeParcelCollaborator,
  transferParcel
} from "../world/store.js";
import { broadcastRegion, nextRegionSequence } from "../world/region.js";

export default async function parcelRoutes(app: FastifyInstance) {
  app.post<{ Body: { token?: string; parcelId?: string } }>("/api/parcels/claim", async (request, reply) => {
    const token = request.body.token;
    const parcelId = request.body.parcelId;

    if (!token || !parcelId) {
      return reply.code(400).send({ error: "token and parcelId are required" });
    }

    const parcel = await claimParcel(token, parcelId);

    if (!parcel) {
      return reply.code(409).send({ error: "parcel unavailable" });
    }

    const session = getSession(token);

    if (session) {
      broadcastRegion(session.regionId, { type: "parcel:updated", sequence: nextRegionSequence(session.regionId), parcel });
      await appendAuditLog(token, "parcel.claim", "parcel", parcel.id, `claimed ${parcel.name}`, session.regionId);
    }

    return reply.send({ parcel });
  });

  app.post<{ Body: { token?: string; parcelId?: string } }>("/api/parcels/release", async (request, reply) => {
    const token = request.body.token;
    const parcelId = request.body.parcelId;

    if (!token || !parcelId) {
      return reply.code(400).send({ error: "token and parcelId are required" });
    }

    const parcel = await releaseParcel(token, parcelId);

    if (!parcel) {
      return reply.code(409).send({ error: "parcel unavailable" });
    }

    const session = getSession(token);

    if (session) {
      broadcastRegion(session.regionId, { type: "parcel:updated", sequence: nextRegionSequence(session.regionId), parcel });
      await appendAuditLog(token, "parcel.release", "parcel", parcel.id, `released ${parcel.name}`, session.regionId);
    }

    return reply.send({ parcel });
  });

  app.post<{ Body: { token?: string; parcelId?: string; collaboratorAccountId?: string } }>("/api/parcels/collaborators/add", async (request, reply) => {
    const { token, parcelId, collaboratorAccountId } = request.body;
    if (!token || !parcelId || !collaboratorAccountId) {
      return reply.code(400).send({ error: "token, parcelId and collaboratorAccountId are required" });
    }
    const parcel = await addParcelCollaborator(token, parcelId, collaboratorAccountId);
    if (!parcel) {
      return reply.code(403).send({ error: "unable to add collaborator" });
    }
    const session = getSession(token);
    if (session) {
      broadcastRegion(session.regionId, { type: "parcel:updated", sequence: nextRegionSequence(session.regionId), parcel });
      await appendAuditLog(token, "parcel.collaborator.add", "parcel", parcel.id, `added collaborator ${collaboratorAccountId}`, session.regionId);
    }
    return reply.send({ parcel });
  });

  app.post<{ Body: { token?: string; parcelId?: string; collaboratorAccountId?: string } }>("/api/parcels/collaborators/remove", async (request, reply) => {
    const { token, parcelId, collaboratorAccountId } = request.body;
    if (!token || !parcelId || !collaboratorAccountId) {
      return reply.code(400).send({ error: "token, parcelId and collaboratorAccountId are required" });
    }
    const parcel = await removeParcelCollaborator(token, parcelId, collaboratorAccountId);
    if (!parcel) {
      return reply.code(403).send({ error: "unable to remove collaborator" });
    }
    const session = getSession(token);
    if (session) {
      broadcastRegion(session.regionId, { type: "parcel:updated", sequence: nextRegionSequence(session.regionId), parcel });
      await appendAuditLog(token, "parcel.collaborator.remove", "parcel", parcel.id, `removed collaborator ${collaboratorAccountId}`, session.regionId);
    }
    return reply.send({ parcel });
  });

  app.post<{ Body: { token?: string; parcelId?: string; ownerAccountId?: string | null } }>("/api/parcels/transfer", async (request, reply) => {
    const { token, parcelId, ownerAccountId = null } = request.body;
    if (!token || !parcelId) {
      return reply.code(400).send({ error: "token and parcelId are required" });
    }
    const parcel = await transferParcel(token, parcelId, ownerAccountId);
    if (!parcel) {
      return reply.code(403).send({ error: "unable to transfer parcel" });
    }
    const session = getSession(token);
    if (session) {
      broadcastRegion(session.regionId, { type: "parcel:updated", sequence: nextRegionSequence(session.regionId), parcel });
      await appendAuditLog(token, "parcel.transfer", "parcel", parcel.id, `transferred parcel to ${ownerAccountId ?? "none"}`, session.regionId);
    }
    return reply.send({ parcel });
  });
}
