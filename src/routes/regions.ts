import { FastifyInstance } from "fastify";
import {
  createRegionObject,
  getSession,
  getRegionPopulation,
  listParcels,
  listRegionObjects,
  listRegions,
  listRegionNotices,
  createRegionNotice,
  deleteRegionNotice
} from "../world/store.js";

export default async function regionRoutes(app: FastifyInstance) {
  app.get("/api/regions", async () => ({
    regions: listRegions().map((region) => ({
      ...region,
      population: getRegionPopulation(region.id).length
    }))
  }));

  app.get<{ Params: { regionId: string } }>("/api/regions/:regionId/parcels", async (request) => ({
    parcels: await listParcels(request.params.regionId)
  }));

  app.get<{ Params: { regionId: string } }>("/api/regions/:regionId/objects", async (request) => ({
    objects: await listRegionObjects(request.params.regionId)
  }));

  app.post<{
    Params: { regionId: string };
    Body: { token?: string; asset?: string; x?: number; y?: number; z?: number; rotationY?: number; scale?: number };
  }>("/api/regions/:regionId/objects", async (request, reply) => {
    const { token, asset, x, y, z, rotationY, scale } = request.body;
    const session = token ? getSession(token) : undefined;

    if (!token || !asset || x === undefined || y === undefined || z === undefined) {
      return reply.code(400).send({ error: "token, asset, x, y, and z are required" });
    }

    if (!session || session.regionId !== request.params.regionId) {
      return reply.code(403).send({ error: "session is not active in this region" });
    }

    const object = await createRegionObject(token, {
      asset,
      x,
      y,
      z,
      rotationY: rotationY ?? 0,
      scale: scale ?? 1
    });

    if (!object.object || object.object.regionId !== request.params.regionId) {
      return reply.code(403).send({ error: object.permission.reason ?? "unable to create object in region" });
    }

    return reply.send({ object: object.object });
  });

  app.get<{ Querystring: { token?: string } }>("/api/regions/notices", async (request, reply) => {
    const token = request.query.token;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const notices = await listRegionNotices(token);
    return reply.send({ notices });
  });

  app.post<{ Body: { token?: string; message?: string; parcelId?: string } }>("/api/regions/notices", async (request, reply) => {
    const { token, message, parcelId = null } = request.body;

    if (!token || !message) {
      return reply.code(400).send({ error: "token and message are required" });
    }

    const notice = await createRegionNotice(token, message, parcelId);

    if (!notice) {
      return reply.code(403).send({ error: "failed to create notice" });
    }

    return reply.send({ notice });
  });

  app.delete<{ Body: { token?: string; noticeId?: string } }>("/api/regions/notices", async (request, reply) => {
    const { token, noticeId } = request.body;

    if (!token || !noticeId) {
      return reply.code(400).send({ error: "token and noticeId are required" });
    }

    const deleted = await deleteRegionNotice(token, noticeId);

    if (!deleted) {
      return reply.code(404).send({ error: "notice not found" });
    }

    return reply.send({ ok: true });
  });
}
