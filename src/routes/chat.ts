import { FastifyInstance } from "fastify";
import { getChatHistory } from "../world/store.js";

export default async function chatRoutes(app: FastifyInstance) {
  app.get<{ Params: { regionId: string } }>("/api/regions/:regionId/chat-history", async (request, reply) => {
    const messages = getChatHistory(request.params.regionId);
    return reply.send({ messages });
  });
}
