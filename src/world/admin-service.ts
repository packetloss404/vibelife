import {
  persistence,
  getSession,
  isAdminSession,
  type Parcel,
  type Ban,
  type AuditLog,
  type RegionNotice
} from "./_shared-state.js";
import { appendAuditLog } from "./_shared-state.js";

export async function adminAssignParcel(token: string, parcelId: string, ownerAccountId: string | null): Promise<Parcel | undefined> {
  const session = getSession(token);

  if (!isAdminSession(session)) {
    return undefined;
  }

  return persistence.reassignParcel(parcelId, ownerAccountId);
}

export async function adminDeleteRegionObject(token: string, objectId: string): Promise<boolean> {
  const session = getSession(token);

  if (!isAdminSession(session)) {
    return false;
  }

  return persistence.adminDeleteRegionObject(objectId);
}

export { appendAuditLog };

export async function listAuditLogs(token: string, limit = 50): Promise<AuditLog[] | undefined> {
  const session = getSession(token);

  if (!isAdminSession(session)) {
    return undefined;
  }

  return persistence.listAuditLogs(limit);
}

export async function banAccount(token: string, accountId: string, reason: string, expiresAt: string | null): Promise<Ban | undefined> {
  const session = getSession(token);
  if (!session || session.role !== "admin") return undefined;
  return persistence.banAccount({ accountId, bannedBy: session.accountId, reason, expiresAt });
}

export async function unbanAccount(token: string, accountId: string): Promise<boolean> {
  const session = getSession(token);
  if (!session || session.role !== "admin") return false;
  return persistence.unbanAccount(accountId);
}

export async function getActiveBan(token: string): Promise<Ban | undefined> {
  const session = getSession(token);
  if (!session) return undefined;
  return persistence.getActiveBan(session.accountId);
}

export async function listRegionNotices(token: string): Promise<RegionNotice[]> {
  const session = getSession(token);
  if (!session) return [];
  return persistence.listRegionNotices(session.regionId);
}

export async function createRegionNotice(token: string, message: string, parcelId: string | null = null): Promise<RegionNotice | undefined> {
  const session = getSession(token);
  if (!session) return undefined;
  return persistence.createRegionNotice({ regionId: session.regionId, parcelId, message, createdBy: session.accountId });
}

export async function deleteRegionNotice(token: string, noticeId: string): Promise<boolean> {
  const session = getSession(token);
  if (!session) return false;
  return persistence.deleteRegionNotice(noticeId, session.regionId);
}
