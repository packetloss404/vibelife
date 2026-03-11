import {
  persistence,
  getSession,
  isAdminSession,
  type Parcel
} from "./_shared-state.js";

export async function listParcels(regionId: string): Promise<Parcel[]> {
  return persistence.listParcels(regionId);
}

export async function claimParcel(token: string, parcelId: string): Promise<Parcel | undefined> {
  const session = getSession(token);

  if (!session) {
    return undefined;
  }

  return persistence.claimParcel(parcelId, session.accountId);
}

export async function releaseParcel(token: string, parcelId: string): Promise<Parcel | undefined> {
  const session = getSession(token);

  if (!session) {
    return undefined;
  }

  return persistence.releaseParcel(parcelId, session.accountId);
}

export async function addParcelCollaborator(token: string, parcelId: string, collaboratorAccountId: string): Promise<Parcel | undefined> {
  const session = getSession(token);

  if (!session) {
    return undefined;
  }

  const parcel = (await persistence.listParcels(session.regionId)).find((entry) => entry.id === parcelId);

  if (!parcel) {
    return undefined;
  }

  if (parcel.ownerAccountId !== session.accountId && !isAdminSession(session)) {
    return undefined;
  }

  return persistence.addParcelCollaborator(parcelId, parcel.ownerAccountId ?? session.accountId, collaboratorAccountId);
}

export async function removeParcelCollaborator(token: string, parcelId: string, collaboratorAccountId: string): Promise<Parcel | undefined> {
  const session = getSession(token);

  if (!session) {
    return undefined;
  }

  const parcel = (await persistence.listParcels(session.regionId)).find((entry) => entry.id === parcelId);

  if (!parcel) {
    return undefined;
  }

  if (parcel.ownerAccountId !== session.accountId && !isAdminSession(session)) {
    return undefined;
  }

  return persistence.removeParcelCollaborator(parcelId, parcel.ownerAccountId ?? session.accountId, collaboratorAccountId);
}

export async function transferParcel(token: string, parcelId: string, ownerAccountId: string | null): Promise<Parcel | undefined> {
  const session = getSession(token);

  if (!session) {
    return undefined;
  }

  const parcel = (await persistence.listParcels(session.regionId)).find((entry) => entry.id === parcelId);

  if (!parcel) {
    return undefined;
  }

  if (parcel.ownerAccountId !== session.accountId && !isAdminSession(session)) {
    return undefined;
  }

  return persistence.reassignParcel(parcelId, ownerAccountId);
}
