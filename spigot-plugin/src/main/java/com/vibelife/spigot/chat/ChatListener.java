package com.vibelife.spigot.chat;

import com.vibelife.spigot.VibeLifePlugin;
import com.vibelife.spigot.parcels.AccountIdCache;
import org.bukkit.entity.Player;
import org.bukkit.event.EventHandler;
import org.bukkit.event.EventPriority;
import org.bukkit.event.Listener;
import org.bukkit.event.player.AsyncPlayerChatEvent;

import java.util.Map;

/**
 * Forwards MC chat messages to the Fastify sidecar for:
 *   - Chat history persistence (viewable in region history)
 *   - Achievement tracking (onChatMessage stat increment)
 *
 * Does NOT modify the chat message itself — MC handles delivery.
 * This is purely for sidecar data persistence.
 */
public class ChatListener implements Listener {

    private final VibeLifePlugin plugin;

    public ChatListener(VibeLifePlugin plugin) {
        this.plugin = plugin;
    }

    @EventHandler(priority = EventPriority.MONITOR, ignoreCancelled = true)
    public void onChat(AsyncPlayerChatEvent event) {
        Player player = event.getPlayer();
        String mcUuid = player.getUniqueId().toString();
        String accountId = AccountIdCache.get(mcUuid);

        if (accountId == null) return; // Not logged in to VibeLife

        String regionId = plugin.getRegionId(player.getWorld().getName());
        String message = event.getMessage();

        // Fire-and-forget — don't block chat delivery
        plugin.getSidecarClient().post("/api/chat/persist", Map.of(
                "accountId", accountId,
                "displayName", player.getName(),
                "regionId", regionId,
                "message", message
        )).exceptionally(ex -> {
            plugin.getLogger().fine("Chat persist failed: " + ex.getMessage());
            return null;
        });
    }
}
