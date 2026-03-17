export type AuthMode = "guest" | "register" | "login";

export type AccountRole = "resident" | "admin";

export type AccountKind = "guest" | "registered";

export type AvatarAppearanceContract = {
  accountId: string;
  bodyColor: string;
  accentColor: string;
  headColor: string;
  hairColor: string;
  outfit: string;
  accessory: string;
  updatedAt: string;
};

export type AvatarStateContract = {
  avatarId: string;
  accountId: string;
  displayName: string;
  appearance: AvatarAppearanceContract;
  x: number;
  y: number;
  z: number;
  updatedAt: string;
};

export type ParcelContract = {
  id: string;
  regionId: string;
  name: string;
  ownerAccountId: string | null;
  ownerDisplayName: string | null;
  collaboratorAccountIds: string[];
  collaboratorDisplayNames: string[];
  minX: number;
  maxX: number;
  minZ: number;
  maxZ: number;
  tier: string;
};

export type RegionObjectContract = {
  id: string;
  regionId: string;
  ownerAccountId: string;
  ownerDisplayName: string | null;
  asset: string;
  x: number;
  y: number;
  z: number;
  rotationY: number;
  scale: number;
  createdAt: string;
  updatedAt: string;
};

export type ChatChannel = "region" | "whisper" | "global" | "group";

export type ChatHistoryEntry = {
  avatarId: string;
  displayName: string;
  message: string;
  channel: ChatChannel;
  createdAt: string;
};

export type RegionSnapshotEvent = {
  type: "snapshot";
  sequence: number;
  avatars: AvatarStateContract[];
  objects: RegionObjectContract[];
  parcels: ParcelContract[];
  chatHistory: ChatHistoryEntry[];
  enemies: EnemyStateContract[];
  combatStats: CombatStatsContract;
};

export type RegionEvent =
  | RegionSnapshotEvent
  | { type: "avatar:joined"; sequence: number; avatar: AvatarStateContract }
  | { type: "avatar:moved"; sequence: number; avatar: AvatarStateContract }
  | { type: "avatar:updated"; sequence: number; avatar: AvatarStateContract }
  | { type: "avatar:left"; sequence: number; avatarId: string }
  | { type: "avatar:typing"; sequence: number; avatarId: string; displayName: string; typing: boolean }
  | { type: "chat"; sequence: number; avatarId: string; displayName: string; message: string; channel: ChatChannel; createdAt: string }
  | { type: "chat:history"; sequence: number; messages: ChatHistoryEntry[] }
  | { type: "whisper"; sequence: number; fromAvatarId: string; fromDisplayName: string; toAvatarId: string; toDisplayName: string; message: string; createdAt: string }
  | { type: "object:created"; sequence: number; object: RegionObjectContract }
  | { type: "object:updated"; sequence: number; object: RegionObjectContract }
  | { type: "object:deleted"; sequence: number; objectId: string }
  | { type: "parcel:updated"; sequence: number; parcel: ParcelContract }
  | { type: "media:created"; sequence: number; media: MediaObjectContract }
  | { type: "media:updated"; sequence: number; media: MediaObjectContract }
  | { type: "media:removed"; sequence: number; objectId: string }
  | { type: "pet:summoned"; sequence: number; petState: PetStateContract }
  | { type: "pet:dismissed"; sequence: number; petId: string }
  | { type: "pet:trick"; sequence: number; petId: string; trick: string; ownerAvatarId: string }
  | { type: "pet:state_updated"; sequence: number; petState: PetStateContract }
  | { type: "voice:participant_joined"; sequence: number; participant: VoiceParticipantContract }
  | { type: "voice:participant_left"; sequence: number; accountId: string; regionId: string }
  | { type: "voice:speaking_changed"; sequence: number; accountId: string; speaking: boolean }
  | { type: "radio:changed"; sequence: number; stationId: string; stationName: string; trackName: string; currentTrack: number }
  | { type: "avatar:emote"; sequence: number; avatarId: string; displayName: string; emoteName: string; duration_ms: number }
  | { type: "emote:combo"; sequence: number; avatarIds: string[]; comboName: string; position: { x: number; y: number; z: number } }
  | { type: "avatar:sit"; sequence: number; avatarId: string; objectId: string; position: { x: number; y: number; z: number } }
  | { type: "avatar:stand"; sequence: number; avatarId: string }
  | { type: "group:chat"; sequence: number; groupId: string; avatarId: string; displayName: string; message: string; createdAt: string }
  | { type: "home:doorbell"; sequence: number; visitorAvatarId: string; visitorDisplayName: string; homeOwnerAccountId: string; parcelName: string }
  | { type: "event:started"; sequence: number; event: GameEventContract }
  | { type: "event:ended"; sequence: number; eventId: string }
  | { type: "voxel:chunk_data"; sequence: number; chunk: VoxelChunkContract }
  | { type: "voxel:block_placed"; sequence: number; regionId: string; x: number; y: number; z: number; blockTypeId: number; accountId: string }
  | { type: "voxel:block_broken"; sequence: number; regionId: string; x: number; y: number; z: number; accountId: string }
  | { type: "combat:damage"; sequence: number; attackerId: string; targetId: string; damage: number; critical: boolean; targetHp: number; targetMaxHp: number; attackStyle: string }
  | { type: "combat:death"; sequence: number; accountId: string; killedBy: string; respawnX: number; respawnY: number; respawnZ: number }
  | { type: "combat:respawn"; sequence: number; accountId: string; x: number; y: number; z: number }
  | { type: "combat:loot"; sequence: number; accountId: string; enemyId: string; currency: number; items: string[] }
  | { type: "combat:level_up"; sequence: number; accountId: string; newLevel: number }
  | { type: "enemy:spawned"; sequence: number; enemy: EnemyStateContract }
  | { type: "enemy:moved"; sequence: number; enemies: Array<{ id: string; x: number; y: number; z: number; state: string; hp: number }> }
  | { type: "enemy:despawned"; sequence: number; enemyId: string }
  | { type: "npc:positions"; sequence: number; npcs: Array<{ id: string; x: number; y: number; z: number; behaviorState: string; displayName: string; npcType: string; appearance: Record<string, string> }> };

export type ChatMessageContract = {
  type: "chat";
  channel: ChatChannel;
  message: string;
  targetAccountId?: string;
  displayName: string;
  timestamp: string;
};

export type ObjectGroupContract = {
  id: string;
  name: string;
  objectIds: string[];
  ownerId: string;
};

export type BuildUndoContract = {
  action: "create" | "delete" | "move" | "rotate" | "scale";
  objectId: string;
  beforeState: { x: number; y: number; z: number; rotationY: number; scale: number } | null;
  afterState: { x: number; y: number; z: number; rotationY: number; scale: number } | null;
};

export type SnapGridSettings = {
  enabled: boolean;
  size: 0.5 | 1.0 | 2.0;
};

export type RegionCommand =
  | { type: "move"; x: number; y?: number; z: number }
  | { type: "chat"; message: string }
  | { type: "whisper"; targetDisplayName: string; message: string }
  | { type: "radio:tune"; stationId: string }
  | { type: "radio:skip" }
  | { type: "emote"; emoteName: string }
  | { type: "typing"; typing: boolean }
  | { type: "sit"; objectId: string }
  | { type: "stand" }
  | { type: "group_chat"; groupId: string; message: string }
  | { type: "voxel:place_block"; x: number; y: number; z: number; blockTypeId: number }
  | { type: "voxel:break_block"; x: number; y: number; z: number }
  | { type: "combat:attack"; targetId: string; attackStyle: "melee" | "magic" };

export const AUTH_MODES: AuthMode[] = ["guest", "register", "login"];

export function isRegionCommand(value: unknown): value is RegionCommand {
  if (!value || typeof value !== "object") {
    return false;
  }

  const candidate = value as Record<string, unknown>;

  if (candidate.type === "move") {
    return Number.isFinite(candidate.x) && Number.isFinite(candidate.z) && (candidate.y === undefined || Number.isFinite(candidate.y));
  }

  if (candidate.type === "chat") {
    return typeof candidate.message === "string";
  }

  if (candidate.type === "whisper") {
    return typeof candidate.targetDisplayName === "string" && typeof candidate.message === "string";
  }

  if (candidate.type === "radio:tune") {
    return typeof candidate.stationId === "string";
  }

  if (candidate.type === "radio:skip") {
    return true;
  }

  if (candidate.type === "emote") {
    return typeof candidate.emoteName === "string";
  }

  if (candidate.type === "typing") {
    return typeof candidate.typing === "boolean";
  }

  if (candidate.type === "sit") {
    return typeof candidate.objectId === "string";
  }

  if (candidate.type === "stand") {
    return true;
  }

  if (candidate.type === "group_chat") {
    return typeof candidate.groupId === "string" && typeof candidate.message === "string";
  }

  if (candidate.type === "voxel:place_block") {
    return Number.isFinite(candidate.x) && Number.isFinite(candidate.y) && Number.isFinite(candidate.z) && Number.isFinite(candidate.blockTypeId);
  }

  if (candidate.type === "voxel:break_block") {
    return Number.isFinite(candidate.x) && Number.isFinite(candidate.y) && Number.isFinite(candidate.z);
  }

  if (candidate.type === "combat:attack") {
    return typeof candidate.targetId === "string" && (candidate.attackStyle === "melee" || candidate.attackStyle === "magic");
  }

  return false;
}

export type TeleportLandingPointContract = {
  id: string;
  accountId: string;
  regionId: string;
  name: string;
  x: number;
  y: number;
  z: number;
  rotationY: number;
  createdAt: string;
};

export type FriendContract = {
  id: string;
  accountId: string;
  friendAccountId: string;
  friendDisplayName: string;
  status: "pending" | "accepted" | "blocked";
  createdAt: string;
};

export type GroupContract = {
  id: string;
  name: string;
  description: string;
  founderAccountId: string;
  createdAt: string;
};

export type GroupMemberContract = {
  groupId: string;
  accountId: string;
  displayName: string;
  role: "member" | "officer" | "owner";
  joinedAt: string;
};

export type CurrencyTransactionContract = {
  id: string;
  fromAccountId: string | null;
  toAccountId: string | null;
  amount: number;
  type: "gift" | "purchase" | "sale" | "bonus" | "region_tax" | "loot" | "death_penalty";
  description: string;
  createdAt: string;
};

export type OfflineMessageContract = {
  id: string;
  fromAccountId: string;
  fromDisplayName: string;
  toAccountId: string;
  message: string;
  read: boolean;
  createdAt: string;
};

export type AvatarProfileContract = {
  accountId: string;
  bio: string;
  imageUrl: string | null;
  worldVisits: number;
  totalTime: number;
  createdAt: string;
  updatedAt: string;
};

export type BanContract = {
  id: string;
  accountId: string;
  bannedBy: string;
  reason: string;
  expiresAt: string | null;
  createdAt: string;
};

export type RegionNoticeContract = {
  id: string;
  regionId: string;
  parcelId: string | null;
  message: string;
  createdBy: string;
  createdAt: string;
};

export type ObjectPermissionsContract = {
  objectId: string;
  allowCopy: boolean;
  allowModify: boolean;
  allowTransfer: boolean;
};

export type TeleportRequest = {
  targetRegionId: string;
  x: number;
  y: number;
  z: number;
};

export type RadioStationContract = {
  id: string;
  name: string;
  genre: string;
  tracks: string[];
  currentTrack: number;
  isPlaying: boolean;
};

export type EmoteContract = {
  name: string;
  category: "greetings" | "expressions" | "actions" | "fun";
  duration_ms: number;
};

export type BlueprintContract = {
  id: string;
  name: string;
  creatorAccountId: string;
  creatorDisplayName: string;
  objects: Array<{ asset: string; x: number; y: number; z: number; rotationY: number; scale: number }>;
  createdAt: string;
};

// ── Tier 2 Contracts ────────────────────────────────────────────────────────

export type PlayerPresenceContract = {
  accountId: string;
  displayName: string;
  status: "online" | "busy" | "away" | "invisible" | "offline";
  customMessage: string;
  regionId: string | null;
  lastActivity: string;
};

export type ActivityEntryContract = {
  id: string;
  accountId: string;
  displayName: string;
  action: string;
  details: string;
  regionId?: string;
  createdAt: string;
  likes: string[];
};

export type MarketListingContract = {
  id: string;
  sellerAccountId: string;
  sellerDisplayName: string;
  itemId: string;
  itemName: string;
  itemKind: string;
  price: number;
  listingType: "fixed" | "auction";
  currentBid?: number;
  currentBidder?: string;
  currentBidderName?: string;
  minBid?: number;
  auctionEndTime?: string;
  createdAt: string;
  status: "active" | "sold" | "expired" | "cancelled";
};

export type TradeOfferContract = {
  id: string;
  fromAccountId: string;
  fromDisplayName: string;
  toAccountId: string;
  toDisplayName: string;
  offeredItems: string[];
  offeredCurrency: number;
  requestedItems: string[];
  requestedCurrency: number;
  status: "pending" | "accepted" | "declined" | "cancelled";
  createdAt: string;
};

export type GameEventContract = {
  id: string;
  name: string;
  description: string;
  creatorAccountId: string;
  creatorDisplayName: string;
  regionId: string;
  parcelId?: string;
  eventType: "build_competition" | "dance_party" | "grand_opening" | "workshop" | "meetup" | "concert" | "market_day" | "exploration";
  startTime: string;
  endTime: string;
  recurring: null | "daily" | "weekly" | "monthly";
  rsvps: string[];
  maxAttendees?: number;
  prizes?: string;
  createdAt: string;
};

export type AchievementContract = {
  id: string;
  name: string;
  description: string;
  category: "explorer" | "builder" | "social" | "collector" | "warrior";
  icon: string;
  xpReward: number;
  requirement: { type: string; count: number };
};

export type PlayerProgressContract = {
  accountId: string;
  xp: number;
  level: number;
  title: string;
  unlockedAchievements: string[];
  stats: {
    regionsVisited: string[];
    objectsPlaced: number;
    chatMessages: number;
    friendsMade: number;
    eventsAttended: number;
    itemsCollected: number;
    totalPlayTime: number;
  };
  dailyChallenges: DailyChallengeContract[];
  weeklyChallenges: DailyChallengeContract[];
};

export type DailyChallengeContract = {
  id: string;
  description: string;
  requirement: { type: string; count: number };
  progress: number;
  completed: boolean;
  xpReward: number;
  expiresAt: string;
};

// ── Tier 3 Contracts ────────────────────────────────────────────────────────

export type PetContract = {
  id: string;
  ownerAccountId: string;
  name: string;
  species: "cat" | "dog" | "bird" | "bunny" | "fox" | "dragon" | "slime" | "owl";
  rarity: "common" | "uncommon" | "rare" | "legendary";
  color: string;
  accentColor: string;
  accessory: "none" | "bow" | "hat" | "scarf" | "collar" | "wings" | "crown";
  happiness: number;
  energy: number;
  tricks: string[];
  level: number;
  xp: number;
  adoptedAt: string;
  lastFedAt: string;
  lastPlayedAt: string;
};

export type PetStateContract = {
  petId: string;
  regionId: string;
  x: number;
  y: number;
  z: number;
  animation: "idle" | "walk" | "run" | "sit" | "trick" | "sleep" | "eat" | "play";
  followingOwner: boolean;
  targetX: number;
  targetZ: number;
};

export type PhotoCommentContract = {
  id: string;
  accountId: string;
  displayName: string;
  text: string;
  createdAt: string;
};

export type PhotoContract = {
  id: string;
  accountId: string;
  displayName: string;
  regionId: string;
  title: string;
  description: string;
  filter: "none" | "vintage" | "noir" | "warm" | "cool" | "dreamy" | "pixel" | "posterize";
  width: number;
  height: number;
  thumbnailData: string;
  position: { x: number; y: number; z: number };
  cameraRotation: { x: number; y: number };
  likes: string[];
  comments: PhotoCommentContract[];
  visibility: "public" | "friends" | "private";
  createdAt: string;
};

export type MediaObjectContract = {
  id: string;
  objectId: string;
  mediaType: "photo_frame" | "video_screen" | "projection" | "billboard" | "slideshow";
  config: Record<string, unknown>;
  regionId: string;
  ownerAccountId: string;
  createdAt: string;
};

export type VoiceParticipantContract = {
  accountId: string;
  displayName: string;
  regionId: string;
  muted: boolean;
  deafened: boolean;
  speaking: boolean;
  joinedAt: string;
};

export type VoiceChannelContract = {
  regionId: string;
  participants: VoiceParticipantContract[];
};

export type SeasonContract = "spring" | "summer" | "autumn" | "winter";

export type SeasonalItemContract = {
  id: string;
  name: string;
  description: string;
  season: SeasonContract;
  holiday?: string;
  rarity: "common" | "uncommon" | "rare" | "legendary";
  type: "decoration" | "wearable" | "emote" | "pet_accessory" | "consumable";
  available: boolean;
  expiresAt?: string;
};

export type SeasonalThemeContract = {
  season: SeasonContract;
  fogColor: string;
  sunColor: string;
  skyTint: string;
  ambientParticles: string;
  ambientIntensity: number;
};

// ── Voxel & Combat Contracts ──────────────────────────────────────────────

export type BlockTypeContract = {
  id: number;
  name: string;
  color: string;
  transparent: boolean;
  hardness: number;
};

export type VoxelChunkContract = {
  chunkX: number;
  chunkZ: number;
  palette: BlockTypeContract[];
  blocks: string; // base64 RLE-compressed
  version: number;
};

export type CombatStatsContract = {
  accountId: string;
  level: number;
  hp: number;
  maxHp: number;
  mana: number;
  maxMana: number;
  strength: number;
  defense: number;
  xp: number;
  xpToNext: number;
  kills: number;
  deaths: number;
};

export type EnemyStateContract = {
  id: string;
  regionId: string;
  variant: "slime" | "skeleton" | "golem" | "shadow" | "drake";
  level: number;
  hp: number;
  maxHp: number;
  x: number;
  y: number;
  z: number;
  state: "idle" | "patrol" | "aggro" | "chase" | "attack" | "dead";
};

export type VoxelBlueprintContract = {
  id: string;
  name: string;
  creatorAccountId: string;
  creatorDisplayName: string;
  blocks: Array<{ x: number; y: number; z: number; blockTypeId: number }>;
  width: number;
  height: number;
  depth: number;
  createdAt: string;
};

export type CustomBlockContract = {
  id: number;
  name: string;
  color: string;
  transparent: boolean;
  hardness: number;
  creatorAccountId: string;
  price: number;
  createdAt: string;
};
