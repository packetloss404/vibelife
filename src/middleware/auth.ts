import { FastifyRequest, FastifyReply } from "fastify";
import { getSession, type Session } from "../world/store.js";

declare module "fastify" {
  interface FastifyRequest {
    session?: Session;
  }
}

/**
 * Fastify preHandler hook that extracts a token from the request body or query
 * string, validates it against the session store, and attaches the resulting
 * Session to `request.session`.
 *
 * Sends a 401 response and short-circuits the request lifecycle when the token
 * is missing or invalid.
 */
export async function requireAuth(request: FastifyRequest, reply: FastifyReply) {
  const body = request.body as Record<string, unknown> | undefined;
  const query = request.query as Record<string, unknown> | undefined;
  const token = (body?.token ?? query?.token) as string | undefined;

  if (!token) {
    reply.status(401).send({ error: "Token required" });
    return;
  }

  const session = getSession(token);

  if (!session) {
    reply.status(401).send({ error: "Invalid session" });
    return;
  }

  request.session = session;
}

/**
 * Stricter variant of `requireAuth` that additionally requires the
 * authenticated session to have the `"admin"` role.
 *
 * Sends a 403 response when the session exists but is not an admin.
 */
export async function requireAdmin(request: FastifyRequest, reply: FastifyReply) {
  await requireAuth(request, reply);

  if (reply.sent) return;

  if (request.session?.role !== "admin") {
    reply.status(403).send({ error: "Admin access required" });
    return;
  }
}
