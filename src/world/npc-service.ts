// NPC Service — Feature 19: AI NPCs for VibeLife
//
// INTEGRATION NOTES (do NOT auto-apply):
// - server.ts: import and register the npcs route plugin:
//     import npcRoutes from "./routes/npcs.js";
//     await app.register(npcRoutes);
//   Then start the NPC tick loop after initializeWorldStore():
//     import { startNpcTickLoop } from "./world/npc-service.js";
//     startNpcTickLoop();
//
// - store.ts: add the following re-exports if barrel-exporting:
//     export { ... } from "./npc-service.js";

import { randomUUID } from "node:crypto";
import { getSession, listRegions, getRegionPopulation, type Session, type AvatarState } from "./store.js";
import { broadcastRegion, nextRegionSequence } from "./region.js";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export type NpcType = "ambient" | "shopkeeper" | "quest-giver" | "tour-guide" | "enemy";

export type BehaviorState =
  | "idle"
  | "patrol"
  | "interact"
  | "converse"
  | "script";

export type DialogueOption = {
  id: string;
  text: string;
  nextNodeId: string | null;
  action?: DialogueAction | null;
};

export type DialogueAction = {
  type: "give_quest" | "complete_quest" | "give_currency" | "give_item" | "teleport" | "open_shop";
  payload: Record<string, unknown>;
};

export type DialogueNode = {
  id: string;
  npcText: string;
  options: DialogueOption[];
};

export type DialogueTree = {
  startNodeId: string;
  nodes: Map<string, DialogueNode>;
};

export type QuestObjectiveType = "visit_region" | "talk_to_npc" | "collect_item" | "spend_currency" | "explore_parcels" | "chat_count";

export type QuestObjective = {
  id: string;
  description: string;
  type: QuestObjectiveType;
  target: string;
  required: number;
  current: number;
};

export type QuestReward = {
  type: "currency" | "item" | "title" | "experience";
  amount: number;
  itemId?: string;
  description: string;
};

export type QuestFrequency = "daily" | "weekly" | "one-time";

export type Quest = {
  id: string;
  npcId: string;
  title: string;
  description: string;
  frequency: QuestFrequency;
  objectives: QuestObjective[];
  rewards: QuestReward[];
  expiresAt: string | null;
  createdAt: string;
};

export type PlayerQuestState = {
  questId: string;
  accountId: string;
  objectives: QuestObjective[];
  status: "active" | "completed" | "expired";
  startedAt: string;
  completedAt: string | null;
};

export type NpcScript = {
  id: string;
  npcId: string;
  name: string;
  code: string;
  enabled: boolean;
  createdAt: string;
};

export type NpcRecord = {
  id: string;
  regionId: string;
  displayName: string;
  npcType: NpcType;
  appearance: NpcAppearance;
  spawnX: number;
  spawnY: number;
  spawnZ: number;
  x: number;
  y: number;
  z: number;
  behaviorState: BehaviorState;
  patrolRadius: number;
  interactRadius: number;
  dialogue: DialogueTree | null;
  quests: Quest[];
  scripts: NpcScript[];
  createdAt: string;
  updatedAt: string;
};

export type NpcAppearance = {
  bodyColor: string;
  accentColor: string;
  headColor: string;
  hairColor: string;
  outfit: string;
  accessory: string;
  nameTagColor: string;
};

// ---------------------------------------------------------------------------
// In-memory NPC state
// ---------------------------------------------------------------------------

const npcsByRegion = new Map<string, Map<string, NpcRecord>>();
const playerQuests = new Map<string, PlayerQuestState[]>(); // accountId -> quests
const activeConversations = new Map<string, { npcId: string; currentNodeId: string }>(); // accountId -> conv
const npcScriptsById = new Map<string, NpcScript>();

let tickInterval: ReturnType<typeof setInterval> | null = null;
const NPC_TICK_MS = 2000;

// ---------------------------------------------------------------------------
// Default NPC templates
// ---------------------------------------------------------------------------

const DEFAULT_APPEARANCES: Record<NpcType, NpcAppearance> = {
  ambient: {
    bodyColor: "#7ec8a0",
    accentColor: "#5da87a",
    headColor: "#f5deb3",
    hairColor: "#8b6c42",
    outfit: "tunic",
    accessory: "none",
    nameTagColor: "#aaddaa"
  },
  shopkeeper: {
    bodyColor: "#d4a853",
    accentColor: "#b8892e",
    headColor: "#f5deb3",
    hairColor: "#4a3728",
    outfit: "apron",
    accessory: "monocle",
    nameTagColor: "#ffd700"
  },
  "quest-giver": {
    bodyColor: "#6b8cce",
    accentColor: "#4a6fb5",
    headColor: "#f5deb3",
    hairColor: "#2c1810",
    outfit: "robe",
    accessory: "scroll",
    nameTagColor: "#88aaff"
  },
  "tour-guide": {
    bodyColor: "#e07850",
    accentColor: "#c45830",
    headColor: "#f5deb3",
    hairColor: "#d4a853",
    outfit: "vest",
    accessory: "flag",
    nameTagColor: "#ff8866"
  },
  enemy: {
    bodyColor: "#880000",
    accentColor: "#440000",
    headColor: "#aa2222",
    hairColor: "#220000",
    outfit: "armor",
    accessory: "none",
    nameTagColor: "#ff0000"
  }
};

// ---------------------------------------------------------------------------
// Dialogue templates
// ---------------------------------------------------------------------------

function buildAmbientDialogue(name: string): DialogueTree {
  const greetId = randomUUID();
  const weatherId = randomUUID();
  const tipsId = randomUUID();
  const farewellId = randomUUID();

  const nodes = new Map<string, DialogueNode>();

  nodes.set(greetId, {
    id: greetId,
    npcText: `Hey there, traveler! I'm ${name}. Beautiful day in the region, isn't it?`,
    options: [
      { id: randomUUID(), text: "What's the weather like around here?", nextNodeId: weatherId },
      { id: randomUUID(), text: "Any tips for a newcomer?", nextNodeId: tipsId },
      { id: randomUUID(), text: "Just passing through. See you around!", nextNodeId: farewellId }
    ]
  });

  nodes.set(weatherId, {
    id: weatherId,
    npcText: "Oh, the weather shifts with the region's mood. Some days it's sunny and calm, other days you can feel the energy crackling. I love it here.",
    options: [
      { id: randomUUID(), text: "Any other tips?", nextNodeId: tipsId },
      { id: randomUUID(), text: "Thanks! Goodbye.", nextNodeId: farewellId }
    ]
  });

  nodes.set(tipsId, {
    id: tipsId,
    npcText: "Sure! Explore the parcels nearby, claim one if you find an empty spot, and try building something. Also, check the market for interesting items. The community here is really friendly.",
    options: [
      { id: randomUUID(), text: "Good to know. Bye for now!", nextNodeId: farewellId }
    ]
  });

  nodes.set(farewellId, {
    id: farewellId,
    npcText: "Safe travels, friend! Come back anytime.",
    options: []
  });

  return { startNodeId: greetId, nodes };
}

function buildShopkeeperDialogue(name: string): DialogueTree {
  const greetId = randomUUID();
  const browseId = randomUUID();
  const sellId = randomUUID();
  const dealsId = randomUUID();
  const farewellId = randomUUID();

  const nodes = new Map<string, DialogueNode>();

  nodes.set(greetId, {
    id: greetId,
    npcText: `Welcome to ${name}'s shop! I've got the finest wares in the region. What can I do for you today?`,
    options: [
      { id: randomUUID(), text: "Let me browse your wares.", nextNodeId: browseId, action: { type: "open_shop", payload: {} } },
      { id: randomUUID(), text: "I'd like to sell something.", nextNodeId: sellId },
      { id: randomUUID(), text: "Any special deals today?", nextNodeId: dealsId },
      { id: randomUUID(), text: "Just looking. Goodbye!", nextNodeId: farewellId }
    ]
  });

  nodes.set(browseId, {
    id: browseId,
    npcText: "Take your time! I've organized everything by category. The new arrivals are on the left — some real gems in there. Let me know if anything catches your eye.",
    options: [
      { id: randomUUID(), text: "Any deals?", nextNodeId: dealsId },
      { id: randomUUID(), text: "Thanks, I'll think about it.", nextNodeId: farewellId }
    ]
  });

  nodes.set(sellId, {
    id: sellId,
    npcText: "I'm always buying interesting items! Show me what you've got and I'll give you a fair price. Quality craftsmanship gets a premium, of course.",
    options: [
      { id: randomUUID(), text: "Maybe later. What else do you have?", nextNodeId: browseId },
      { id: randomUUID(), text: "Alright, thanks!", nextNodeId: farewellId }
    ]
  });

  nodes.set(dealsId, {
    id: dealsId,
    npcText: "As a matter of fact, yes! I'm running a special on building materials — perfect for anyone who just claimed a parcel. And if you complete a quest for one of the locals, I might throw in an extra discount.",
    options: [
      { id: randomUUID(), text: "I'll check out the wares.", nextNodeId: browseId, action: { type: "open_shop", payload: {} } },
      { id: randomUUID(), text: "Good to know. Bye!", nextNodeId: farewellId }
    ]
  });

  nodes.set(farewellId, {
    id: farewellId,
    npcText: "Come back soon! I restock regularly, so there's always something new.",
    options: []
  });

  return { startNodeId: greetId, nodes };
}

function buildQuestGiverDialogue(name: string, quests: Quest[]): DialogueTree {
  const greetId = randomUUID();
  const questListId = randomUUID();
  const loreId = randomUUID();
  const farewellId = randomUUID();

  const nodes = new Map<string, DialogueNode>();

  const questNames = quests.length > 0
    ? quests.map((q) => `"${q.title}"`).join(", ")
    : "nothing right now, but check back soon";

  nodes.set(greetId, {
    id: greetId,
    npcText: `Greetings, adventurer! I'm ${name}, keeper of quests and chronicles. I have challenges for those brave enough to accept them.`,
    options: [
      { id: randomUUID(), text: "What quests do you have?", nextNodeId: questListId },
      { id: randomUUID(), text: "Tell me about this region's history.", nextNodeId: loreId },
      { id: randomUUID(), text: "Not right now. Farewell!", nextNodeId: farewellId }
    ]
  });

  nodes.set(questListId, {
    id: questListId,
    npcText: `Currently available: ${questNames}. Each quest has its own rewards — complete them before they expire! Want to take one on?`,
    options: (quests.map((q): DialogueOption => ({
      id: randomUUID(),
      text: `Tell me about "${q.title}"`,
      nextNodeId: (() => {
        const detailId = randomUUID();
        nodes.set(detailId, {
          id: detailId,
          npcText: `${q.description}\n\nReward: ${q.rewards.map((r) => r.description).join(", ")}`,
          options: [
            { id: randomUUID(), text: "I accept this quest!", nextNodeId: farewellId, action: { type: "give_quest" as const, payload: { questId: q.id } } },
            { id: randomUUID(), text: "Let me think about it.", nextNodeId: questListId }
          ]
        });
        return detailId;
      })()
    })) as DialogueOption[]).concat([
      { id: randomUUID(), text: "Maybe later.", nextNodeId: farewellId, action: null }
    ])
  });

  nodes.set(loreId, {
    id: loreId,
    npcText: "This region has a rich history. It was one of the first territories settled when VibeLife opened its doors. Many great builders have left their mark here, and new creators arrive every day. The parcels you see were carefully planned to give everyone a fair space to express themselves.",
    options: [
      { id: randomUUID(), text: "Fascinating. What quests do you have?", nextNodeId: questListId },
      { id: randomUUID(), text: "Thanks for the history lesson!", nextNodeId: farewellId }
    ]
  });

  nodes.set(farewellId, {
    id: farewellId,
    npcText: "May your journey be filled with wonder. Return when you've completed your tasks — or whenever you need new challenges!",
    options: []
  });

  return { startNodeId: greetId, nodes };
}

function buildTourGuideDialogue(name: string, regionName: string): DialogueTree {
  const greetId = randomUUID();
  const overviewId = randomUUID();
  const parcelsId = randomUUID();
  const buildingId = randomUUID();
  const socialId = randomUUID();
  const teleportId = randomUUID();
  const farewellId = randomUUID();

  const nodes = new Map<string, DialogueNode>();

  nodes.set(greetId, {
    id: greetId,
    npcText: `Welcome to ${regionName}! I'm ${name}, your friendly tour guide. I can show you the ropes if you're new, or just chat about what's happening in the area.`,
    options: [
      { id: randomUUID(), text: "Give me the grand tour!", nextNodeId: overviewId },
      { id: randomUUID(), text: "How do parcels work?", nextNodeId: parcelsId },
      { id: randomUUID(), text: "How do I build things?", nextNodeId: buildingId },
      { id: randomUUID(), text: "How do I meet people?", nextNodeId: socialId },
      { id: randomUUID(), text: "I'm all set, thanks!", nextNodeId: farewellId }
    ]
  });

  nodes.set(overviewId, {
    id: overviewId,
    npcText: `${regionName} is divided into parcels — plots of virtual land you can claim and build on. Walk around, chat with others, and make this world your own. You can open the build panel to place objects, and use the chat to talk to everyone nearby.`,
    options: [
      { id: randomUUID(), text: "Tell me about parcels.", nextNodeId: parcelsId },
      { id: randomUUID(), text: "How about building?", nextNodeId: buildingId },
      { id: randomUUID(), text: "What about teleporting?", nextNodeId: teleportId },
      { id: randomUUID(), text: "Thanks, that's enough for now!", nextNodeId: farewellId }
    ]
  });

  nodes.set(parcelsId, {
    id: parcelsId,
    npcText: "Parcels are sections of the region you can claim. Once you own a parcel, only you and your collaborators can build on it. Public parcels let anyone build — great for community projects. Look for unclaimed parcels to start your homestead!",
    options: [
      { id: randomUUID(), text: "How do I build?", nextNodeId: buildingId },
      { id: randomUUID(), text: "How do I meet people?", nextNodeId: socialId },
      { id: randomUUID(), text: "Got it, thanks!", nextNodeId: farewellId }
    ]
  });

  nodes.set(buildingId, {
    id: buildingId,
    npcText: "Open the build panel and select an asset from the dropdown. Click in the world to place it on your parcel. You can move, rotate, and scale objects with the gizmo tools. Try different combinations to create something unique!",
    options: [
      { id: randomUUID(), text: "What about teleporting?", nextNodeId: teleportId },
      { id: randomUUID(), text: "How do parcels work again?", nextNodeId: parcelsId },
      { id: randomUUID(), text: "Perfect, thanks!", nextNodeId: farewellId }
    ]
  });

  nodes.set(socialId, {
    id: socialId,
    npcText: "Use the chat panel on the right to talk to everyone in the region. You can add friends, join groups, and even send offline messages. The community is the heart of VibeLife — don't be shy!",
    options: [
      { id: randomUUID(), text: "How do I teleport?", nextNodeId: teleportId },
      { id: randomUUID(), text: "Sounds great, bye!", nextNodeId: farewellId }
    ]
  });

  nodes.set(teleportId, {
    id: teleportId,
    npcText: "You can save teleport points to quickly jump back to your favorite spots. Use the teleport menu to travel between regions. It's a big world out there — explore it all!",
    options: [
      { id: randomUUID(), text: "Back to the overview.", nextNodeId: overviewId },
      { id: randomUUID(), text: "Thanks for the tour!", nextNodeId: farewellId }
    ]
  });

  nodes.set(farewellId, {
    id: farewellId,
    npcText: "Have a wonderful time exploring! If you need help, just come find me. I'm always here. Happy building!",
    options: []
  });

  return { startNodeId: greetId, nodes };
}

// ---------------------------------------------------------------------------
// Default quest templates
// ---------------------------------------------------------------------------

function generateDailyQuests(npcId: string): Quest[] {
  const now = new Date();
  const tomorrow = new Date(now);
  tomorrow.setDate(tomorrow.getDate() + 1);
  tomorrow.setHours(0, 0, 0, 0);

  return [
    {
      id: randomUUID(),
      npcId,
      title: "Regional Explorer",
      description: "Visit 2 different regions today. Travel broadens the mind!",
      frequency: "daily",
      objectives: [{
        id: randomUUID(),
        description: "Visit regions",
        type: "visit_region",
        target: "any",
        required: 2,
        current: 0
      }],
      rewards: [
        { type: "currency", amount: 50, description: "50 VibeCoins" }
      ],
      expiresAt: tomorrow.toISOString(),
      createdAt: now.toISOString()
    },
    {
      id: randomUUID(),
      npcId,
      title: "Social Butterfly",
      description: "Send 5 chat messages in the region. Make some friends!",
      frequency: "daily",
      objectives: [{
        id: randomUUID(),
        description: "Send chat messages",
        type: "chat_count",
        target: "any",
        required: 5,
        current: 0
      }],
      rewards: [
        { type: "currency", amount: 25, description: "25 VibeCoins" }
      ],
      expiresAt: tomorrow.toISOString(),
      createdAt: now.toISOString()
    },
    {
      id: randomUUID(),
      npcId,
      title: "Parcel Scout",
      description: "Explore 3 different parcels in this region. See what others have built!",
      frequency: "daily",
      objectives: [{
        id: randomUUID(),
        description: "Explore parcels",
        type: "explore_parcels",
        target: "any",
        required: 3,
        current: 0
      }],
      rewards: [
        { type: "currency", amount: 35, description: "35 VibeCoins" },
        { type: "experience", amount: 10, description: "10 XP" }
      ],
      expiresAt: tomorrow.toISOString(),
      createdAt: now.toISOString()
    }
  ];
}

function generateWeeklyQuests(npcId: string): Quest[] {
  const now = new Date();
  const nextWeek = new Date(now);
  nextWeek.setDate(nextWeek.getDate() + 7);
  nextWeek.setHours(0, 0, 0, 0);

  return [
    {
      id: randomUUID(),
      npcId,
      title: "Master Builder",
      description: "A true builder leaves their mark. Show your creativity by placing objects in the world.",
      frequency: "weekly",
      objectives: [{
        id: randomUUID(),
        description: "Place objects in parcels",
        type: "collect_item",
        target: "build_object",
        required: 5,
        current: 0
      }],
      rewards: [
        { type: "currency", amount: 200, description: "200 VibeCoins" },
        { type: "title", amount: 1, description: "Title: Master Builder" }
      ],
      expiresAt: nextWeek.toISOString(),
      createdAt: now.toISOString()
    },
    {
      id: randomUUID(),
      npcId,
      title: "World Traveler",
      description: "Visit every region available in VibeLife this week.",
      frequency: "weekly",
      objectives: [{
        id: randomUUID(),
        description: "Visit all regions",
        type: "visit_region",
        target: "all",
        required: 3,
        current: 0
      }],
      rewards: [
        { type: "currency", amount: 150, description: "150 VibeCoins" },
        { type: "experience", amount: 50, description: "50 XP" }
      ],
      expiresAt: nextWeek.toISOString(),
      createdAt: now.toISOString()
    }
  ];
}

// ---------------------------------------------------------------------------
// Ambient NPC name pools
// ---------------------------------------------------------------------------

const AMBIENT_NAMES = [
  "Willow", "Jasper", "Fern", "Cobalt", "Sage", "Ember", "Pebble",
  "Basil", "Cedar", "Coral", "Dusk", "Flint", "Gale", "Hazel",
  "Indigo", "Ivy", "Jade", "Lark", "Maple", "Nova"
];

const SHOPKEEPER_NAMES = [
  "Merchant Talia", "Trader Bram", "Artisan Kira", "Vendor Enzo"
];

const QUEST_GIVER_NAMES = [
  "Oracle Mirin", "Sage Althor", "Chronicle Keeper Yael", "Wanderer Kael"
];

const TOUR_GUIDE_NAMES = [
  "Guide Rowan", "Pathfinder Nia", "Scout Theron", "Navigator Sol"
];

function pickRandom<T>(arr: T[]): T {
  return arr[Math.floor(Math.random() * arr.length)];
}

// ---------------------------------------------------------------------------
// NPC lifecycle
// ---------------------------------------------------------------------------

function getRegionNpcs(regionId: string): Map<string, NpcRecord> {
  let npcs = npcsByRegion.get(regionId);
  if (!npcs) {
    npcs = new Map();
    npcsByRegion.set(regionId, npcs);
  }
  return npcs;
}

export function listNpcsByRegion(regionId: string): NpcRecord[] {
  return Array.from(getRegionNpcs(regionId).values());
}

export function getNpc(npcId: string): NpcRecord | undefined {
  for (const npcs of Array.from(npcsByRegion.values())) {
    const npc = npcs.get(npcId);
    if (npc) return npc;
  }
  return undefined;
}

export function spawnNpc(
  regionId: string,
  displayName: string,
  npcType: NpcType,
  x: number,
  y: number,
  z: number,
  options?: {
    appearance?: Partial<NpcAppearance>;
    patrolRadius?: number;
    interactRadius?: number;
  }
): NpcRecord {
  const baseAppearance = DEFAULT_APPEARANCES[npcType];
  const appearance: NpcAppearance = {
    ...baseAppearance,
    ...(options?.appearance ?? {})
  };

  const quests: Quest[] = npcType === "quest-giver"
    ? [...generateDailyQuests(randomUUID()), ...generateWeeklyQuests(randomUUID())]
    : [];

  const id = randomUUID();
  // Fix quest npcId references
  for (const q of quests) {
    q.npcId = id;
  }

  let dialogue: DialogueTree | null = null;
  switch (npcType) {
    case "ambient":
      dialogue = buildAmbientDialogue(displayName);
      break;
    case "shopkeeper":
      dialogue = buildShopkeeperDialogue(displayName);
      break;
    case "quest-giver":
      dialogue = buildQuestGiverDialogue(displayName, quests);
      break;
    case "tour-guide": {
      const regions = listRegions();
      const regionName = regions.find((r) => r.id === regionId)?.name ?? "this region";
      dialogue = buildTourGuideDialogue(displayName, regionName);
      break;
    }
  }

  const npc: NpcRecord = {
    id,
    regionId,
    displayName,
    npcType,
    appearance,
    spawnX: x,
    spawnY: y,
    spawnZ: z,
    x,
    y,
    z,
    behaviorState: "idle",
    patrolRadius: options?.patrolRadius ?? (npcType === "ambient" ? 8 : 2),
    interactRadius: options?.interactRadius ?? 4,
    dialogue,
    quests,
    scripts: [],
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString()
  };

  getRegionNpcs(regionId).set(id, npc);
  return npc;
}

export function despawnNpc(npcId: string): boolean {
  for (const [regionId, npcs] of Array.from(npcsByRegion.entries())) {
    if (npcs.delete(npcId)) {
      broadcastRegion(regionId, {
        type: "chat",
        sequence: nextRegionSequence(regionId),
        avatarId: "system",
        displayName: "System",
        message: `NPC has departed the region.`,
        createdAt: new Date().toISOString()
      });
      return true;
    }
  }
  return false;
}

// ---------------------------------------------------------------------------
// NPC behavior tick
// ---------------------------------------------------------------------------

function clampToRegion(value: number): number {
  return Math.max(-28, Math.min(28, value));
}

function distanceSq(ax: number, az: number, bx: number, bz: number): number {
  return (ax - bx) ** 2 + (az - bz) ** 2;
}

function tickNpc(npc: NpcRecord, nearbyAvatars: AvatarState[]): void {
  const closestAvatar = nearbyAvatars.reduce<{ avatar: AvatarState | null; dist: number }>(
    (best, av) => {
      const d = distanceSq(npc.x, npc.z, av.x, av.z);
      return d < best.dist ? { avatar: av, dist: d } : best;
    },
    { avatar: null, dist: Infinity }
  );

  const interactRadiusSq = npc.interactRadius ** 2;
  const hasNearbyAvatar = closestAvatar.avatar !== null && closestAvatar.dist <= interactRadiusSq;

  // Run any custom scripts first
  if (npc.scripts.some((s) => s.enabled)) {
    tickNpcScript(npc, closestAvatar.avatar, hasNearbyAvatar);
    return;
  }

  switch (npc.behaviorState) {
    case "idle":
      tickIdle(npc, hasNearbyAvatar);
      break;
    case "patrol":
      tickPatrol(npc, hasNearbyAvatar);
      break;
    case "interact":
      tickInteract(npc, hasNearbyAvatar);
      break;
    case "converse":
      tickConverse(npc, hasNearbyAvatar);
      break;
    case "script":
      // Handled by custom script engine
      break;
  }
}

function tickIdle(npc: NpcRecord, hasNearbyAvatar: boolean): void {
  if (hasNearbyAvatar && npc.npcType !== "ambient") {
    npc.behaviorState = "interact";
    return;
  }

  // Randomly transition to patrol (ambient and tour-guide wander more)
  const patrolChance = npc.npcType === "ambient" ? 0.3 : npc.npcType === "tour-guide" ? 0.2 : 0.05;
  if (Math.random() < patrolChance) {
    npc.behaviorState = "patrol";
  }
}

function tickPatrol(npc: NpcRecord, hasNearbyAvatar: boolean): void {
  if (hasNearbyAvatar && npc.npcType !== "ambient") {
    npc.behaviorState = "interact";
    return;
  }

  // Move toward a random point within patrol radius of spawn
  const angle = Math.random() * Math.PI * 2;
  const distance = Math.random() * npc.patrolRadius * 0.3;
  const targetX = npc.spawnX + Math.cos(angle) * distance;
  const targetZ = npc.spawnZ + Math.sin(angle) * distance;

  // Smooth movement toward target
  const dx = targetX - npc.x;
  const dz = targetZ - npc.z;
  const moveSpeed = 0.5;
  const len = Math.sqrt(dx * dx + dz * dz);

  if (len > 0.1) {
    npc.x = clampToRegion(npc.x + (dx / len) * Math.min(moveSpeed, len));
    npc.z = clampToRegion(npc.z + (dz / len) * Math.min(moveSpeed, len));
  }

  npc.updatedAt = new Date().toISOString();

  // Chance to go back to idle
  if (Math.random() < 0.15) {
    npc.behaviorState = "idle";
  }
}

function tickInteract(npc: NpcRecord, hasNearbyAvatar: boolean): void {
  if (!hasNearbyAvatar) {
    npc.behaviorState = "idle";
    return;
  }

  // Stay in interact mode; NPC faces the player and waits for dialogue
  // Slight idle sway
  npc.x += (Math.random() - 0.5) * 0.05;
  npc.z += (Math.random() - 0.5) * 0.05;
  npc.updatedAt = new Date().toISOString();
}

function tickConverse(npc: NpcRecord, hasNearbyAvatar: boolean): void {
  if (!hasNearbyAvatar) {
    npc.behaviorState = "idle";
  }
  // Conversation is driven by player interaction, NPC stays still
}

function tickNpcScript(npc: NpcRecord, _closestAvatar: AvatarState | null, _hasNearby: boolean): void {
  // Script-driven behavior: evaluate simple movement commands
  for (const script of npc.scripts) {
    if (!script.enabled) continue;

    try {
      const commands = JSON.parse(script.code) as ScriptCommand[];
      for (const cmd of commands) {
        executeScriptCommand(npc, cmd);
      }
    } catch {
      // Invalid script JSON — skip silently
    }
  }
}

type ScriptCommand =
  | { action: "move_to"; x: number; z: number; speed?: number }
  | { action: "say"; message: string }
  | { action: "wait"; ticks: number }
  | { action: "patrol_radius"; radius: number }
  | { action: "set_behavior"; behavior: BehaviorState }
  | { action: "emote"; emote: string };

const scriptWaitCounters = new Map<string, number>();

function executeScriptCommand(npc: NpcRecord, cmd: ScriptCommand): void {
  switch (cmd.action) {
    case "move_to": {
      const speed = cmd.speed ?? 0.5;
      const dx = cmd.x - npc.x;
      const dz = cmd.z - npc.z;
      const len = Math.sqrt(dx * dx + dz * dz);
      if (len > 0.1) {
        npc.x = clampToRegion(npc.x + (dx / len) * Math.min(speed, len));
        npc.z = clampToRegion(npc.z + (dz / len) * Math.min(speed, len));
        npc.updatedAt = new Date().toISOString();
      }
      break;
    }
    case "say": {
      broadcastRegion(npc.regionId, {
        type: "chat",
        sequence: nextRegionSequence(npc.regionId),
        avatarId: `npc:${npc.id}`,
        displayName: npc.displayName,
        message: cmd.message.slice(0, 180),
        createdAt: new Date().toISOString()
      });
      break;
    }
    case "wait": {
      const key = `${npc.id}:wait`;
      const counter = scriptWaitCounters.get(key) ?? 0;
      if (counter < cmd.ticks) {
        scriptWaitCounters.set(key, counter + 1);
        return;
      }
      scriptWaitCounters.delete(key);
      break;
    }
    case "patrol_radius":
      npc.patrolRadius = Math.max(1, Math.min(20, cmd.radius));
      break;
    case "set_behavior":
      npc.behaviorState = cmd.behavior;
      break;
    case "emote": {
      broadcastRegion(npc.regionId, {
        type: "chat",
        sequence: nextRegionSequence(npc.regionId),
        avatarId: `npc:${npc.id}`,
        displayName: npc.displayName,
        message: `* ${npc.displayName} ${cmd.emote} *`,
        createdAt: new Date().toISOString()
      });
      break;
    }
  }
}

// ---------------------------------------------------------------------------
// Main tick loop
// ---------------------------------------------------------------------------

function npcTick(): void {
  for (const [regionId, npcs] of Array.from(npcsByRegion.entries())) {
    if (npcs.size === 0) continue;

    const avatars = getRegionPopulation(regionId);

    for (const npc of Array.from(npcs.values())) {
      tickNpc(npc, avatars);
    }

    // Broadcast NPC positions to region (batched as a single event)
    const npcStates = Array.from(npcs.values()).map((n) => ({
      id: n.id,
      x: n.x,
      y: n.y,
      z: n.z,
      behaviorState: n.behaviorState,
      displayName: n.displayName,
      npcType: n.npcType,
      appearance: n.appearance
    }));

    broadcastRegion(regionId, {
      type: "chat",
      sequence: nextRegionSequence(regionId),
      avatarId: "npc:tick",
      displayName: "NPC System",
      message: JSON.stringify({ npcPositions: npcStates }),
      createdAt: new Date().toISOString()
    });
  }
}

export function startNpcTickLoop(): void {
  if (tickInterval) return;
  seedDefaultNpcs();
  tickInterval = setInterval(npcTick, NPC_TICK_MS);
}

export function stopNpcTickLoop(): void {
  if (tickInterval) {
    clearInterval(tickInterval);
    tickInterval = null;
  }
}

// ---------------------------------------------------------------------------
// Seed default NPCs into existing regions
// ---------------------------------------------------------------------------

function seedDefaultNpcs(): void {
  const regions = listRegions();

  for (const region of regions) {
    const existing = getRegionNpcs(region.id);
    if (existing.size > 0) continue;

    // Spawn a tour guide near the center
    spawnNpc(region.id, pickRandom(TOUR_GUIDE_NAMES), "tour-guide", 2, 0, 2);

    // Spawn a shopkeeper
    spawnNpc(region.id, pickRandom(SHOPKEEPER_NAMES), "shopkeeper", 8, 0, -6);

    // Spawn a quest giver
    spawnNpc(region.id, pickRandom(QUEST_GIVER_NAMES), "quest-giver", -8, 0, 6);

    // Spawn 3 ambient NPCs at varied positions
    for (let i = 0; i < 3; i++) {
      const ax = Number(((Math.random() - 0.5) * 40).toFixed(2));
      const az = Number(((Math.random() - 0.5) * 40).toFixed(2));
      spawnNpc(region.id, pickRandom(AMBIENT_NAMES), "ambient", ax, 0, az);
    }
  }
}

// ---------------------------------------------------------------------------
// Dialogue interaction
// ---------------------------------------------------------------------------

export function startDialogue(token: string, npcId: string): { npcText: string; options: DialogueOption[] } | undefined {
  const session = getSession(token);
  if (!session) return undefined;

  const npc = getNpc(npcId);
  if (!npc || !npc.dialogue) return undefined;

  const startNode = npc.dialogue.nodes.get(npc.dialogue.startNodeId);
  if (!startNode) return undefined;

  // Track conversation state
  activeConversations.set(session.accountId, {
    npcId,
    currentNodeId: npc.dialogue.startNodeId
  });

  npc.behaviorState = "converse";

  return {
    npcText: startNode.npcText,
    options: startNode.options
  };
}

export function advanceDialogue(
  token: string,
  npcId: string,
  optionId: string
): { npcText: string; options: DialogueOption[]; action?: DialogueAction | null; ended: boolean } | undefined {
  const session = getSession(token);
  if (!session) return undefined;

  const npc = getNpc(npcId);
  if (!npc || !npc.dialogue) return undefined;

  const conversation = activeConversations.get(session.accountId);
  if (!conversation || conversation.npcId !== npcId) return undefined;

  const currentNode = npc.dialogue.nodes.get(conversation.currentNodeId);
  if (!currentNode) return undefined;

  const selectedOption = currentNode.options.find((o) => o.id === optionId);
  if (!selectedOption) return undefined;

  // Handle action from the selected option
  const action = selectedOption.action ?? null;
  if (action) {
    executeDialogueAction(session, npc, action);
  }

  // End of conversation
  if (!selectedOption.nextNodeId) {
    activeConversations.delete(session.accountId);
    npc.behaviorState = "idle";
    return {
      npcText: currentNode.npcText,
      options: [],
      action,
      ended: true
    };
  }

  const nextNode = npc.dialogue.nodes.get(selectedOption.nextNodeId);
  if (!nextNode) {
    activeConversations.delete(session.accountId);
    npc.behaviorState = "idle";
    return {
      npcText: "Hmm, I seem to have lost my train of thought. Come back later!",
      options: [],
      action,
      ended: true
    };
  }

  conversation.currentNodeId = selectedOption.nextNodeId;

  return {
    npcText: nextNode.npcText,
    options: nextNode.options,
    action,
    ended: nextNode.options.length === 0
  };
}

function executeDialogueAction(session: Session, npc: NpcRecord, action: DialogueAction): void {
  switch (action.type) {
    case "give_quest": {
      const questId = action.payload.questId as string;
      const quest = npc.quests.find((q) => q.id === questId);
      if (quest) {
        acceptQuest(session.accountId, quest);
      }
      break;
    }
    case "give_currency": {
      // Would integrate with economy-service — placeholder broadcast
      const amount = (action.payload.amount as number) ?? 10;
      broadcastRegion(session.regionId, {
        type: "chat",
        sequence: nextRegionSequence(session.regionId),
        avatarId: `npc:${npc.id}`,
        displayName: npc.displayName,
        message: `Here's ${amount} VibeCoins for your trouble!`,
        createdAt: new Date().toISOString()
      });
      break;
    }
    case "open_shop":
    case "give_item":
    case "teleport":
      // These actions are communicated back to the client for handling
      break;
  }
}

// ---------------------------------------------------------------------------
// Quest system
// ---------------------------------------------------------------------------

function acceptQuest(accountId: string, quest: Quest): void {
  const existing = playerQuests.get(accountId) ?? [];

  // Don't accept duplicates
  if (existing.some((pq) => pq.questId === quest.id && pq.status === "active")) return;

  const state: PlayerQuestState = {
    questId: quest.id,
    accountId,
    objectives: quest.objectives.map((o) => ({ ...o, current: 0 })),
    status: "active",
    startedAt: new Date().toISOString(),
    completedAt: null
  };

  existing.push(state);
  playerQuests.set(accountId, existing);
}

export function getPlayerQuests(token: string): { active: PlayerQuestState[]; completed: PlayerQuestState[] } | undefined {
  const session = getSession(token);
  if (!session) return undefined;

  const quests = playerQuests.get(session.accountId) ?? [];

  // Check for expired quests
  const now = new Date();
  for (const pq of quests) {
    if (pq.status === "active") {
      const quest = findQuestById(pq.questId);
      if (quest?.expiresAt && new Date(quest.expiresAt) < now) {
        pq.status = "expired";
      }
    }
  }

  return {
    active: quests.filter((q) => q.status === "active"),
    completed: quests.filter((q) => q.status === "completed")
  };
}

export function listAvailableQuests(regionId: string): Quest[] {
  const npcs = listNpcsByRegion(regionId);
  const quests: Quest[] = [];
  for (const npc of npcs) {
    quests.push(...npc.quests);
  }
  return quests;
}

function findQuestById(questId: string): Quest | undefined {
  for (const npcs of Array.from(npcsByRegion.values())) {
    for (const npc of Array.from(npcs.values())) {
      const quest = npc.quests.find((q) => q.id === questId);
      if (quest) return quest;
    }
  }
  return undefined;
}

export function completeQuest(token: string, questId: string): { success: boolean; rewards?: QuestReward[]; reason?: string } {
  const session = getSession(token);
  if (!session) return { success: false, reason: "invalid session" };

  const quests = playerQuests.get(session.accountId) ?? [];
  const pq = quests.find((q) => q.questId === questId && q.status === "active");

  if (!pq) return { success: false, reason: "quest not found or not active" };

  // Check if all objectives are complete
  const allComplete = pq.objectives.every((o) => o.current >= o.required);
  if (!allComplete) return { success: false, reason: "objectives not yet complete" };

  pq.status = "completed";
  pq.completedAt = new Date().toISOString();

  const quest = findQuestById(questId);
  const rewards = quest?.rewards ?? [];

  // Broadcast completion
  broadcastRegion(session.regionId, {
    type: "chat",
    sequence: nextRegionSequence(session.regionId),
    avatarId: "system",
    displayName: "Quest System",
    message: `${session.displayName} completed the quest "${quest?.title ?? "Unknown"}"!`,
    createdAt: new Date().toISOString()
  });

  return { success: true, rewards };
}

export function updateQuestProgress(
  accountId: string,
  objectiveType: QuestObjectiveType,
  target: string,
  increment: number = 1
): void {
  const quests = playerQuests.get(accountId) ?? [];

  for (const pq of quests) {
    if (pq.status !== "active") continue;

    for (const obj of pq.objectives) {
      if (obj.type === objectiveType && (obj.target === target || obj.target === "any")) {
        obj.current = Math.min(obj.current + increment, obj.required);
      }
    }
  }
}

// ---------------------------------------------------------------------------
// NPC scripting
// ---------------------------------------------------------------------------

export function addNpcScript(token: string, npcId: string, name: string, code: string): NpcScript | undefined {
  const session = getSession(token);
  if (!session || session.role !== "admin") return undefined;

  const npc = getNpc(npcId);
  if (!npc) return undefined;

  const script: NpcScript = {
    id: randomUUID(),
    npcId,
    name,
    code,
    enabled: true,
    createdAt: new Date().toISOString()
  };

  npc.scripts.push(script);
  npcScriptsById.set(script.id, script);
  return script;
}

export function updateNpcScript(token: string, scriptId: string, code: string, enabled: boolean): NpcScript | undefined {
  const session = getSession(token);
  if (!session || session.role !== "admin") return undefined;

  const script = npcScriptsById.get(scriptId);
  if (!script) return undefined;

  script.code = code;
  script.enabled = enabled;

  // Also update in the NPC's script list
  const npc = getNpc(script.npcId);
  if (npc) {
    const idx = npc.scripts.findIndex((s) => s.id === scriptId);
    if (idx !== -1) npc.scripts[idx] = script;
  }

  return script;
}

export function removeNpcScript(token: string, scriptId: string): boolean {
  const session = getSession(token);
  if (!session || session.role !== "admin") return false;

  const script = npcScriptsById.get(scriptId);
  if (!script) return false;

  npcScriptsById.delete(scriptId);

  const npc = getNpc(script.npcId);
  if (npc) {
    npc.scripts = npc.scripts.filter((s) => s.id !== scriptId);
  }

  return true;
}

// ---------------------------------------------------------------------------
// Serialization helpers (for API responses)
// ---------------------------------------------------------------------------

export function serializeNpc(npc: NpcRecord): Record<string, unknown> {
  return {
    id: npc.id,
    regionId: npc.regionId,
    displayName: npc.displayName,
    npcType: npc.npcType,
    appearance: npc.appearance,
    x: npc.x,
    y: npc.y,
    z: npc.z,
    behaviorState: npc.behaviorState,
    patrolRadius: npc.patrolRadius,
    interactRadius: npc.interactRadius,
    hasDialogue: npc.dialogue !== null,
    questCount: npc.quests.length,
    scriptCount: npc.scripts.length,
    createdAt: npc.createdAt,
    updatedAt: npc.updatedAt
  };
}

export function serializeDialogueNode(npcText: string, options: DialogueOption[]): Record<string, unknown> {
  return {
    npcText,
    options: options.map((o) => ({
      id: o.id,
      text: o.text,
      hasAction: !!o.action
    }))
  };
}
