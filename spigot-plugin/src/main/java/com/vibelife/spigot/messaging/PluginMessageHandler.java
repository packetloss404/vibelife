package com.vibelife.spigot.messaging;

import com.vibelife.spigot.VibeLifePlugin;
import org.bukkit.entity.Player;
import org.bukkit.plugin.messaging.PluginMessageListener;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.io.IOException;

/**
 * Handles plugin message channel communication between Spigot and Fabric mod.
 *
 * Protocol:
 *   - First field is always a UTF string identifying the message type
 *   - Remaining fields depend on the type
 *
 * Incoming (from Fabric mod):
 *   - "ping" -> respond with "pong"
 *
 * Outgoing (to Fabric mod):
 *   - "session" + token -> session token after auth
 *   - "achievement" + id + name + description -> achievement unlock notification
 *   - "balance" + amount -> currency balance update
 *   - "event_start" + eventId + eventName -> event started notification
 *   - "event_end" + eventId -> event ended notification
 */
public class PluginMessageHandler implements PluginMessageListener {

    private final VibeLifePlugin plugin;

    public PluginMessageHandler(VibeLifePlugin plugin) {
        this.plugin = plugin;
    }

    @Override
    public void onPluginMessageReceived(String channel, Player player, byte[] message) {
        String expectedChannel = plugin.getConfig().getString("channel", "vibelife:main");
        if (!channel.equals(expectedChannel)) return;

        try {
            DataInputStream in = new DataInputStream(new ByteArrayInputStream(message));
            String type = in.readUTF();

            switch (type) {
                case "ping" -> sendToPlayer(player, "pong");
                default -> plugin.getLogger().fine("Unknown plugin message type: " + type);
            }
        } catch (IOException e) {
            plugin.getLogger().warning("Failed to read plugin message from " + player.getName() + ": " + e.getMessage());
        }
    }

    /**
     * Send a simple string message to a player's Fabric mod.
     */
    public void sendToPlayer(Player player, String... fields) {
        String channel = plugin.getConfig().getString("channel", "vibelife:main");
        try {
            ByteArrayOutputStream bytes = new ByteArrayOutputStream();
            DataOutputStream out = new DataOutputStream(bytes);
            for (String field : fields) {
                out.writeUTF(field);
            }
            player.sendPluginMessage(plugin, channel, bytes.toByteArray());
        } catch (IOException e) {
            plugin.getLogger().warning("Failed to send plugin message to " + player.getName() + ": " + e.getMessage());
        }
    }

    /**
     * Send an achievement unlock notification to a player's Fabric mod.
     */
    public void sendAchievementUnlock(Player player, String achievementId, String name, String description) {
        sendToPlayer(player, "achievement", achievementId, name, description);
    }

    /**
     * Send a currency balance update to a player's Fabric mod.
     */
    public void sendBalanceUpdate(Player player, String amount) {
        sendToPlayer(player, "balance", amount);
    }
}
