import { FastifyInstance } from "fastify";
import { getEmoteList } from "../world/store.js";

export default async function emoteRoutes(app: FastifyInstance) {
  app.get("/api/emotes", async () => ({
    emotes: getEmoteList()
  }));
}
