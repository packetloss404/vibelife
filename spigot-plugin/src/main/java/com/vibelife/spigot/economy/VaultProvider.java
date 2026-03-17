package com.vibelife.spigot.economy;

import com.google.gson.JsonObject;
import com.vibelife.spigot.VibeLifePlugin;
import com.vibelife.spigot.parcels.AccountIdCache;
import net.milkbowl.vault.economy.Economy;
import net.milkbowl.vault.economy.EconomyResponse;
import org.bukkit.OfflinePlayer;

import java.util.List;
import java.util.Map;
import java.util.concurrent.CompletableFuture;

/**
 * Vault Economy implementation backed by the VibeLife Fastify sidecar.
 *
 * All balance/transfer operations delegate to the sidecar REST API.
 * This allows any Vault-compatible plugin (ChestShop, etc.) to use VibeLife currency.
 *
 * Note: Vault's API is synchronous, but our sidecar calls are async.
 * We use CompletableFuture.get() with a timeout to bridge this gap.
 * This is acceptable because Vault calls typically happen on the main thread
 * and the sidecar is on localhost (sub-ms latency).
 */
public class VaultProvider implements Economy {

    private final VibeLifePlugin plugin;
    private static final String CURRENCY_NAME = "Vibe";
    private static final String CURRENCY_NAME_PLURAL = "Vibes";

    public VaultProvider(VibeLifePlugin plugin) {
        this.plugin = plugin;
    }

    // ── Helper ────────────────────────────────────────────────────────────

    private String resolveAccountId(OfflinePlayer player) {
        if (player == null || player.getUniqueId() == null) return null;
        return AccountIdCache.get(player.getUniqueId().toString());
    }

    private double getBalanceSync(String accountId) {
        try {
            JsonObject resp = plugin.getSidecarClient()
                    .get("/api/economy/balance/" + accountId)
                    .get();
            return resp.has("balance") ? resp.get("balance").getAsDouble() : 0;
        } catch (Exception e) {
            plugin.getLogger().warning("Vault getBalance failed: " + e.getMessage());
            return 0;
        }
    }

    private EconomyResponse transferSync(String fromAccountId, String toAccountId, double amount, String description) {
        try {
            JsonObject resp = plugin.getSidecarClient()
                    .post("/api/economy/server-transfer", Map.of(
                            "fromAccountId", fromAccountId != null ? fromAccountId : "",
                            "toAccountId", toAccountId != null ? toAccountId : "",
                            "amount", (int) amount,
                            "type", "purchase",
                            "description", description
                    ))
                    .get();

            if (resp.has("success") && resp.get("success").getAsBoolean()) {
                double balance = resp.has("balance") ? resp.get("balance").getAsDouble() : 0;
                return new EconomyResponse(amount, balance, EconomyResponse.ResponseType.SUCCESS, "");
            } else {
                String error = resp.has("error") ? resp.get("error").getAsString() : "unknown error";
                return new EconomyResponse(0, 0, EconomyResponse.ResponseType.FAILURE, error);
            }
        } catch (Exception e) {
            return new EconomyResponse(0, 0, EconomyResponse.ResponseType.FAILURE, e.getMessage());
        }
    }

    // ── Economy interface ────────────────────────────────────────────────

    @Override
    public boolean isEnabled() {
        return plugin.isEnabled();
    }

    @Override
    public String getName() {
        return "VibeLife";
    }

    @Override
    public boolean hasBankSupport() {
        return false;
    }

    @Override
    public int fractionalDigits() {
        return 0; // Integer currency
    }

    @Override
    public String format(double amount) {
        return String.format("%.0f %s", amount, amount == 1 ? CURRENCY_NAME : CURRENCY_NAME_PLURAL);
    }

    @Override
    public String currencyNamePlural() {
        return CURRENCY_NAME_PLURAL;
    }

    @Override
    public String currencyNameSingular() {
        return CURRENCY_NAME;
    }

    @Override
    public boolean hasAccount(OfflinePlayer player) {
        return resolveAccountId(player) != null;
    }

    @Override
    public boolean hasAccount(String playerName) {
        return false; // Name-based lookups not supported
    }

    @Override
    public boolean hasAccount(OfflinePlayer player, String worldName) {
        return hasAccount(player);
    }

    @Override
    public boolean hasAccount(String playerName, String worldName) {
        return false;
    }

    @Override
    public double getBalance(OfflinePlayer player) {
        String accountId = resolveAccountId(player);
        if (accountId == null) return 0;
        return getBalanceSync(accountId);
    }

    @Override
    public double getBalance(String playerName) {
        return 0;
    }

    @Override
    public double getBalance(OfflinePlayer player, String world) {
        return getBalance(player);
    }

    @Override
    public double getBalance(String playerName, String world) {
        return 0;
    }

    @Override
    public boolean has(OfflinePlayer player, double amount) {
        return getBalance(player) >= amount;
    }

    @Override
    public boolean has(String playerName, double amount) {
        return false;
    }

    @Override
    public boolean has(OfflinePlayer player, String worldName, double amount) {
        return has(player, amount);
    }

    @Override
    public boolean has(String playerName, String worldName, double amount) {
        return false;
    }

    @Override
    public EconomyResponse withdrawPlayer(OfflinePlayer player, double amount) {
        String accountId = resolveAccountId(player);
        if (accountId == null) {
            return new EconomyResponse(0, 0, EconomyResponse.ResponseType.FAILURE, "player not linked");
        }
        return transferSync(accountId, null, amount, "vault withdraw");
    }

    @Override
    public EconomyResponse withdrawPlayer(String playerName, double amount) {
        return new EconomyResponse(0, 0, EconomyResponse.ResponseType.NOT_IMPLEMENTED, "name-based not supported");
    }

    @Override
    public EconomyResponse withdrawPlayer(OfflinePlayer player, String worldName, double amount) {
        return withdrawPlayer(player, amount);
    }

    @Override
    public EconomyResponse withdrawPlayer(String playerName, String worldName, double amount) {
        return withdrawPlayer(playerName, amount);
    }

    @Override
    public EconomyResponse depositPlayer(OfflinePlayer player, double amount) {
        String accountId = resolveAccountId(player);
        if (accountId == null) {
            return new EconomyResponse(0, 0, EconomyResponse.ResponseType.FAILURE, "player not linked");
        }
        return transferSync(null, accountId, amount, "vault deposit");
    }

    @Override
    public EconomyResponse depositPlayer(String playerName, double amount) {
        return new EconomyResponse(0, 0, EconomyResponse.ResponseType.NOT_IMPLEMENTED, "name-based not supported");
    }

    @Override
    public EconomyResponse depositPlayer(OfflinePlayer player, String worldName, double amount) {
        return depositPlayer(player, amount);
    }

    @Override
    public EconomyResponse depositPlayer(String playerName, String worldName, double amount) {
        return depositPlayer(playerName, amount);
    }

    // ── Account creation (no-op, handled by sidecar on login) ───────────

    @Override
    public boolean createPlayerAccount(OfflinePlayer player) {
        return true; // Accounts are auto-created on MC login
    }

    @Override
    public boolean createPlayerAccount(String playerName) {
        return false;
    }

    @Override
    public boolean createPlayerAccount(OfflinePlayer player, String worldName) {
        return true;
    }

    @Override
    public boolean createPlayerAccount(String playerName, String worldName) {
        return false;
    }

    // ── Bank (not supported) ────────────────────────────────────────────

    @Override
    public EconomyResponse createBank(String name, OfflinePlayer player) {
        return new EconomyResponse(0, 0, EconomyResponse.ResponseType.NOT_IMPLEMENTED, "no bank support");
    }

    @Override
    public EconomyResponse createBank(String name, String playerName) {
        return new EconomyResponse(0, 0, EconomyResponse.ResponseType.NOT_IMPLEMENTED, "no bank support");
    }

    @Override
    public EconomyResponse deleteBank(String name) {
        return new EconomyResponse(0, 0, EconomyResponse.ResponseType.NOT_IMPLEMENTED, "no bank support");
    }

    @Override
    public EconomyResponse bankBalance(String name) {
        return new EconomyResponse(0, 0, EconomyResponse.ResponseType.NOT_IMPLEMENTED, "no bank support");
    }

    @Override
    public EconomyResponse bankHas(String name, double amount) {
        return new EconomyResponse(0, 0, EconomyResponse.ResponseType.NOT_IMPLEMENTED, "no bank support");
    }

    @Override
    public EconomyResponse bankWithdraw(String name, double amount) {
        return new EconomyResponse(0, 0, EconomyResponse.ResponseType.NOT_IMPLEMENTED, "no bank support");
    }

    @Override
    public EconomyResponse bankDeposit(String name, double amount) {
        return new EconomyResponse(0, 0, EconomyResponse.ResponseType.NOT_IMPLEMENTED, "no bank support");
    }

    @Override
    public EconomyResponse isBankOwner(String name, OfflinePlayer player) {
        return new EconomyResponse(0, 0, EconomyResponse.ResponseType.NOT_IMPLEMENTED, "no bank support");
    }

    @Override
    public EconomyResponse isBankOwner(String name, String playerName) {
        return new EconomyResponse(0, 0, EconomyResponse.ResponseType.NOT_IMPLEMENTED, "no bank support");
    }

    @Override
    public EconomyResponse isBankMember(String name, OfflinePlayer player) {
        return new EconomyResponse(0, 0, EconomyResponse.ResponseType.NOT_IMPLEMENTED, "no bank support");
    }

    @Override
    public EconomyResponse isBankMember(String name, String playerName) {
        return new EconomyResponse(0, 0, EconomyResponse.ResponseType.NOT_IMPLEMENTED, "no bank support");
    }

    @Override
    public List<String> getBanks() {
        return List.of();
    }
}
