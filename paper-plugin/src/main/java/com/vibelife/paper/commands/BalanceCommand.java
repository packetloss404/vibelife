package com.vibelife.paper.commands;

import com.vibelife.paper.VibeLifePlugin;
import com.vibelife.paper.parcels.AccountIdCache;
import org.bukkit.command.Command;
import org.bukkit.command.CommandExecutor;
import org.bukkit.command.CommandSender;
import org.bukkit.entity.Player;

/**
 * /balance - Show the player's VibeLife currency balance.
 */
public class BalanceCommand implements CommandExecutor {

    private final VibeLifePlugin plugin;

    public BalanceCommand(VibeLifePlugin plugin) {
        this.plugin = plugin;
    }

    @Override
    public boolean onCommand(CommandSender sender, Command command, String label, String[] args) {
        if (!(sender instanceof Player player)) {
            sender.sendMessage("This command can only be used by players.");
            return true;
        }

        String accountId = AccountIdCache.get(player.getUniqueId().toString());
        if (accountId == null) {
            player.sendMessage("\u00a7c[VibeLife] \u00a7fYou must be logged in.");
            return true;
        }

        plugin.getSidecarClient().get("/api/economy/balance/" + accountId)
                .thenAccept(response -> {
                    double balance = response.has("balance") ? response.get("balance").getAsDouble() : 0;
                    plugin.getServer().getScheduler().runTask(plugin, () ->
                            player.sendMessage("\u00a76[VibeLife] \u00a7fBalance: \u00a7e" + String.format("%.0f", balance) + " Vibes")
                    );
                })
                .exceptionally(ex -> {
                    plugin.getServer().getScheduler().runTask(plugin, () ->
                            player.sendMessage("\u00a7c[VibeLife] \u00a7fUnable to check balance.")
                    );
                    return null;
                });

        return true;
    }
}
