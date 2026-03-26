package com.packetcraft.fabric.keybind;

import com.packetcraft.fabric.PacketCraftClient;
import com.packetcraft.fabric.screen.AchievementsScreen;
import com.packetcraft.fabric.screen.EconomyScreen;
import com.packetcraft.fabric.screen.EventsScreen;
import com.packetcraft.fabric.screen.MarketplaceScreen;
import com.packetcraft.fabric.screen.SocialScreen;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.fabricmc.fabric.api.client.keybinding.v1.KeyBindingHelper;
import net.minecraft.client.option.KeyBinding;
import net.minecraft.client.util.InputUtil;
import org.lwjgl.glfw.GLFW;

/**
 * Registers PacketCraft keybinds for opening custom GUI screens.
 *
 * Default bindings:
 *   V - Economy (balance, send, transactions)
 *   N - Social (friends, groups, messages)
 *   M - Marketplace (browse, buy, sell)
 *   J - Achievements (progress, challenges)
 *   K - Events (calendar, RSVP)
 */
public class KeybindManager {

    private static KeyBinding economyKey;
    private static KeyBinding socialKey;
    private static KeyBinding marketplaceKey;
    private static KeyBinding achievementsKey;
    private static KeyBinding eventsKey;

    public static void register() {
        economyKey = KeyBindingHelper.registerKeyBinding(new KeyBinding(
                "key.packetcraft.economy", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_V, "category.packetcraft"
        ));
        socialKey = KeyBindingHelper.registerKeyBinding(new KeyBinding(
                "key.packetcraft.social", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_N, "category.packetcraft"
        ));
        marketplaceKey = KeyBindingHelper.registerKeyBinding(new KeyBinding(
                "key.packetcraft.marketplace", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_M, "category.packetcraft"
        ));
        achievementsKey = KeyBindingHelper.registerKeyBinding(new KeyBinding(
                "key.packetcraft.achievements", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_J, "category.packetcraft"
        ));
        eventsKey = KeyBindingHelper.registerKeyBinding(new KeyBinding(
                "key.packetcraft.events", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_K, "category.packetcraft"
        ));

        ClientTickEvents.END_CLIENT_TICK.register(client -> {
            if (client.player == null) return;

            // TODO: Replace these with actual screen opens once screens are implemented
            if (economyKey.wasPressed()) {
                client.setScreen(new EconomyScreen());
            }
            if (socialKey.wasPressed()) {
                client.setScreen(new SocialScreen());
            }
            if (marketplaceKey.wasPressed()) {
                client.setScreen(new MarketplaceScreen());
            }
            if (achievementsKey.wasPressed()) {
                client.setScreen(new AchievementsScreen());
            }
            if (eventsKey.wasPressed()) {
                client.setScreen(new EventsScreen());
            }
        });

        PacketCraftClient.LOGGER.info("Keybinds registered: V=Economy, N=Social, M=Marketplace, J=Achievements, K=Events");
    }
}
