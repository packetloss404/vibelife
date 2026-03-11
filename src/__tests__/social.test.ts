import { describe, it, expect, beforeEach } from "vitest";
import {
  addFriend,
  removeFriend,
  listFriends,
  createGroup,
  addGroupMember,
  getGroupMembers,
  listGroups,
  getCurrencyBalance,
  sendCurrency,
} from "../world/store.js";
import { resetWorldStore, createTestSession } from "./helpers.js";

describe("Social features", () => {
  beforeEach(async () => {
    await resetWorldStore();
  });

  // ── Friends ────────────────────────────────────────────────────────────────

  it("adds a friend", async () => {
    const alice = await createTestSession("Alice");
    const bob = await createTestSession("Bob");

    const friend = await addFriend(alice.token, bob.account.id);

    expect(friend).toBeDefined();
    expect(friend!.friendAccountId).toBe(bob.account.id);
    expect(friend!.status).toBe("pending");

    const friends = await listFriends(alice.token);
    expect(friends).toHaveLength(1);
  });

  it("removes a friend", async () => {
    const alice = await createTestSession("Alice");
    const bob = await createTestSession("Bob");

    await addFriend(alice.token, bob.account.id);
    const removed = await removeFriend(alice.token, bob.account.id);
    expect(removed).toBe(true);

    const friends = await listFriends(alice.token);
    expect(friends).toHaveLength(0);
  });

  // ── Groups ─────────────────────────────────────────────────────────────────

  it("creates a group", async () => {
    const alice = await createTestSession("Alice");

    const group = await createGroup(alice.token, "VibeClub", "A chill group");
    expect(group).toBeDefined();
    expect(group!.name).toBe("VibeClub");
    expect(group!.founderAccountId).toBe(alice.account.id);

    // Founder is automatically added as owner
    const members = await getGroupMembers(alice.token, group!.id);
    expect(members).toHaveLength(1);
    expect(members[0].role).toBe("owner");
  });

  it("allows another user to join a group", async () => {
    const alice = await createTestSession("Alice");
    const bob = await createTestSession("Bob");

    const group = await createGroup(alice.token, "Party", "Everyone welcome");

    const joined = await addGroupMember(
      alice.token,
      group!.id,
      bob.account.id,
      "member",
    );
    expect(joined).toBe(true);

    const members = await getGroupMembers(alice.token, group!.id);
    expect(members).toHaveLength(2);

    // Bob should see the group in their list
    const bobGroups = await listGroups(bob.token);
    expect(bobGroups.some((g) => g.id === group!.id)).toBe(true);
  });

  // ── Currency ───────────────────────────────────────────────────────────────

  it("transfers currency between accounts", async () => {
    const alice = await createTestSession("Alice");
    const bob = await createTestSession("Bob");

    const aliceBalanceBefore = await getCurrencyBalance(alice.token);
    expect(aliceBalanceBefore).toBe(1000); // default starting balance

    const result = await sendCurrency(
      alice.token,
      bob.account.id,
      250,
      "housewarming gift",
    );

    expect(result).toBeDefined();

    const aliceBalanceAfter = await getCurrencyBalance(alice.token);
    const bobBalanceAfter = await getCurrencyBalance(bob.token);

    expect(aliceBalanceAfter).toBe(750);
    expect(bobBalanceAfter).toBe(1250);
  });

  it("rejects currency transfer when balance is insufficient", async () => {
    const alice = await createTestSession("Alice");
    const bob = await createTestSession("Bob");

    // Try to send more than the 1000 starting balance
    const result = await sendCurrency(
      alice.token,
      bob.account.id,
      5000,
      "too much",
    );

    expect(result).toBeUndefined();
  });
});
