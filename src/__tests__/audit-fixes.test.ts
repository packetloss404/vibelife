import { beforeEach, describe, expect, it } from "vitest";
import { attackEnemy, getEnemiesInRegion } from "../world/enemy-service.js";
import { moveAvatar } from "../world/avatar-service.js";
import { issueIdentityToken, verifyIdentityToken } from "../world/federation-service.js";
import { createTestSession, resetWorldStore, TEST_REGION_ID } from "./helpers.js";

describe("audit fix regressions", () => {
  beforeEach(async () => {
    await resetWorldStore();
  });

  it("issues federated identity tokens that verify locally", async () => {
    const { token } = await createTestSession("FederatedUser");

    const identityToken = issueIdentityToken(token);

    expect(identityToken).toBeDefined();
    expect(identityToken?.issuedAt).toBeDefined();
    expect(identityToken?.expiresAt).toBeDefined();
    expect(verifyIdentityToken(identityToken!)).toEqual({ valid: true });
  });

  it("attacks enemies with the session token rather than an account id", async () => {
    const { token } = await createTestSession("CombatUser");
    const [enemy] = getEnemiesInRegion(TEST_REGION_ID);

    expect(enemy).toBeDefined();

    await moveAvatar(token, enemy.x, enemy.z, enemy.y);

    const result = attackEnemy(token, enemy.id, "melee");

    expect(result).not.toEqual({ error: "invalid_session" });
    expect("error" in result && result.error === "avatar_not_found").toBe(false);
  });
});
