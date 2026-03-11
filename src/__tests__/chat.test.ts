import { describe, it, expect, beforeEach } from "vitest";
import {
  handleChatMessage,
  getChatHistory,
  handleWhisper,
  handleEmote,
  getEmoteList,
  createGuestSession,
  getSession,
} from "../world/store.js";
import { resetWorldStore, createTestSession, TEST_REGION_ID } from "./helpers.js";

describe("Chat", () => {
  beforeEach(async () => {
    await resetWorldStore();
  });

  it("stores a chat message in the history buffer", async () => {
    const { session } = await createTestSession("Chatter");

    const entry = handleChatMessage(session, "Hello world!");

    expect(entry.displayName).toBe("Chatter");
    expect(entry.message).toBe("Hello world!");
    expect(entry.channel).toBe("region");
  });

  it("retrieves chat history for a region", async () => {
    const { session } = await createTestSession("Historian");

    handleChatMessage(session, "First");
    handleChatMessage(session, "Second");
    handleChatMessage(session, "Third");

    const history = getChatHistory(session.regionId);
    expect(history).toHaveLength(3);
    expect(history[0].message).toBe("First");
    expect(history[2].message).toBe("Third");
  });

  it("caps the history buffer at 50 entries", async () => {
    const { session } = await createTestSession("Spammer");

    for (let i = 0; i < 60; i++) {
      handleChatMessage(session, `msg-${i}`);
    }

    const history = getChatHistory(session.regionId);
    expect(history).toHaveLength(50);
    // oldest messages should have been dropped
    expect(history[0].message).toBe("msg-10");
    expect(history[49].message).toBe("msg-59");
  });

  // ── Whisper ────────────────────────────────────────────────────────────────

  it("whisper finds target in same region", async () => {
    const alice = await createTestSession("Alice");
    const bob = await createTestSession("Bob");

    const result = handleWhisper(alice.session, "Bob", "psst hey");

    expect(result).toBeDefined();
    expect(result!.toSession.displayName).toBe("Bob");
    expect(result!.message).toBe("psst hey");
  });

  it("whisper returns undefined for unknown target", async () => {
    const alice = await createTestSession("Alice");

    const result = handleWhisper(alice.session, "Nobody", "hello?");
    expect(result).toBeUndefined();
  });

  // ── Emotes ─────────────────────────────────────────────────────────────────

  it("validates a known emote", async () => {
    const { token } = await createTestSession("Dancer");

    const result = handleEmote(token, "wave");
    expect(result).toBeDefined();
    expect(result!.emote.name).toBe("wave");
    expect(result!.emote.category).toBe("greetings");
  });

  it("rejects an unknown emote", async () => {
    const { token } = await createTestSession("Dancer");

    const result = handleEmote(token, "moonwalk");
    expect(result).toBeUndefined();
  });

  it("emote list is non-empty", () => {
    const emotes = getEmoteList();
    expect(emotes.length).toBeGreaterThan(0);
    expect(emotes.some((e) => e.name === "dance")).toBe(true);
  });
});
