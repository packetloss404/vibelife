package com.vibelife.spigot.commands;

import com.vibelife.spigot.VibeLifePlugin;
import com.vibelife.spigot.auth.LoginListener;
import com.vibelife.spigot.parcels.AccountIdCache;
import com.vibelife.spigot.parcels.ParcelManager;
import org.bukkit.command.Command;
import org.bukkit.command.CommandExecutor;
import org.bukkit.command.CommandSender;
import org.bukkit.command.TabCompleter;
import org.bukkit.entity.Player;

import java.util.List;
import java.util.Map;

/**
 * /parcel command for managing VibeLife parcels in-game.
 *
 * Subcommands:
 *   /parcel info       - Show parcel info at current location
 *   /parcel claim      - Claim the parcel at current location
 *   /parcel release    - Release your parcel at current location
 *   /parcel list       - List all parcels in current region
 */
public class ParcelCommand implements CommandExecutor, TabCompleter {

    private final VibeLifePlugin plugin;
    private final ParcelManager parcelManager;
    private final LoginListener loginListener;

    public ParcelCommand(VibeLifePlugin plugin, ParcelManager parcelManager, LoginListener loginListener) {
        this.plugin = plugin;
        this.parcelManager = parcelManager;
        this.loginListener = loginListener;
    }

    @Override
    public boolean onCommand(CommandSender sender, Command command, String label, String[] args) {
        if (!(sender instanceof Player player)) {
            sender.sendMessage("This command can only be used by players.");
            return true;
        }

        if (args.length == 0) {
            sendUsage(player);
            return true;
        }

        String sub = args[0].toLowerCase();
        return switch (sub) {
            case "info" -> handleInfo(player);
            case "claim" -> handleClaim(player);
            case "release" -> handleRelease(player);
            case "list" -> handleList(player);
            default -> { sendUsage(player); yield true; }
        };
    }

    private boolean handleInfo(Player player) {
        String regionId = plugin.getRegionId(player.getWorld().getName());
        int x = player.getLocation().getBlockX();
        int z = player.getLocation().getBlockZ();

        ParcelManager.ParcelData parcel = parcelManager.getParcelAt(regionId, x, z);
        if (parcel == null) {
            player.sendMessage("\u00a7e[VibeLife] \u00a7fNo parcel at your location.");
            return true;
        }

        player.sendMessage("\u00a76[VibeLife] Parcel: \u00a7f" + parcel.name);
        player.sendMessage("\u00a76  Owner: \u00a7f" + (parcel.ownerAccountId != null ? parcel.ownerAccountId : "unclaimed"));
        player.sendMessage("\u00a76  Tier: \u00a7f" + parcel.tier);
        player.sendMessage("\u00a76  Bounds: \u00a7f(" + parcel.minX + ", " + parcel.minZ + ") to (" + parcel.maxX + ", " + parcel.maxZ + ")");
        if (!parcel.collaboratorAccountIds.isEmpty()) {
            player.sendMessage("\u00a76  Collaborators: \u00a7f" + parcel.collaboratorAccountIds.size());
        }
        return true;
    }

    private boolean handleClaim(Player player) {
        String regionId = plugin.getRegionId(player.getWorld().getName());
        int x = player.getLocation().getBlockX();
        int z = player.getLocation().getBlockZ();
        String mcUuid = player.getUniqueId().toString();
        String token = loginListener.getSessionToken(mcUuid);

        if (token == null) {
            player.sendMessage("\u00a7c[VibeLife] \u00a7fYou must be logged in.");
            return true;
        }

        ParcelManager.ParcelData parcel = parcelManager.getParcelAt(regionId, x, z);
        if (parcel == null) {
            player.sendMessage("\u00a7c[VibeLife] \u00a7fNo parcel at your location.");
            return true;
        }

        if (parcel.ownerAccountId != null) {
            player.sendMessage("\u00a7c[VibeLife] \u00a7fThis parcel is already claimed.");
            return true;
        }

        plugin.getSidecarClient()
                .post("/api/parcels/claim", Map.of("token", token, "parcelId", parcel.id))
                .thenAccept(response -> {
                    if (response.has("parcel")) {
                        plugin.getServer().getScheduler().runTask(plugin, () -> {
                            player.sendMessage("\u00a7a[VibeLife] \u00a7fParcel \u00a7e" + parcel.name + "\u00a7f claimed!");
                            // Refresh cache
                            parcelManager.syncRegion(regionId);
                        });
                    } else {
                        plugin.getServer().getScheduler().runTask(plugin, () ->
                                player.sendMessage("\u00a7c[VibeLife] \u00a7fFailed to claim parcel.")
                        );
                    }
                })
                .exceptionally(ex -> {
                    plugin.getServer().getScheduler().runTask(plugin, () ->
                            player.sendMessage("\u00a7c[VibeLife] \u00a7fError claiming parcel: " + ex.getMessage())
                    );
                    return null;
                });
        return true;
    }

    private boolean handleRelease(Player player) {
        String regionId = plugin.getRegionId(player.getWorld().getName());
        int x = player.getLocation().getBlockX();
        int z = player.getLocation().getBlockZ();
        String mcUuid = player.getUniqueId().toString();
        String token = loginListener.getSessionToken(mcUuid);

        if (token == null) {
            player.sendMessage("\u00a7c[VibeLife] \u00a7fYou must be logged in.");
            return true;
        }

        ParcelManager.ParcelData parcel = parcelManager.getParcelAt(regionId, x, z);
        if (parcel == null) {
            player.sendMessage("\u00a7c[VibeLife] \u00a7fNo parcel at your location.");
            return true;
        }

        String accountId = AccountIdCache.get(mcUuid);
        if (accountId == null || !accountId.equals(parcel.ownerAccountId)) {
            player.sendMessage("\u00a7c[VibeLife] \u00a7fYou don't own this parcel.");
            return true;
        }

        plugin.getSidecarClient()
                .post("/api/parcels/release", Map.of("token", token, "parcelId", parcel.id))
                .thenAccept(response -> {
                    if (response.has("parcel")) {
                        plugin.getServer().getScheduler().runTask(plugin, () -> {
                            player.sendMessage("\u00a7a[VibeLife] \u00a7fParcel \u00a7e" + parcel.name + "\u00a7f released.");
                            parcelManager.syncRegion(regionId);
                        });
                    } else {
                        plugin.getServer().getScheduler().runTask(plugin, () ->
                                player.sendMessage("\u00a7c[VibeLife] \u00a7fFailed to release parcel.")
                        );
                    }
                })
                .exceptionally(ex -> {
                    plugin.getServer().getScheduler().runTask(plugin, () ->
                            player.sendMessage("\u00a7c[VibeLife] \u00a7fError releasing parcel: " + ex.getMessage())
                    );
                    return null;
                });
        return true;
    }

    private boolean handleList(Player player) {
        String regionId = plugin.getRegionId(player.getWorld().getName());
        var parcels = parcelManager.getParcels(regionId);

        if (parcels.isEmpty()) {
            player.sendMessage("\u00a7e[VibeLife] \u00a7fNo parcels in this region.");
            return true;
        }

        player.sendMessage("\u00a76[VibeLife] Parcels in region \u00a7e" + regionId + "\u00a76:");
        for (ParcelManager.ParcelData p : parcels) {
            String status = p.ownerAccountId != null ? "\u00a7c(claimed)" : "\u00a7a(available)";
            player.sendMessage("  \u00a7f" + p.name + " " + status + " \u00a77[" + p.minX + "," + p.minZ + " to " + p.maxX + "," + p.maxZ + "]");
        }
        return true;
    }

    private void sendUsage(Player player) {
        player.sendMessage("\u00a76[VibeLife] Parcel commands:");
        player.sendMessage("  \u00a7f/parcel info \u00a77- Show parcel at your location");
        player.sendMessage("  \u00a7f/parcel claim \u00a77- Claim unclaimed parcel");
        player.sendMessage("  \u00a7f/parcel release \u00a77- Release your parcel");
        player.sendMessage("  \u00a7f/parcel list \u00a77- List all parcels");
    }

    @Override
    public List<String> onTabComplete(CommandSender sender, Command command, String alias, String[] args) {
        if (args.length == 1) {
            return List.of("info", "claim", "release", "list").stream()
                    .filter(s -> s.startsWith(args[0].toLowerCase()))
                    .toList();
        }
        return List.of();
    }
}
