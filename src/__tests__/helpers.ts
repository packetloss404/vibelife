import {
  createGuestSession,
  registerSession,
  initializeWorldStore,
} from "../world/store.js";
import {
  sessions,
  avatarsByRegion,
  chatHistoryByRegion,
  objectGroups,
} from "../world/_shared-state.js";

/**
 * Re-initialise the in-memory world store so every test starts clean.
 * Clears all module-level maps that initializeWorldStore does not reset.
 */
export async function resetWorldStore(): Promise<void> {
  sessions.clear();
  avatarsByRegion.clear();
  chatHistoryByRegion.clear();
  objectGroups.clear();
  await initializeWorldStore();
}

/**
 * Create a guest session and return the token + session for convenience.
 */
export async function createTestSession(displayName = "TestUser") {
  const result = await createGuestSession(displayName);
  return {
    token: result.session.token,
    session: result.session,
    account: result.account,
    avatar: result.avatar,
  };
}

/**
 * Register a named account with a password, returning the token + session.
 */
export async function createRegisteredSession(
  displayName: string,
  password: string,
) {
  const result = await registerSession(displayName, password);
  if (!result.ok) {
    throw new Error(`Registration failed: ${result.reason}`);
  }
  return {
    token: result.session.token,
    session: result.session,
    account: result.account,
  };
}

/** The first seeded region id - "aurora-docks". */
export const TEST_REGION_ID = "aurora-docks";

/** A public parcel in aurora-docks (minX=-10..maxX=10, minZ=-10..maxZ=10). */
export const PUBLIC_PARCEL_ID = "aurora-landing";

/** A homestead (private) parcel in aurora-docks. */
export const PRIVATE_PARCEL_ID = "aurora-east-pier";
