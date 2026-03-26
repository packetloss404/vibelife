# Sprint 0: Bug Squash

**Duration:** 3 days
**Goal:** Fix all known bugs before adding new features.

---

## Bug 1: Fabric API URLs Incorrect

**Component:** `fabric-mod/src/main/java/com/vibelife/fabric/network/SidecarApi.java`

**Problem:** The `SidecarApi` convenience methods hardcode API paths that may not match
the current sidecar route structure. For example, `getBalance()` calls
`/api/economy/balance` but the sidecar may expect an account ID parameter. The
`EconomyScreen.sendCurrency()` method calls `/api/currency/send` which does not exist --
the actual endpoint is `/api/economy/send` or similar.

**Fix:**
- Audit every `SidecarApi` convenience method against `src/routes/*.ts`
- Fix all mismatched paths
- Add a `delete(String path)` method (currently missing, needed for marketplace delisting)
- Add a `put(String path, Object body)` method for update operations

---

## Bug 2: VaultProvider Blocking the Main Thread

**Component:** `paper-plugin/src/main/java/com/vibelife/paper/economy/VaultProvider.java`

**Problem:** `getBalanceSync()` and `transferSync()` call `CompletableFuture.get()`
without a timeout. If the sidecar is slow or unreachable, this blocks the Paper main
thread indefinitely, freezing the server.

**Fix:**
- Add a 3-second timeout to all `.get()` calls: `.get(3, TimeUnit.SECONDS)`
- Catch `TimeoutException` and return a sensible default (0 balance, FAILURE response)
- Log timeouts at WARNING level so operators can diagnose connectivity issues

---

## Bug 3: Extract BasePacketScreen

**Component:** `fabric-mod/src/main/java/com/vibelife/fabric/screen/*.java`

**Problem:** All 5 Fabric screens (`EconomyScreen`, `SocialScreen`, `MarketplaceScreen`,
`AchievementsScreen`, `EventsScreen`) duplicate boilerplate: background rendering, close
button, title drawing, `shouldPause() = false`, and `fetchData()` pattern with
`VibeLifeClient.getInstance().getSidecarApi()`.

**Fix:**
- Create `BasePacketScreen extends Screen` with:
  - Standard background rendering
  - Close button in bottom center
  - Title rendering with PacketCraft gold styling
  - `shouldPause()` returning `false`
  - Protected `api()` helper returning `SidecarApi` instance
  - Abstract `fetchData()` method called from `init()`
- Refactor all 5 screens to extend `BasePacketScreen`
- Rename package from `com.vibelife.fabric` to `com.packetcraft.fabric` (branding)

---

## Bug 4: Achievement Toast Uses Chat Instead of Toast API

**Component:** `fabric-mod/src/main/java/com/vibelife/fabric/hud/AchievementToast.java`

**Problem:** The `show()` method sends a chat message instead of using Minecraft's
built-in toast notification system (`ToastManager`). This makes achievements
indistinguishable from chat spam.

**Fix:**
- Implement a proper `SystemToast` or custom `Toast` subclass
- Use `MinecraftClient.getInstance().getToastManager().add(toast)` to display
- Include an icon (gold star or trophy) and the achievement name/description
- Keep the chat message as a fallback if toast rendering fails

---

## Bug 5: SidecarClient Missing DELETE Method

**Component:** `paper-plugin/src/main/java/com/vibelife/paper/bridge/SidecarClient.java`

**Problem:** The `SidecarClient` only has `post()`, `get()`, and `postWithToken()`.
Several sidecar endpoints use DELETE (e.g., removing marketplace listings, unfriending,
leaving guilds). The Paper plugin cannot call these endpoints.

**Fix:**
- Add `delete(String path)` method using `HttpRequest.Builder.DELETE()`
- Add `deleteWithToken(String path, String token)` for player-initiated deletions
- Add `put(String path, Object body)` and `putWithToken()` for update operations
- Follow the same async pattern and error logging as existing methods

---

## Verification

After all fixes:
- [ ] `./gradlew build` succeeds in both `paper-plugin/` and `fabric-mod/`
- [ ] `npm run check` passes in root
- [ ] Manual test: open each Fabric screen, verify no errors in log
- [ ] Manual test: Vault balance check does not freeze server when sidecar is down
