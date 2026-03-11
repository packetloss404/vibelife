import { FastifyRequest, FastifyReply } from "fastify";
import { getSession, type Session } from "../world/store.js";

declare module "fastify" {
  interface FastifyRequest {
    authToken?: string;
    session?: Session;
  }
}

export function getRequestToken(request: FastifyRequest): string | undefined {
  const body = request.body as Record<string, unknown> | undefined;
  const query = request.query as Record<string, unknown> | undefined;
  const header = request.headers.authorization;
  const bearerToken = typeof header === "string" && header.startsWith("Bearer ")
    ? header.slice("Bearer ".length).trim()
    : undefined;
  const token = bearerToken ?? body?.token ?? query?.token;

  return typeof token === "string" && token.length > 0 ? token : undefined;
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
  const token = getRequestToken(request);

  if (!token) {
    reply.status(401).send({ error: "token is required" });
    return;
  }

  const session = getSession(token);

  if (!session) {
    reply.status(401).send({ error: "invalid session" });
    return;
  }

  request.authToken = token;
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
    reply.status(403).send({ error: "admin access required" });
    return;
  }
}
