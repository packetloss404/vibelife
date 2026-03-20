package com.vibelife.paper.commands;

import com.vibelife.paper.VibeLifePlugin;
import com.vibelife.paper.parcels.AccountIdCache;
import org.bukkit.Bukkit;
import org.bukkit.command.Command;
import org.bukkit.command.CommandExecutor;
import org.bukkit.command.CommandSender;
import org.bukkit.command.TabCompleter;
import org.bukkit.entity.Player;

import java.util.List;
import java.util.Map;

/**
 * /pay <player> <amount> - Send VibeLife currency to another player.
 */
public class PayCommand implements CommandExecutor, TabCompleter {

    private final VibeLifePlugin plugin;

    public PayCommand(VibeLifePlugin plugin) {
        this.plugin = plugin;
    }

    @Override
    public boolean onCommand(CommandSender sender, Command command, String label, String[] args) {
        if (!(sender instanceof Player player)) {
            sender.sendMessage("This command can only be used by players.");
            return true;
        }

        if (args.length < 2) {
            player.sendMessage("\u00a7c[VibeLife] \u00a7fUsage: /pay <player> <amount>");
            return true;
        }

        String targetName = args[0];
        int amount;
        try {
            amount = Integer.parseInt(args[1]);
        } catch (NumberFormatException e) {
            player.sendMessage("\u00a7c[VibeLife] \u00a7fAmount must be a number.");
            return true;
        }

        if (amount <= 0) {
            player.sendMessage("\u00a7c[VibeLife] \u00a7fAmount must be positive.");
            return true;
        }

        Player target = Bukkit.getPlayer(targetName);
        if (target == null) {
            player.sendMessage("\u00a7c[VibeLife] \u00a7fPlayer not found.");
            return true;
        }

        if (target.equals(player)) {
            player.sendMessage("\u00a7c[VibeLife] \u00a7fYou can't pay yourself.");
            return true;
        }

        String fromAccountId = AccountIdCache.get(player.getUniqueId().toString());
        String toAccountId = AccountIdCache.get(target.getUniqueId().toString());

        if (fromAccountId == null || toAccountId == null) {
            player.sendMessage("\u00a7c[VibeLife] \u00a7fBoth players must be logged in.");
            return true;
        }

        plugin.getSidecarClient()
                .post("/api/economy/server-transfer", Map.of(
                        "fromAccountId", fromAccountId,
                        "toAccountId", toAccountId,
                        "amount", amount,
                        "type", "gift",
                        "description", "payment from " + player.getName() + " to " + target.getName()
                ))
                .thenAccept(response -> {
                    plugin.getServer().getScheduler().runTask(plugin, () -> {
                        if (response.has("success") && response.get("success").getAsBoolean()) {
                            player.sendMessage("\u00a7a[VibeLife] \u00a7fSent \u00a7e" + amount + " Vibes\u00a7f to \u00a7e" + target.getName());
                            target.sendMessage("\u00a7a[VibeLife] \u00a7fReceived \u00a7e" + amount + " Vibes\u00a7f from \u00a7e" + player.getName());

                            // Notify Fabric mods of balance change
                            plugin.getPluginMessageHandler().sendBalanceUpdate(player, String.valueOf(response.get("balance").getAsInt()));
                        } else {
                            String error = response.has("error") ? response.get("error").getAsString() : "transfer failed";
                            player.sendMessage("\u00a7c[VibeLife] \u00a7f" + error);
                        }
                    });
                })
                .exceptionally(ex -> {
                    plugin.getServer().getScheduler().runTask(plugin, () ->
                            player.sendMessage("\u00a7c[VibeLife] \u00a7fError processing payment.")
                    );
                    return null;
                });

        return true;
    }

    @Override
    public List<String> onTabComplete(CommandSender sender, Command command, String alias, String[] args) {
        if (args.length == 1) {
            return Bukkit.getOnlinePlayers().stream()
                    .map(Player::getName)
                    .filter(name -> name.toLowerCase().startsWith(args[0].toLowerCase()))
                    .toList();
        }
        return List.of();
    }
}
