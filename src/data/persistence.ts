import { randomUUID } from "node:crypto";
import pg from "pg";

const { Pool } = pg;

export type RegionRecord = {
  id: string;
  name: string;
  capacity: number;
  terrain: string;
  mood: string;
  themeColor: string;
};

export type AccountRecord = {
  id: string;
  displayName: string;
  kind: "guest";
  createdAt: string;
};

export type InventoryItemRecord = {
  id: string;
  accountId: string;
  name: string;
  kind: string;
  rarity: string;
  createdAt: string;
};

export type AvatarPositionRecord = {
  accountId: string;
  regionId: string;
  x: number;
  y: number;
  z: number;
  updatedAt: string;
};

export type ParcelRecord = {
  id: string;
  regionId: string;
  name: string;
  ownerAccountId: string | null;
  ownerDisplayName: string | null;
  minX: number;
  maxX: number;
  minZ: number;
  maxZ: number;
  tier: string;
};

export type PersistenceLayer = {
  mode: "memory" | "postgres";
  listRegions(): Promise<RegionRecord[]>;
  getOrCreateGuestAccount(displayName: string): Promise<{ account: AccountRecord; isNew: boolean }>;
  getInventory(accountId: string): Promise<InventoryItemRecord[]>;
  getAvatarPosition(accountId: string, regionId: string): Promise<AvatarPositionRecord | undefined>;
  saveAvatarPosition(position: AvatarPositionRecord): Promise<void>;
  listParcels(regionId: string): Promise<ParcelRecord[]>;
  claimParcel(parcelId: string, accountId: string): Promise<ParcelRecord | undefined>;
};

const seededRegions: RegionRecord[] = [
  {
    id: "aurora-docks",
    name: "Aurora Docks",
    capacity: 80,
    terrain: "floating harbor",
    mood: "social",
    themeColor: "#66ffd1"
  },
  {
    id: "glass-garden",
    name: "Glass Garden",
    capacity: 50,
    terrain: "botanical sky dome",
    mood: "relaxed",
    themeColor: "#ffb36a"
  }
];

const seededParcels: Omit<ParcelRecord, "ownerDisplayName">[] = [
  {
    id: "aurora-landing",
    regionId: "aurora-docks",
    name: "Landing Strip",
    ownerAccountId: null,
    minX: -10,
    maxX: 10,
    minZ: -10,
    maxZ: 10,
    tier: "public"
  },
  {
    id: "aurora-east-pier",
    regionId: "aurora-docks",
    name: "East Pier",
    ownerAccountId: null,
    minX: 10,
    maxX: 28,
    minZ: -16,
    maxZ: 12,
    tier: "homestead"
  },
  {
    id: "glass-orchard",
    regionId: "glass-garden",
    name: "Orchard Ring",
    ownerAccountId: null,
    minX: -18,
    maxX: 4,
    minZ: -12,
    maxZ: 16,
    tier: "homestead"
  },
  {
    id: "glass-overlook",
    regionId: "glass-garden",
    name: "Sky Overlook",
    ownerAccountId: null,
    minX: 4,
    maxX: 22,
    minZ: -18,
    maxZ: 10,
    tier: "premium"
  }
];

const starterInventory = [
  { name: "Starter Flight Band", kind: "wearable", rarity: "common" },
  { name: "Parcel Builder Wand", kind: "tool", rarity: "uncommon" },
  { name: "Welcome Drone Companion", kind: "pet", rarity: "rare" }
];

function normalizeDisplayName(displayName: string) {
  return displayName.trim().toLowerCase().replace(/\s+/g, " ");
}

function createStarterPosition(accountId: string, regionId: string): AvatarPositionRecord {
  return {
    accountId,
    regionId,
    x: Number((Math.random() * 32 - 16).toFixed(2)),
    y: 0,
    z: Number((Math.random() * 32 - 16).toFixed(2)),
    updatedAt: new Date().toISOString()
  };
}

function createMemoryPersistence(): PersistenceLayer {
  const accountsById = new Map<string, AccountRecord>();
  const accountIdsByName = new Map<string, string>();
  const inventory = new Map<string, InventoryItemRecord[]>();
  const positions = new Map<string, AvatarPositionRecord>();
  const parcels = new Map<string, ParcelRecord>(
    seededParcels.map((parcel) => [parcel.id, { ...parcel, ownerDisplayName: null }])
  );

  return {
    mode: "memory",
    async listRegions() {
      return seededRegions;
    },
    async getOrCreateGuestAccount(displayName) {
      const key = normalizeDisplayName(displayName);
      const existingId = accountIdsByName.get(key);

      if (existingId) {
        return { account: accountsById.get(existingId) as AccountRecord, isNew: false };
      }

      const account: AccountRecord = {
        id: randomUUID(),
        displayName,
        kind: "guest",
        createdAt: new Date().toISOString()
      };

      accountsById.set(account.id, account);
      accountIdsByName.set(key, account.id);
      inventory.set(
        account.id,
        starterInventory.map((item) => ({
          id: randomUUID(),
          accountId: account.id,
          name: item.name,
          kind: item.kind,
          rarity: item.rarity,
          createdAt: new Date().toISOString()
        }))
      );

      return { account, isNew: true };
    },
    async getInventory(accountId) {
      return inventory.get(accountId) ?? [];
    },
    async getAvatarPosition(accountId, regionId) {
      return positions.get(`${accountId}:${regionId}`);
    },
    async saveAvatarPosition(position) {
      positions.set(`${position.accountId}:${position.regionId}`, position);
    },
    async listParcels(regionId) {
      return [...parcels.values()].filter((parcel) => parcel.regionId === regionId);
    },
    async claimParcel(parcelId, accountId) {
      const parcel = parcels.get(parcelId);
      const account = accountsById.get(accountId);

      if (!parcel || !account || (parcel.ownerAccountId && parcel.ownerAccountId !== accountId)) {
        return undefined;
      }

      const updatedParcel: ParcelRecord = {
        ...parcel,
        ownerAccountId: accountId,
        ownerDisplayName: account.displayName
      };

      parcels.set(parcelId, updatedParcel);
      return updatedParcel;
    }
  };
}

async function createPostgresPersistence(databaseUrl: string): Promise<PersistenceLayer> {
  const pool = new Pool({ connectionString: databaseUrl });

  await pool.query(`
    CREATE TABLE IF NOT EXISTS regions (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      capacity INTEGER NOT NULL,
      terrain TEXT NOT NULL,
      mood TEXT NOT NULL,
      theme_color TEXT NOT NULL
    )
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS accounts (
      id UUID PRIMARY KEY,
      display_name TEXT NOT NULL,
      display_name_key TEXT NOT NULL UNIQUE,
      kind TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL
    )
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS inventory_items (
      id UUID PRIMARY KEY,
      account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
      name TEXT NOT NULL,
      kind TEXT NOT NULL,
      rarity TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL
    )
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS avatar_positions (
      account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
      region_id TEXT NOT NULL REFERENCES regions(id) ON DELETE CASCADE,
      x DOUBLE PRECISION NOT NULL,
      y DOUBLE PRECISION NOT NULL,
      z DOUBLE PRECISION NOT NULL,
      updated_at TIMESTAMPTZ NOT NULL,
      PRIMARY KEY (account_id, region_id)
    )
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS parcels (
      id TEXT PRIMARY KEY,
      region_id TEXT NOT NULL REFERENCES regions(id) ON DELETE CASCADE,
      name TEXT NOT NULL,
      owner_account_id UUID REFERENCES accounts(id) ON DELETE SET NULL,
      min_x DOUBLE PRECISION NOT NULL,
      max_x DOUBLE PRECISION NOT NULL,
      min_z DOUBLE PRECISION NOT NULL,
      max_z DOUBLE PRECISION NOT NULL,
      tier TEXT NOT NULL
    )
  `);

  for (const region of seededRegions) {
    await pool.query(
      `
        INSERT INTO regions (id, name, capacity, terrain, mood, theme_color)
        VALUES ($1, $2, $3, $4, $5, $6)
        ON CONFLICT (id) DO UPDATE SET
          name = EXCLUDED.name,
          capacity = EXCLUDED.capacity,
          terrain = EXCLUDED.terrain,
          mood = EXCLUDED.mood,
          theme_color = EXCLUDED.theme_color
      `,
      [region.id, region.name, region.capacity, region.terrain, region.mood, region.themeColor]
    );
  }

  for (const parcel of seededParcels) {
    await pool.query(
      `
        INSERT INTO parcels (id, region_id, name, owner_account_id, min_x, max_x, min_z, max_z, tier)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
        ON CONFLICT (id) DO UPDATE SET
          region_id = EXCLUDED.region_id,
          name = EXCLUDED.name,
          min_x = EXCLUDED.min_x,
          max_x = EXCLUDED.max_x,
          min_z = EXCLUDED.min_z,
          max_z = EXCLUDED.max_z,
          tier = EXCLUDED.tier
      `,
      [
        parcel.id,
        parcel.regionId,
        parcel.name,
        parcel.ownerAccountId,
        parcel.minX,
        parcel.maxX,
        parcel.minZ,
        parcel.maxZ,
        parcel.tier
      ]
    );
  }

  return {
    mode: "postgres",
    async listRegions() {
      const result = await pool.query<{
        id: string;
        name: string;
        capacity: number;
        terrain: string;
        mood: string;
        theme_color: string;
      }>("SELECT id, name, capacity, terrain, mood, theme_color FROM regions ORDER BY name ASC");

      return result.rows.map((row) => ({
        id: row.id,
        name: row.name,
        capacity: row.capacity,
        terrain: row.terrain,
        mood: row.mood,
        themeColor: row.theme_color
      }));
    },
    async getOrCreateGuestAccount(displayName) {
      const displayNameKey = normalizeDisplayName(displayName);
      const existing = await pool.query<{
        id: string;
        display_name: string;
        kind: "guest";
        created_at: string;
      }>(
        "SELECT id, display_name, kind, created_at FROM accounts WHERE display_name_key = $1 LIMIT 1",
        [displayNameKey]
      );

      if (existing.rows[0]) {
        return {
          account: {
            id: existing.rows[0].id,
            displayName: existing.rows[0].display_name,
            kind: existing.rows[0].kind,
            createdAt: existing.rows[0].created_at
          },
          isNew: false
        };
      }

      const account: AccountRecord = {
        id: randomUUID(),
        displayName,
        kind: "guest",
        createdAt: new Date().toISOString()
      };

      await pool.query(
        "INSERT INTO accounts (id, display_name, display_name_key, kind, created_at) VALUES ($1, $2, $3, $4, $5)",
        [account.id, account.displayName, displayNameKey, account.kind, account.createdAt]
      );

      for (const item of starterInventory) {
        await pool.query(
          "INSERT INTO inventory_items (id, account_id, name, kind, rarity, created_at) VALUES ($1, $2, $3, $4, $5, $6)",
          [randomUUID(), account.id, item.name, item.kind, item.rarity, new Date().toISOString()]
        );
      }

      return { account, isNew: true };
    },
    async getInventory(accountId) {
      const result = await pool.query<{
        id: string;
        account_id: string;
        name: string;
        kind: string;
        rarity: string;
        created_at: string;
      }>(
        "SELECT id, account_id, name, kind, rarity, created_at FROM inventory_items WHERE account_id = $1 ORDER BY created_at ASC",
        [accountId]
      );

      return result.rows.map((row) => ({
        id: row.id,
        accountId: row.account_id,
        name: row.name,
        kind: row.kind,
        rarity: row.rarity,
        createdAt: row.created_at
      }));
    },
    async getAvatarPosition(accountId, regionId) {
      const result = await pool.query<{
        account_id: string;
        region_id: string;
        x: number;
        y: number;
        z: number;
        updated_at: string;
      }>(
        "SELECT account_id, region_id, x, y, z, updated_at FROM avatar_positions WHERE account_id = $1 AND region_id = $2 LIMIT 1",
        [accountId, regionId]
      );

      const row = result.rows[0];

      if (!row) {
        return undefined;
      }

      return {
        accountId: row.account_id,
        regionId: row.region_id,
        x: row.x,
        y: row.y,
        z: row.z,
        updatedAt: row.updated_at
      };
    },
    async saveAvatarPosition(position) {
      await pool.query(
        `
          INSERT INTO avatar_positions (account_id, region_id, x, y, z, updated_at)
          VALUES ($1, $2, $3, $4, $5, $6)
          ON CONFLICT (account_id, region_id) DO UPDATE SET
            x = EXCLUDED.x,
            y = EXCLUDED.y,
            z = EXCLUDED.z,
            updated_at = EXCLUDED.updated_at
        `,
        [position.accountId, position.regionId, position.x, position.y, position.z, position.updatedAt]
      );
    },
    async listParcels(regionId) {
      const result = await pool.query<{
        id: string;
        region_id: string;
        name: string;
        owner_account_id: string | null;
        owner_display_name: string | null;
        min_x: number;
        max_x: number;
        min_z: number;
        max_z: number;
        tier: string;
      }>(
        `
          SELECT
            parcels.id,
            parcels.region_id,
            parcels.name,
            parcels.owner_account_id,
            accounts.display_name AS owner_display_name,
            parcels.min_x,
            parcels.max_x,
            parcels.min_z,
            parcels.max_z,
            parcels.tier
          FROM parcels
          LEFT JOIN accounts ON accounts.id = parcels.owner_account_id
          WHERE parcels.region_id = $1
          ORDER BY parcels.name ASC
        `,
        [regionId]
      );

      return result.rows.map((row) => ({
        id: row.id,
        regionId: row.region_id,
        name: row.name,
        ownerAccountId: row.owner_account_id,
        ownerDisplayName: row.owner_display_name,
        minX: row.min_x,
        maxX: row.max_x,
        minZ: row.min_z,
        maxZ: row.max_z,
        tier: row.tier
      }));
    },
    async claimParcel(parcelId, accountId) {
      const result = await pool.query<{
        id: string;
        region_id: string;
        name: string;
        owner_account_id: string | null;
        owner_display_name: string | null;
        min_x: number;
        max_x: number;
        min_z: number;
        max_z: number;
        tier: string;
      }>(
        `
          UPDATE parcels
          SET owner_account_id = $2
          WHERE id = $1 AND (owner_account_id IS NULL OR owner_account_id = $2)
          RETURNING
            id,
            region_id,
            name,
            owner_account_id,
            (SELECT display_name FROM accounts WHERE accounts.id = $2) AS owner_display_name,
            min_x,
            max_x,
            min_z,
            max_z,
            tier
        `,
        [parcelId, accountId]
      );

      const row = result.rows[0];

      if (!row) {
        return undefined;
      }

      return {
        id: row.id,
        regionId: row.region_id,
        name: row.name,
        ownerAccountId: row.owner_account_id,
        ownerDisplayName: row.owner_display_name,
        minX: row.min_x,
        maxX: row.max_x,
        minZ: row.min_z,
        maxZ: row.max_z,
        tier: row.tier
      };
    }
  };
}

export async function createPersistenceLayer(): Promise<PersistenceLayer> {
  const databaseUrl = process.env.DATABASE_URL;

  if (!databaseUrl) {
    return createMemoryPersistence();
  }

  try {
    return await createPostgresPersistence(databaseUrl);
  } catch (error) {
    console.warn("Postgres bootstrap failed, using memory mode instead.", error);
    return createMemoryPersistence();
  }
}
