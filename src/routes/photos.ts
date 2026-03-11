import type { FastifyInstance } from "fastify";
import {
  takePhoto,
  listPhotos,
  getPhoto,
  deletePhoto,
  likePhoto,
  commentOnPhoto,
  getPhotoFeed,
  getPlayerGallery,
  getFeaturedPhotos,
  type PhotoFilter,
} from "../world/photo-service.js";
import { getSession } from "../world/store.js";

const VALID_FILTERS: PhotoFilter[] = [
  "none",
  "vintage",
  "noir",
  "warm",
  "cool",
  "dreamy",
  "pixel",
  "posterize",
];

export default async function photosRoutes(app: FastifyInstance) {
  // POST /api/photos — take/upload photo
  app.post<{
    Body: {
      token?: string;
      regionId?: string;
      title?: string;
      thumbnailData?: string;
      filter?: string;
      position?: { x: number; y: number; z: number };
      cameraRotation?: { x: number; y: number };
    };
  }>("/api/photos", async (request, reply) => {
    const { token, regionId, title, thumbnailData, filter, position, cameraRotation } =
      request.body;

    if (!token || !regionId || !title || !thumbnailData) {
      return reply
        .code(400)
        .send({ error: "token, regionId, title, and thumbnailData are required" });
    }

    const photoFilter: PhotoFilter = VALID_FILTERS.includes(filter as PhotoFilter)
      ? (filter as PhotoFilter)
      : "none";

    const photo = takePhoto(
      token,
      regionId,
      title,
      thumbnailData,
      photoFilter,
      position ?? { x: 0, y: 0, z: 0 },
      cameraRotation ?? { x: 0, y: 0 }
    );

    if (!photo) {
      return reply.code(403).send({ error: "failed to take photo" });
    }

    return reply.send({ photo });
  });

  // GET /api/photos?accountId=&regionId=&limit=&offset= — list photos
  app.get<{
    Querystring: {
      accountId?: string;
      regionId?: string;
      limit?: string;
      offset?: string;
    };
  }>("/api/photos", async (request, reply) => {
    const { accountId, regionId } = request.query;
    const limit = Math.max(1, Math.min(100, Number(request.query.limit ?? 20)));
    const offset = Math.max(0, Number(request.query.offset ?? 0));

    const photos = listPhotos(accountId, regionId, limit, offset);
    return reply.send({ photos });
  });

  // GET /api/photos/feed?limit= — global feed
  app.get<{
    Querystring: { limit?: string };
  }>("/api/photos/feed", async (request, reply) => {
    const limit = Math.max(1, Math.min(100, Number(request.query.limit ?? 20)));
    const photos = getPhotoFeed(limit);
    return reply.send({ photos });
  });

  // GET /api/photos/featured?limit= — featured/most liked
  app.get<{
    Querystring: { limit?: string };
  }>("/api/photos/featured", async (request, reply) => {
    const limit = Math.max(1, Math.min(50, Number(request.query.limit ?? 10)));
    const photos = getFeaturedPhotos(limit);
    return reply.send({ photos });
  });

  // GET /api/photos/gallery/:accountId — player gallery
  app.get<{
    Params: { accountId: string };
    Querystring: { limit?: string; offset?: string };
  }>("/api/photos/gallery/:accountId", async (request, reply) => {
    const limit = Math.max(1, Math.min(100, Number(request.query.limit ?? 20)));
    const offset = Math.max(0, Number(request.query.offset ?? 0));
    const photos = getPlayerGallery(request.params.accountId, limit, offset);
    return reply.send({ photos });
  });

  // GET /api/photos/:id — get single photo
  app.get<{
    Params: { id: string };
  }>("/api/photos/:id", async (request, reply) => {
    const photo = getPhoto(request.params.id);

    if (!photo) {
      return reply.code(404).send({ error: "photo not found" });
    }

    return reply.send({ photo });
  });

  // DELETE /api/photos/:id — delete photo
  app.delete<{
    Params: { id: string };
    Body: { token?: string };
  }>("/api/photos/:id", async (request, reply) => {
    const token = request.body.token;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const deleted = deletePhoto(token, request.params.id);

    if (!deleted) {
      return reply.code(404).send({ error: "photo not found or not owned" });
    }

    return reply.send({ ok: true });
  });

  // POST /api/photos/:id/like — toggle like
  app.post<{
    Params: { id: string };
    Body: { token?: string };
  }>("/api/photos/:id/like", async (request, reply) => {
    const token = request.body.token;

    if (!token) {
      return reply.code(400).send({ error: "token is required" });
    }

    const photo = likePhoto(token, request.params.id);

    if (!photo) {
      return reply.code(404).send({ error: "photo not found" });
    }

    return reply.send({ photo });
  });

  // POST /api/photos/:id/comment — add comment
  app.post<{
    Params: { id: string };
    Body: { token?: string; text?: string };
  }>("/api/photos/:id/comment", async (request, reply) => {
    const { token, text } = request.body;

    if (!token || !text) {
      return reply.code(400).send({ error: "token and text are required" });
    }

    const photo = commentOnPhoto(token, request.params.id, text);

    if (!photo) {
      return reply.code(404).send({ error: "photo not found" });
    }

    return reply.send({ photo });
  });
}
