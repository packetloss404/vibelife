package com.vibelife.fabric.keybind;

import com.vibelife.fabric.VibeLifeClient;
import com.vibelife.fabric.screen.AchievementsScreen;
import com.vibelife.fabric.screen.EconomyScreen;
import com.vibelife.fabric.screen.EventsScreen;
import com.vibelife.fabric.screen.MarketplaceScreen;
import com.vibelife.fabric.screen.SocialScreen;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.fabricmc.fabric.api.client.keybinding.v1.KeyBindingHelper;
import net.minecraft.client.option.KeyBinding;
import net.minecraft.client.util.InputUtil;
import org.lwjgl.glfw.GLFW;

/**
 * Registers VibeLife keybinds for opening custom GUI screens.
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
                "key.vibelife.economy", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_V, "category.vibelife"
        ));
        socialKey = KeyBindingHelper.registerKeyBinding(new KeyBinding(
                "key.vibelife.social", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_N, "category.vibelife"
        ));
        marketplaceKey = KeyBindingHelper.registerKeyBinding(new KeyBinding(
                "key.vibelife.marketplace", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_M, "category.vibelife"
        ));
        achievementsKey = KeyBindingHelper.registerKeyBinding(new KeyBinding(
                "key.vibelife.achievements", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_J, "category.vibelife"
        ));
        eventsKey = KeyBindingHelper.registerKeyBinding(new KeyBinding(
                "key.vibelife.events", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_K, "category.vibelife"
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

        VibeLifeClient.LOGGER.info("Keybinds registered: V=Economy, N=Social, M=Marketplace, J=Achievements, K=Events");
    }
}
