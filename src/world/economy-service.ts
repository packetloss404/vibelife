import {
  persistence,
  getSession,
  type CurrencyTransaction,
  type Asset
} from "./_shared-state.js";

export async function getCurrencyBalance(token: string): Promise<number> {
  const session = getSession(token);
  if (!session) return 0;
  return persistence.getCurrencyBalance(session.accountId);
}

export async function sendCurrency(token: string, toAccountId: string, amount: number, description: string): Promise<number | undefined> {
  const session = getSession(token);
  if (!session || amount <= 0) return undefined;
  const balance = await persistence.getCurrencyBalance(session.accountId);
  if (balance < amount) return undefined;
  return persistence.addCurrency({ fromAccountId: session.accountId, toAccountId, amount, type: "gift", description });
}

export async function listCurrencyTransactions(token: string, limit: number = 20): Promise<CurrencyTransaction[]> {
  const session = getSession(token);
  if (!session) return [];
  return persistence.listCurrencyTransactions(session.accountId, limit);
}

export async function listAssets(token: string): Promise<Asset[]> {
  const session = getSession(token);
  if (!session) return [];
  return persistence.listAssets(session.accountId);
}

export async function createAsset(token: string, name: string, description: string, assetType: string, url: string, thumbnailUrl: string | null, price: number): Promise<Asset | undefined> {
  const session = getSession(token);
  if (!session) return undefined;
  return persistence.createAsset({ accountId: session.accountId, name, description, assetType, url, thumbnailUrl, price });
}

export async function deleteAsset(token: string, assetId: string): Promise<boolean> {
  const session = getSession(token);
  if (!session) return false;
  return persistence.deleteAsset(assetId, session.accountId);
}
