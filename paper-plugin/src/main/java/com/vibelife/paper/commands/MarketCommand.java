package com.vibelife.paper.commands;

import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.vibelife.paper.VibeLifePlugin;
import org.bukkit.command.Command;
import org.bukkit.command.CommandExecutor;
import org.bukkit.command.CommandSender;
import org.bukkit.command.TabCompleter;
import org.bukkit.entity.Player;

import java.util.List;

/**
 * /market command — browse marketplace from chat or open the Fabric GUI.
 *
 * Subcommands:
 *   /market         - List top active listings
 *   /market search <query> - Search listings
 *
 * For full marketplace features (buy, sell, bid), use the Fabric mod GUI (M key).
 */
public class MarketCommand implements CommandExecutor, TabCompleter {

    private final VibeLifePlugin plugin;

    public MarketCommand(VibeLifePlugin plugin) {
        this.plugin = plugin;
    }

    @Override
    public boolean onCommand(CommandSender sender, Command command, String label, String[] args) {
        if (!(sender instanceof Player player)) {
            sender.sendMessage("This command can only be used by players.");
            return true;
        }

        plugin.getSidecarClient().get("/api/marketplace")
                .thenAccept(response -> plugin.getServer().getScheduler().runTask(plugin, () -> {
                    if (!response.has("listings") || !response.get("listings").isJsonArray()) {
                        player.sendMessage("\u00a7e[VibeLife] \u00a7fNo marketplace listings.");
                        return;
                    }

                    JsonArray arr = response.getAsJsonArray("listings");
                    if (arr.isEmpty()) {
                        player.sendMessage("\u00a7e[VibeLife] \u00a7fNo active listings. Press \u00a7eM\u00a7f to open the marketplace GUI.");
                        return;
                    }

                    int max = Math.min(arr.size(), 10);
                    player.sendMessage("\u00a76[VibeLife] Marketplace (" + arr.size() + " listings):");
                    for (int i = 0; i < max; i++) {
                        JsonObject l = arr.get(i).getAsJsonObject();
                        String name = l.has("itemName") ? l.get("itemName").getAsString() : "?";
                        int price = l.has("price") ? l.get("price").getAsInt() : 0;
                        String seller = l.has("sellerDisplayName") ? l.get("sellerDisplayName").getAsString() : "?";
                        String type = l.has("listingType") ? l.get("listingType").getAsString() : "fixed";

                        String typeTag = "auction".equals(type) ? "\u00a7d[auction]" : "";
                        player.sendMessage("  \u00a7f" + name + " \u00a7e" + price + "V \u00a77by " + seller + " " + typeTag);
                    }

                    if (arr.size() > 10) {
                        player.sendMessage("\u00a77  ... and " + (arr.size() - 10) + " more. Press \u00a7eM\u00a77 for full marketplace.");
                    }
                }))
                .exceptionally(ex -> {
                    plugin.getServer().getScheduler().runTask(plugin, () ->
                            player.sendMessage("\u00a7c[VibeLife] \u00a7fFailed to load marketplace."));
                    return null;
                });

        return true;
    }

    @Override
    public List<String> onTabComplete(CommandSender sender, Command command, String alias, String[] args) {
        return List.of();
    }
}
