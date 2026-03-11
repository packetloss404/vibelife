import { FastifyInstance } from "fastify";
import { listRadioStations } from "../world/store.js";

export default async function radioRoutes(app: FastifyInstance) {
  app.get("/api/radio/stations", async () => ({
    stations: listRadioStations()
  }));
}
