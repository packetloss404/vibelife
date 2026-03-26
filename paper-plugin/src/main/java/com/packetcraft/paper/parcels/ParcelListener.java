package com.packetcraft.paper.parcels;

import com.packetcraft.paper.PacketCraftPlugin;
import com.packetcraft.paper.auth.LoginListener;
import org.bukkit.Location;
import org.bukkit.entity.Player;
import org.bukkit.event.EventHandler;
import org.bukkit.event.EventPriority;
import org.bukkit.event.Listener;
import org.bukkit.event.block.BlockBreakEvent;
import org.bukkit.event.block.BlockPlaceEvent;

import java.util.Map;

/**
 * Intercepts block place/break events and checks PacketCraft parcel permissions.
 *
 * Uses fast local cache first (ParcelManager.checkLocal). If the cache has no data
 * for the region, falls back to a REST call to the sidecar (async, but blocks the event
 * briefly — acceptable because it only happens on cache miss, which is rare after startup).
 *
 * Players with the packetcraft.admin permission bypass all parcel checks.
 */
public class ParcelListener implements Listener {

    private final PacketCraftPlugin plugin;
    private final ParcelManager parcelManager;
    private final LoginListener loginListener;

    public ParcelListener(PacketCraftPlugin plugin, ParcelManager parcelManager, LoginListener loginListener) {
        this.plugin = plugin;
        this.parcelManager = parcelManager;
        this.loginListener = loginListener;
    }

    @EventHandler(priority = EventPriority.HIGH, ignoreCancelled = true)
    public void onBlockPlace(BlockPlaceEvent event) {
        if (!checkPermission(event.getPlayer(), event.getBlock().getLocation())) {
            event.setCancelled(true);
        }
    }

    @EventHandler(priority = EventPriority.HIGH, ignoreCancelled = true)
    public void onBlockBreak(BlockBreakEvent event) {
        if (!checkPermission(event.getPlayer(), event.getBlock().getLocation())) {
            event.setCancelled(true);
        }
    }

    private boolean checkPermission(Player player, Location location) {
        // Admins bypass parcel checks
        if (player.hasPermission("packetcraft.admin")) {
            return true;
        }

        String worldName = location.getWorld().getName();
        String regionId = plugin.getRegionId(worldName);
        int x = location.getBlockX();
        int z = location.getBlockZ();

        // We need the PacketCraft accountId, not the MC UUID
        // The LoginListener maps MC UUID -> session token, but we need accountId
        // For now, use the MC UUID as a lookup key — the sidecar maps it
        String mcUuid = player.getUniqueId().toString();
        String accountId = getAccountId(mcUuid);

        if (accountId == null) {
            player.sendMessage("\u00a7c[PacketCraft] \u00a7fYou must be logged in to build.");
            return false;
        }

        // Fast path: check local parcel cache
        ParcelManager.BuildCheckResult result = parcelManager.checkLocal(accountId, regionId, x, z);

        if (result != null) {
            if (!result.allowed()) {
                player.sendMessage("\u00a7c[PacketCraft] \u00a7f" + result.reason());
            }
            return result.allowed();
        }

        // Cache miss — fall back to sidecar REST (sync, blocking briefly)
        // This should be rare after initial parcel sync
        try {
            var response = plugin.getSidecarClient()
                    .post("/api/parcels/check-build", Map.of(
                            "accountId", accountId,
                            "regionId", regionId,
                            "x", x,
                            "z", z
                    ))
                    .get(); // Blocking — only on cache miss

            boolean allowed = response.has("allowed") && response.get("allowed").getAsBoolean();
            if (!allowed) {
                String reason = response.has("reason") ? response.get("reason").getAsString() : "permission denied";
                player.sendMessage("\u00a7c[PacketCraft] \u00a7f" + reason);
            }
            return allowed;
        } catch (Exception e) {
            plugin.getLogger().warning("Parcel check failed for " + player.getName() + ": " + e.getMessage());
            // Fail open or closed? Fail closed for safety.
            player.sendMessage("\u00a7c[PacketCraft] \u00a7fUnable to verify build permissions. Try again.");
            return false;
        }
    }

    /**
     * Resolve MC UUID to PacketCraft accountId.
     * For now this uses a simple in-memory cache populated during login.
     */
    private String getAccountId(String mcUuid) {
        return AccountIdCache.get(mcUuid);
    }
}
