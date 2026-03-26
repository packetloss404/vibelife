package com.packetcraft.fabric.hud;

import com.packetcraft.fabric.PacketCraftClient;

/**
 * Renders a Minecraft-style toast notification when a PacketCraft achievement is unlocked.
 *
 * TODO: Implement actual toast rendering using MinecraftClient.getInstance().getToastManager()
 * For now, logs the achievement and sends a chat message.
 */
public class AchievementToast {

    public static void show(String name, String description) {
        PacketCraftClient.LOGGER.info("Achievement unlocked: " + name + " - " + description);

        // TODO: Create a proper Toast implementation
        // MinecraftClient client = MinecraftClient.getInstance();
        // client.getToastManager().add(new PacketCraftAchievementToast(name, description));

        // For now, send as chat message
        var client = net.minecraft.client.MinecraftClient.getInstance();
        if (client.player != null) {
            client.player.sendMessage(
                    net.minecraft.text.Text.literal("\u00a76\u00a7l[Achievement] \u00a7e" + name + " \u00a77- " + description),
                    false
            );
        }
    }
}
