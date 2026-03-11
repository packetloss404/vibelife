import {
  persistence,
  getSession,
  type Friend,
  type Group,
  type GroupMember,
  type OfflineMessage,
  type AvatarProfile
} from "./_shared-state.js";

export async function listFriends(token: string): Promise<Friend[]> {
  const session = getSession(token);
  if (!session) return [];
  return persistence.listFriends(session.accountId);
}

export async function addFriend(token: string, friendAccountId: string): Promise<Friend | undefined> {
  const session = getSession(token);
  if (!session) return undefined;
  if (session.accountId === friendAccountId) return undefined;
  const friendRecord = [...(await persistence.listFriends(session.accountId))].find((f) => f.friendAccountId === friendAccountId);
  if (friendRecord) return undefined;
  return persistence.addFriend({ accountId: session.accountId, friendAccountId, friendDisplayName: "Friend", status: "pending" });
}

export async function removeFriend(token: string, friendAccountId: string): Promise<boolean> {
  const session = getSession(token);
  if (!session) return false;
  return persistence.removeFriend(session.accountId, friendAccountId);
}

export async function blockAccount(token: string, blockedAccountId: string): Promise<Friend | undefined> {
  const session = getSession(token);
  if (!session) return undefined;
  return persistence.blockAccount(session.accountId, blockedAccountId);
}

export async function unblockAccount(token: string, blockedAccountId: string): Promise<boolean> {
  const session = getSession(token);
  if (!session) return false;
  return persistence.unblockAccount(session.accountId, blockedAccountId);
}

export async function listGroups(token: string): Promise<Group[]> {
  const session = getSession(token);
  if (!session) return [];
  return persistence.listGroups(session.accountId);
}

export async function createGroup(token: string, name: string, description: string): Promise<Group | undefined> {
  const session = getSession(token);
  if (!session) return undefined;
  return persistence.createGroup({ name, description, founderAccountId: session.accountId });
}

export async function getGroupMembers(token: string, groupId: string): Promise<GroupMember[]> {
  const session = getSession(token);
  if (!session) return [];
  return persistence.getGroupMembers(groupId);
}

export async function addGroupMember(token: string, groupId: string, memberAccountId: string, role: "member" | "officer" | "owner"): Promise<boolean> {
  const session = getSession(token);
  if (!session) return false;
  await persistence.addGroupMember({ groupId, accountId: memberAccountId, displayName: "Member", role, joinedAt: new Date().toISOString() });
  return true;
}

export async function removeGroupMember(token: string, groupId: string, memberAccountId: string): Promise<boolean> {
  const session = getSession(token);
  if (!session) return false;
  return persistence.removeGroupMember(groupId, memberAccountId);
}

export async function sendOfflineMessage(token: string, toAccountId: string, message: string): Promise<OfflineMessage | undefined> {
  const session = getSession(token);
  if (!session) return undefined;
  return persistence.sendOfflineMessage({ fromAccountId: session.accountId, fromDisplayName: session.displayName, toAccountId, message, read: false });
}

export async function listOfflineMessages(token: string, limit: number = 50): Promise<OfflineMessage[]> {
  const session = getSession(token);
  if (!session) return [];
  return persistence.listOfflineMessages(session.accountId, limit);
}

export async function markMessageRead(token: string, messageId: string): Promise<boolean> {
  const session = getSession(token);
  if (!session) return false;
  return persistence.markOfflineMessageRead(messageId, session.accountId);
}

export async function getAvatarProfile(token: string): Promise<AvatarProfile | undefined> {
  const session = getSession(token);
  if (!session) return undefined;
  return persistence.getAvatarProfile(session.accountId);
}

export async function saveAvatarProfile(token: string, bio: string, imageUrl: string | null): Promise<AvatarProfile | undefined> {
  const session = getSession(token);
  if (!session) return undefined;
  const existing = await persistence.getAvatarProfile(session.accountId);
  if (existing) {
    return persistence.saveAvatarProfile({ ...existing, bio, imageUrl, updatedAt: new Date().toISOString() });
  }
  return persistence.saveAvatarProfile({ accountId: session.accountId, bio, imageUrl, worldVisits: 0, totalTime: 0, createdAt: new Date().toISOString(), updatedAt: new Date().toISOString() });
}
