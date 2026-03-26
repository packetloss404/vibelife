package com.packetcraft.fabric;

import com.packetcraft.fabric.keybind.KeybindManager;
import com.packetcraft.fabric.network.PluginChannelHandler;
import com.packetcraft.fabric.network.SidecarApi;
import net.fabricmc.api.ClientModInitializer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * PacketCraft Fabric client mod entry point.
 *
 * Registers keybinds, plugin channel handler, and initializes the sidecar API client.
 * All custom UI screens (economy, marketplace, social, etc.) are opened via keybinds.
 */
public class PacketCraftClient implements ClientModInitializer {

    public static final String MOD_ID = "packetcraft";
    public static final Logger LOGGER = LoggerFactory.getLogger(MOD_ID);

    private static PacketCraftClient instance;
    private SidecarApi sidecarApi;
    private String sessionToken;

    @Override
    public void onInitializeClient() {
        instance = this;

        sidecarApi = new SidecarApi("http://localhost:3000");

        PluginChannelHandler.register();
        KeybindManager.register();

        LOGGER.info("PacketCraft client mod initialized");
    }

    public static PacketCraftClient getInstance() {
        return instance;
    }

    public SidecarApi getSidecarApi() {
        return sidecarApi;
    }

    public String getSessionToken() {
        return sessionToken;
    }

    public void setSessionToken(String token) {
        this.sessionToken = token;
        LOGGER.info("Session token received from server");
    }
}
