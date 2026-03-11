import type { FastifyInstance } from "fastify";
import { getSession } from "../world/store.js";
import { broadcastRegion, nextRegionSequence } from "../world/region.js";
import {
  adoptPet,
  listPets,
  getActivePet,
  summonPet,
  dismissPet,
  feedPet,
  playWithPet,
  petPet,
  renamePet,
  customizePet,
  performTrick,
  getPetStates,
  type PetSpecies,
  type PetTrick,
  type PetAccessory
} from "../world/pet-service.js";

export default async function petRoutes(app: FastifyInstance) {
  // POST /api/pets/adopt
  app.post<{ Body: { token?: string; name?: string; species?: string } }>(
    "/api/pets/adopt",
    async (request, reply) => {
      const { token, name, species } = request.body;

      if (!token || !name || !species) {
        return reply.code(400).send({ error: "token, name, and species are required" });
      }

      const pet = adoptPet(token, name, species as PetSpecies);

      if (!pet) {
        return reply.code(403).send({ error: "failed to adopt pet" });
      }

      return reply.send({ pet });
    }
  );

  // GET /api/pets
  app.get<{ Querystring: { token?: string } }>(
    "/api/pets",
    async (request, reply) => {
      const token = request.query.token;

      if (!token) {
        return reply.code(400).send({ error: "token is required" });
      }

      const pets = listPets(token);
      return reply.send({ pets });
    }
  );

  // GET /api/pets/active
  app.get<{ Querystring: { token?: string } }>(
    "/api/pets/active",
    async (request, reply) => {
      const token = request.query.token;

      if (!token) {
        return reply.code(400).send({ error: "token is required" });
      }

      const result = getActivePet(token);
      return reply.send({ active: result ?? null });
    }
  );

  // POST /api/pets/:id/summon
  app.post<{ Params: { id: string }; Body: { token?: string } }>(
    "/api/pets/:id/summon",
    async (request, reply) => {
      const { token } = request.body;

      if (!token) {
        return reply.code(400).send({ error: "token is required" });
      }

      const result = summonPet(token, request.params.id);

      if (!result) {
        return reply.code(404).send({ error: "pet not found or not owned" });
      }

      const session = getSession(token);
      if (session) {
        broadcastRegion(session.regionId, {
          type: "pet:summoned",
          sequence: nextRegionSequence(session.regionId),
          pet: result.pet,
          state: result.state
        } as any);
      }

      return reply.send({ pet: result.pet, state: result.state });
    }
  );

  // POST /api/pets/:id/dismiss
  app.post<{ Params: { id: string }; Body: { token?: string } }>(
    "/api/pets/:id/dismiss",
    async (request, reply) => {
      const { token } = request.body;

      if (!token) {
        return reply.code(400).send({ error: "token is required" });
      }

      const result = dismissPet(token);

      if (!result) {
        return reply.code(404).send({ error: "no active pet to dismiss" });
      }

      broadcastRegion(result.regionId, {
        type: "pet:dismissed",
        sequence: nextRegionSequence(result.regionId),
        petId: result.petId
      } as any);

      return reply.send({ ok: true, petId: result.petId });
    }
  );

  // POST /api/pets/:id/feed
  app.post<{ Params: { id: string }; Body: { token?: string } }>(
    "/api/pets/:id/feed",
    async (request, reply) => {
      const { token } = request.body;

      if (!token) {
        return reply.code(400).send({ error: "token is required" });
      }

      const result = feedPet(token, request.params.id);

      if (!result) {
        return reply.code(404).send({ error: "pet not found or not owned" });
      }

      return reply.send({ pet: result.pet, message: result.message });
    }
  );

  // POST /api/pets/:id/play
  app.post<{ Params: { id: string }; Body: { token?: string } }>(
    "/api/pets/:id/play",
    async (request, reply) => {
      const { token } = request.body;

      if (!token) {
        return reply.code(400).send({ error: "token is required" });
      }

      const result = playWithPet(token, request.params.id);

      if (!result) {
        return reply.code(404).send({ error: "pet not found or not owned" });
      }

      return reply.send({ pet: result.pet, message: result.message, learnedTrick: result.learnedTrick ?? null });
    }
  );

  // POST /api/pets/:id/pet
  app.post<{ Params: { id: string }; Body: { token?: string } }>(
    "/api/pets/:id/pet",
    async (request, reply) => {
      const { token } = request.body;

      if (!token) {
        return reply.code(400).send({ error: "token is required" });
      }

      const result = petPet(token, request.params.id);

      if (!result) {
        return reply.code(404).send({ error: "pet not found or not owned" });
      }

      return reply.send({ pet: result.pet, message: result.message });
    }
  );

  // POST /api/pets/:id/trick
  app.post<{ Params: { id: string }; Body: { token?: string; trick?: string } }>(
    "/api/pets/:id/trick",
    async (request, reply) => {
      const { token, trick } = request.body;

      if (!token || !trick) {
        return reply.code(400).send({ error: "token and trick are required" });
      }

      const result = performTrick(token, request.params.id, trick as PetTrick);

      if (!result) {
        return reply.code(404).send({ error: "pet not found or not owned" });
      }

      const session = getSession(token);
      if (session && result.state) {
        broadcastRegion(session.regionId, {
          type: "pet:trick",
          sequence: nextRegionSequence(session.regionId),
          petId: request.params.id,
          trick,
          petName: result.pet.name
        } as any);
      }

      return reply.send({ pet: result.pet, message: result.message });
    }
  );

  // PATCH /api/pets/:id — rename or customize
  app.patch<{
    Params: { id: string };
    Body: { token?: string; name?: string; color?: string; accentColor?: string; accessory?: string };
  }>(
    "/api/pets/:id",
    async (request, reply) => {
      const { token, name, color, accentColor, accessory } = request.body;

      if (!token) {
        return reply.code(400).send({ error: "token is required" });
      }

      let pet;

      if (name !== undefined) {
        pet = renamePet(token, request.params.id, name);
        if (!pet) {
          return reply.code(404).send({ error: "pet not found or invalid name" });
        }
      }

      if (color !== undefined || accentColor !== undefined || accessory !== undefined) {
        pet = customizePet(
          token,
          request.params.id,
          color,
          accentColor,
          accessory as PetAccessory | undefined
        );
        if (!pet) {
          return reply.code(404).send({ error: "pet not found or not owned" });
        }
      }

      if (!pet) {
        return reply.code(400).send({ error: "no updates provided" });
      }

      const session = getSession(token);
      if (session) {
        const activePetData = getActivePet(token);
        if (activePetData && activePetData.pet.id === request.params.id) {
          broadcastRegion(session.regionId, {
            type: "pet:state_updated",
            sequence: nextRegionSequence(session.regionId),
            pet: activePetData.pet,
            state: activePetData.state
          } as any);
        }
      }

      return reply.send({ pet });
    }
  );

  // GET /api/pets/region/:regionId
  app.get<{ Params: { regionId: string } }>(
    "/api/pets/region/:regionId",
    async (request, reply) => {
      const results = getPetStates(request.params.regionId);
      return reply.send({ pets: results });
    }
  );
}
