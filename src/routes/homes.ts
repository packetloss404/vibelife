import type { FastifyInstance } from "fastify";
import {
  setHome,
  getHome,
  clearHome,
  teleportHome,
  setHomePrivacy,
  type HomePrivacy
} from "../world/home-service.js";
import { getSession, teleportToRegion } from "../world/store.js";

export async function homeRoutes(app: FastifyInstance) {
  app.post<{ Body: { token?: string; parcelId?: string } }>("/api/homes/set", async (request, reply) => {
    const { token, parcelId } = request.body;

    if (!token || !parcelId) {
      return reply.code(400).send({ error: "token and parcelId are required" });
    }

    const home = await setHome(token, parcelId);

    if (!home) {
      return reply.code(403).send({ error: "unable to set home — you must own the parcel" });
    }

    return reply.send({ home });
  });

  app.get<{ Querystring: { token?: string } }>("/api/homes", async (request, reply) => {
    const token = request.query.token;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const home = getHome(token);
    return reply.send({ home: home ?? null });
  });

  app.post<{ Body: { token?: string } }>("/api/homes/teleport", async (request, reply) => {
    const { token } = request.body;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const homeInfo = await teleportHome(token);

    if (!homeInfo) {
      return reply.code(404).send({ error: "no home set or home parcel not found" });
    }

    const { parcel, regionId } = homeInfo;
    const centerX = (parcel.minX + parcel.maxX) / 2;
    const centerZ = (parcel.minZ + parcel.maxZ) / 2;

    const session = getSession(token);
    if (!session) {
      return reply.code(403).send({ error: "invalid session" });
    }

    // If already in the same region, just return coordinates
    if (session.regionId === regionId) {
      return reply.send({
        teleported: true,
        regionId,
        x: centerX,
        y: 0,
        z: centerZ
      });
    }

    // Cross-region teleport
    const result = await teleportToRegion(token, regionId, centerX, 0, centerZ);

    if (!result.ok) {
      return reply.code(403).send({ error: result.reason });
    }

    return reply.send({
      teleported: true,
      regionId,
      x: centerX,
      y: 0,
      z: centerZ,
      session: result.session,
      avatar: result.avatar
    });
  });

  app.post<{ Body: { token?: string; privacy?: string } }>("/api/homes/privacy", async (request, reply) => {
    const { token, privacy } = request.body;

    if (!token || !privacy) {
      return reply.code(400).send({ error: "token and privacy are required" });
    }

    if (!["public", "friends", "private"].includes(privacy)) {
      return reply.code(400).send({ error: "privacy must be public, friends, or private" });
    }

    const home = setHomePrivacy(token, privacy as HomePrivacy);

    if (!home) {
      return reply.code(404).send({ error: "no home set" });
    }

    return reply.send({ home });
  });

  app.delete<{ Body: { token?: string } }>("/api/homes", async (request, reply) => {
    const { token } = request.body;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const cleared = clearHome(token);

    if (!cleared) {
      return reply.code(404).send({ error: "no home to clear" });
    }

    return reply.send({ ok: true });
  });
}
