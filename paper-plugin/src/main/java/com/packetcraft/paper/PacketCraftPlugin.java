package com.packetcraft.paper;

import com.packetcraft.paper.achievements.AchievementHook;
import com.packetcraft.paper.auth.LoginListener;
import com.packetcraft.paper.bridge.SidecarClient;
import com.packetcraft.paper.chat.ChatListener;
import com.packetcraft.paper.commands.BalanceCommand;
import com.packetcraft.paper.commands.FriendsCommand;
import com.packetcraft.paper.commands.MarketCommand;
import com.packetcraft.paper.commands.ParcelCommand;
import com.packetcraft.paper.commands.PayCommand;
import com.packetcraft.paper.economy.VaultProvider;
import com.packetcraft.paper.messaging.PluginMessageHandler;
import com.packetcraft.paper.parcels.ParcelListener;
import com.packetcraft.paper.parcels.ParcelManager;
import net.milkbowl.vault.economy.Economy;
import org.bukkit.plugin.ServicePriority;
import org.bukkit.plugin.java.JavaPlugin;

public class PacketCraftPlugin extends JavaPlugin {

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
        String channel = getConfig().getString("channel", "packetcraft:main");
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

        getLogger().info("PacketCraft plugin enabled — sidecar at " + sidecarUrl);
    }

    @Override
    public void onDisable() {
        String channel = getConfig().getString("channel", "packetcraft:main");
        getServer().getMessenger().unregisterOutgoingPluginChannel(this, channel);
        getServer().getMessenger().unregisterIncomingPluginChannel(this, channel);

        if (sidecarClient != null) {
            sidecarClient.shutdown();
        }

        getLogger().info("PacketCraft plugin disabled");
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
     * Get the PacketCraft region ID for a given MC world name.
     */
    public String getRegionId(String worldName) {
        return getConfig().getString("regions." + worldName, worldName);
    }
}
