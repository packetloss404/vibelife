import type { ChatHistoryEntry } from "../contracts.js";
import {
  sessions,
  pushChatHistory,
  getChatHistoryBuffer,
  type Session
} from "./_shared-state.js";

export function handleChatMessage(session: Session, message: string): ChatHistoryEntry {
  const entry: ChatHistoryEntry = {
    avatarId: session.avatarId,
    displayName: session.displayName,
    message: message.slice(0, 180),
    channel: "region",
    createdAt: new Date().toISOString()
  };
  pushChatHistory(session.regionId, entry);
  return entry;
}

export function getChatHistory(regionId: string): ChatHistoryEntry[] {
  return [...getChatHistoryBuffer(regionId)];
}

export function handleWhisper(session: Session, targetDisplayName: string, message: string): {
  fromSession: Session;
  toSession: Session;
  message: string;
} | undefined {
  let targetSession: Session | undefined;
  for (const s of sessions.values()) {
    if (s.displayName.toLowerCase() === targetDisplayName.toLowerCase() && s.regionId === session.regionId) {
      targetSession = s;
      break;
    }
  }

  if (!targetSession) {
    return undefined;
  }

  return {
    fromSession: session,
    toSession: targetSession,
    message: message.slice(0, 180)
  };
}
