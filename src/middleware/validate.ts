import { FastifyRequest, FastifyReply } from "fastify";

/**
 * Returns a Fastify preHandler hook that verifies every field listed in
 * `fields` is present (not `undefined`) on `request.body`.
 *
 * Sends a 400 response for the first missing field encountered.
 */
export function requireFields(...fields: string[]) {
  return async (request: FastifyRequest, reply: FastifyReply) => {
    const body = request.body as Record<string, unknown> | undefined;

    for (const field of fields) {
      if (body?.[field] === undefined) {
        reply.status(400).send({ error: `Missing required field: ${field}` });
        return;
      }
    }
  };
}
