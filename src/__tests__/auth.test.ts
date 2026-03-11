import { describe, it, expect, beforeEach } from "vitest";
import {
  createGuestSession,
  registerSession,
  loginSession,
  getSession,
  getPersistenceMode,
} from "../world/store.js";
import { resetWorldStore } from "./helpers.js";

describe("Auth flows", () => {
  beforeEach(async () => {
    await resetWorldStore();
  });

  it("uses in-memory persistence (no DATABASE_URL)", () => {
    expect(getPersistenceMode()).toBe("memory");
  });

  // ── Guest ──────────────────────────────────────────────────────────────────

  it("creates a guest account and returns a valid session", async () => {
    const result = await createGuestSession("GuestAlice");

    expect(result.account).toBeDefined();
    expect(result.account.kind).toBe("guest");
    expect(result.account.displayName).toBe("GuestAlice");
    expect(result.session.token).toBeTruthy();
    expect(result.session.accountId).toBe(result.account.id);
    expect(result.session.role).toBe("resident");
    expect(result.avatar).toBeDefined();
    expect(result.inventory.length).toBeGreaterThan(0);
  });

  // ── Register ───────────────────────────────────────────────────────────────

  it("registers a new account", async () => {
    const result = await registerSession("Alice", "secret123");

    expect(result.ok).toBe(true);
    if (!result.ok) return;
    expect(result.account.kind).toBe("registered");
    expect(result.account.displayName).toBe("Alice");
    expect(result.session.token).toBeTruthy();
  });

  it("rejects duplicate registration", async () => {
    await registerSession("Alice", "secret123");
    const dup = await registerSession("Alice", "other");

    expect(dup.ok).toBe(false);
    if (!dup.ok) {
      expect(dup.reason).toMatch(/already exists/i);
    }
  });

  // ── Login ──────────────────────────────────────────────────────────────────

  it("logs in with the correct password", async () => {
    await registerSession("Bob", "pass1234");
    const login = await loginSession("Bob", "pass1234");

    expect(login.ok).toBe(true);
    if (!login.ok) return;
    expect(login.account.displayName).toBe("Bob");
    expect(login.session.token).toBeTruthy();
  });

  it("rejects login with wrong password", async () => {
    await registerSession("Carol", "correct");
    const login = await loginSession("Carol", "wrong");

    expect(login.ok).toBe(false);
    if (!login.ok) {
      expect(login.reason).toMatch(/invalid credentials/i);
    }
  });

  // ── Session token ──────────────────────────────────────────────────────────

  it("validates a session token that was just created", async () => {
    const result = await createGuestSession("Dave");
    const session = getSession(result.session.token);

    expect(session).toBeDefined();
    expect(session!.accountId).toBe(result.account.id);
  });

  it("rejects an invalid / made-up token", () => {
    const session = getSession("not-a-real-token");
    expect(session).toBeUndefined();
  });
});
