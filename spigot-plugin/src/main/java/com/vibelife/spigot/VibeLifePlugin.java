package com.vibelife.spigot;

import com.vibelife.spigot.achievements.AchievementHook;
import com.vibelife.spigot.auth.LoginListener;
import com.vibelife.spigot.bridge.SidecarClient;
import com.vibelife.spigot.chat.ChatListener;
import com.vibelife.spigot.commands.BalanceCommand;
import com.vibelife.spigot.commands.FriendsCommand;
import com.vibelife.spigot.commands.MarketCommand;
import com.vibelife.spigot.commands.ParcelCommand;
import com.vibelife.spigot.commands.PayCommand;
import com.vibelife.spigot.economy.VaultProvider;
import com.vibelife.spigot.messaging.PluginMessageHandler;
import com.vibelife.spigot.parcels.ParcelListener;
import com.vibelife.spigot.parcels.ParcelManager;
import net.milkbowl.vault.economy.Economy;
import org.bukkit.plugin.ServicePriority;
import org.bukkit.plugin.java.JavaPlugin;

public class VibeLifePlugin extends JavaPlugin {

    private SidecarClient sidecarClient;
    private PluginMessageHandler pluginMessageHandler;
    private ParcelManager parcelManager;
    private LoginListener loginListener;

    @Override
    public void onEnable() {
        saveDefaultConfig();

        String sidecarUrl = getConfig().getString("sidecar.url", "http://localhost:3000");
        String apiKey = getConfig().getString("sidecar.api-key", "");
        int timeoutMs = getConfig().getInt("sidecar.timeout-ms", 5000);

        sidecarClient = new SidecarClient(sidecarUrl, apiKey, timeoutMs);

        // Register plugin message channel for Fabric mod communication
        String channel = getConfig().getString("channel", "vibelife:main");
        getServer().getMessenger().registerOutgoingPluginChannel(this, channel);
        getServer().getMessenger().registerIncomingPluginChannel(this, channel, getPluginMessageHandler());

        // Initialize managers
        parcelManager = new ParcelManager(this);
        loginListener = new LoginListener(this);

        // Register event listeners
        getServer().getPluginManager().registerEvents(loginListener, this);
        getServer().getPluginManager().registerEvents(new ParcelListener(this, parcelManager, loginListener), this);
        getServer().getPluginManager().registerEvents(new ChatListener(this), this);
        getServer().getPluginManager().registerEvents(new AchievementHook(this), this);

        // Register commands
        var parcelCmd = getCommand("parcel");
        if (parcelCmd != null) {
            var parcelCommand = new ParcelCommand(this, parcelManager, loginListener);
            parcelCmd.setExecutor(parcelCommand);
            parcelCmd.setTabCompleter(parcelCommand);
        }

        var friendsCmd = getCommand("friends");
        if (friendsCmd != null) {
            var friendsCommand = new FriendsCommand(this, loginListener);
            friendsCmd.setExecutor(friendsCommand);
            friendsCmd.setTabCompleter(friendsCommand);
        }

        var marketCmd = getCommand("market");
        if (marketCmd != null) {
            var marketCommand = new MarketCommand(this);
            marketCmd.setExecutor(marketCommand);
            marketCmd.setTabCompleter(marketCommand);
        }

        var balanceCmd = getCommand("balance");
        if (balanceCmd != null) {
            balanceCmd.setExecutor(new BalanceCommand(this));
        }

        var payCmd = getCommand("pay");
        if (payCmd != null) {
            var payCommand = new PayCommand(this);
            payCmd.setExecutor(payCommand);
            payCmd.setTabCompleter(payCommand);
        }

        // Register Vault economy provider if Vault is present
        if (getServer().getPluginManager().getPlugin("Vault") != null) {
            getServer().getServicesManager().register(Economy.class, new VaultProvider(this), this, ServicePriority.Normal);
            getLogger().info("Vault economy provider registered");
        }

        // Sync parcels from sidecar after server is fully loaded
        getServer().getScheduler().runTaskLater(this, () -> parcelManager.syncAll(), 40L); // 2 seconds after enable

        // Periodic parcel re-sync every 5 minutes
        getServer().getScheduler().runTaskTimerAsynchronously(this, () -> parcelManager.syncAll(), 6000L, 6000L);

        getLogger().info("VibeLife plugin enabled — sidecar at " + sidecarUrl);
    }

    @Override
    public void onDisable() {
        String channel = getConfig().getString("channel", "vibelife:main");
        getServer().getMessenger().unregisterOutgoingPluginChannel(this, channel);
        getServer().getMessenger().unregisterIncomingPluginChannel(this, channel);

        if (sidecarClient != null) {
            sidecarClient.shutdown();
        }

        getLogger().info("VibeLife plugin disabled");
    }

    public SidecarClient getSidecarClient() {
        return sidecarClient;
    }

    public PluginMessageHandler getPluginMessageHandler() {
        if (pluginMessageHandler == null) {
            pluginMessageHandler = new PluginMessageHandler(this);
        }
        return pluginMessageHandler;
    }

    public ParcelManager getParcelManager() {
        return parcelManager;
    }

    public LoginListener getLoginListener() {
        return loginListener;
    }

    /**
     * Get the VibeLife region ID for a given MC world name.
     */
    public String getRegionId(String worldName) {
        return getConfig().getString("regions." + worldName, worldName);
    }
}
