package com.vibelife.spigot.auth;

import com.vibelife.spigot.VibeLifePlugin;
import com.vibelife.spigot.parcels.AccountIdCache;
import com.google.gson.JsonObject;
import org.bukkit.entity.Player;
import org.bukkit.event.EventHandler;
import org.bukkit.event.EventPriority;
import org.bukkit.event.Listener;
import org.bukkit.event.player.PlayerJoinEvent;
import org.bukkit.event.player.PlayerQuitEvent;

import java.io.ByteArrayOutputStream;
import java.io.DataOutputStream;
import java.io.IOException;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Handles player join/quit events and bridges to the Fastify sidecar auth system.
 * On join: calls mc-login endpoint, sends session token to Fabric mod via plugin channel.
 * On quit: cleans up session.
 */
public class LoginListener implements Listener {

    private final VibeLifePlugin plugin;

    /** MC UUID -> VibeLife session token for online players */
    private final Map<String, String> sessionTokens = new ConcurrentHashMap<>();

    public LoginListener(VibeLifePlugin plugin) {
        this.plugin = plugin;
    }

    @EventHandler(priority = EventPriority.NORMAL)
    public void onPlayerJoin(PlayerJoinEvent event) {
        Player player = event.getPlayer();
        String mcUuid = player.getUniqueId().toString();
        String mcUsername = player.getName();
        String worldName = player.getWorld().getName();
        String regionId = plugin.getRegionId(worldName);

        plugin.getSidecarClient().mcLogin(mcUuid, mcUsername, regionId)
                .thenAccept(response -> {
                    if (response.has("session")) {
                        JsonObject session = response.getAsJsonObject("session");
                        String token = session.get("token").getAsString();
                        String accountId = session.get("accountId").getAsString();
                        sessionTokens.put(mcUuid, token);
                        AccountIdCache.put(mcUuid, accountId);

                        // Send session token to Fabric mod via plugin channel
                        sendTokenToClient(player, token);

                        // Set presence online
                        plugin.getSidecarClient().post("/api/presence/online", Map.of(
                                "accountId", accountId,
                                "displayName", mcUsername,
                                "regionId", regionId
                        ));

                        boolean isNew = response.has("isNewAccount") && response.get("isNewAccount").getAsBoolean();
                        if (isNew) {
                            plugin.getServer().getScheduler().runTask(plugin, () ->
                                    player.sendMessage("\u00a7a[VibeLife] \u00a7fWelcome! A new account has been created for you.")
                            );
                        } else {
                            plugin.getServer().getScheduler().runTask(plugin, () ->
                                    player.sendMessage("\u00a7a[VibeLife] \u00a7fWelcome back!")
                            );
                        }
                    } else {
                        plugin.getLogger().warning("mc-login failed for " + mcUsername + ": " + response);
                    }
                })
                .exceptionally(ex -> {
                    plugin.getLogger().warning("Sidecar unreachable for " + mcUsername + ": " + ex.getMessage());
                    return null;
                });
    }

    @EventHandler(priority = EventPriority.NORMAL)
    public void onPlayerQuit(PlayerQuitEvent event) {
        String mcUuid = event.getPlayer().getUniqueId().toString();
        String accountId = AccountIdCache.get(mcUuid);

        // Set presence offline
        if (accountId != null) {
            plugin.getSidecarClient().post("/api/presence/offline", Map.of("accountId", accountId));
        }

        sessionTokens.remove(mcUuid);
        AccountIdCache.remove(mcUuid);
    }

    /**
     * Get the VibeLife session token for an online player, or null.
     */
    public String getSessionToken(String mcUuid) {
        return sessionTokens.get(mcUuid);
    }

    /**
     * Send the session token to the Fabric mod via plugin message channel.
     */
    private void sendTokenToClient(Player player, String token) {
        String channel = plugin.getConfig().getString("channel", "vibelife:main");
        try {
            ByteArrayOutputStream bytes = new ByteArrayOutputStream();
            DataOutputStream out = new DataOutputStream(bytes);
            out.writeUTF("session");
            out.writeUTF(token);
            player.sendPluginMessage(plugin, channel, bytes.toByteArray());
        } catch (IOException e) {
            plugin.getLogger().warning("Failed to send token to " + player.getName() + ": " + e.getMessage());
        }
    }
}
