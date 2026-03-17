package com.vibelife.fabric;

import com.vibelife.fabric.keybind.KeybindManager;
import com.vibelife.fabric.network.PluginChannelHandler;
import com.vibelife.fabric.network.SidecarApi;
import net.fabricmc.api.ClientModInitializer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * VibeLife Fabric client mod entry point.
 *
 * Registers keybinds, plugin channel handler, and initializes the sidecar API client.
 * All custom UI screens (economy, marketplace, social, etc.) are opened via keybinds.
 */
public class VibeLifeClient implements ClientModInitializer {

    public static final String MOD_ID = "vibelife";
    public static final Logger LOGGER = LoggerFactory.getLogger(MOD_ID);

    private static VibeLifeClient instance;
    private SidecarApi sidecarApi;
    private String sessionToken;

    @Override
    public void onInitializeClient() {
        instance = this;

        sidecarApi = new SidecarApi("http://localhost:3000");

        PluginChannelHandler.register();
        KeybindManager.register();

        LOGGER.info("VibeLife client mod initialized");
    }

    public static VibeLifeClient getInstance() {
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
