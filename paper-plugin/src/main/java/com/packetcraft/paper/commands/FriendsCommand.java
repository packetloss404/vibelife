package com.packetcraft.paper.commands;

import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.packetcraft.paper.PacketCraftPlugin;
import com.packetcraft.paper.auth.LoginListener;
import com.packetcraft.paper.parcels.AccountIdCache;
import org.bukkit.Bukkit;
import org.bukkit.command.Command;
import org.bukkit.command.CommandExecutor;
import org.bukkit.command.CommandSender;
import org.bukkit.command.TabCompleter;
import org.bukkit.entity.Player;

import java.util.List;
import java.util.Map;

/**
 * /friends command for managing PacketCraft friendships.
 *
 * Subcommands:
 *   /friends list              - List all friends
 *   /friends add <player>      - Send friend request
 *   /friends remove <player>   - Remove friend
 *   /friends messages          - View offline messages
 */
public class FriendsCommand implements CommandExecutor, TabCompleter {

    private final PacketCraftPlugin plugin;
    private final LoginListener loginListener;

    public FriendsCommand(PacketCraftPlugin plugin, LoginListener loginListener) {
        this.plugin = plugin;
        this.loginListener = loginListener;
    }

    @Override
    public boolean onCommand(CommandSender sender, Command command, String label, String[] args) {
        if (!(sender instanceof Player player)) {
            sender.sendMessage("This command can only be used by players.");
            return true;
        }

        String token = loginListener.getSessionToken(player.getUniqueId().toString());
        if (token == null) {
            player.sendMessage("\u00a7c[PacketCraft] \u00a7fYou must be logged in.");
            return true;
        }

        if (args.length == 0) {
            sendUsage(player);
            return true;
        }

        return switch (args[0].toLowerCase()) {
            case "list" -> handleList(player, token);
            case "add" -> handleAdd(player, token, args);
            case "remove" -> handleRemove(player, token, args);
            case "messages", "msg" -> handleMessages(player, token);
            default -> { sendUsage(player); yield true; }
        };
    }

    private boolean handleList(Player player, String token) {
        plugin.getSidecarClient().get("/api/friends?token=" + token)
                .thenAccept(response -> plugin.getServer().getScheduler().runTask(plugin, () -> {
                    if (!response.has("friends") || !response.get("friends").isJsonArray()) {
                        player.sendMessage("\u00a7e[PacketCraft] \u00a7fNo friends yet.");
                        return;
                    }

                    JsonArray friends = response.getAsJsonArray("friends");
                    if (friends.isEmpty()) {
                        player.sendMessage("\u00a7e[PacketCraft] \u00a7fNo friends yet. Use /friends add <player>");
                        return;
                    }

                    player.sendMessage("\u00a76[PacketCraft] Friends (" + friends.size() + "):");
                    for (JsonElement el : friends) {
                        JsonObject f = el.getAsJsonObject();
                        String name = f.has("friendDisplayName") ? f.get("friendDisplayName").getAsString() : "?";
                        String status = f.has("status") ? f.get("status").getAsString() : "?";
                        String statusColor = "accepted".equals(status) ? "\u00a7a" : "\u00a7e";
                        player.sendMessage("  \u00a7f" + name + " " + statusColor + "[" + status + "]");
                    }
                }))
                .exceptionally(ex -> {
                    plugin.getServer().getScheduler().runTask(plugin, () ->
                            player.sendMessage("\u00a7c[PacketCraft] \u00a7fFailed to load friends."));
                    return null;
                });
        return true;
    }

    private boolean handleAdd(Player player, String token, String[] args) {
        if (args.length < 2) {
            player.sendMessage("\u00a7c[PacketCraft] \u00a7fUsage: /friends add <player>");
            return true;
        }

        Player target = Bukkit.getPlayer(args[1]);
        if (target == null) {
            player.sendMessage("\u00a7c[PacketCraft] \u00a7fPlayer not found or not online.");
            return true;
        }

        String targetAccountId = AccountIdCache.get(target.getUniqueId().toString());
        if (targetAccountId == null) {
            player.sendMessage("\u00a7c[PacketCraft] \u00a7fThat player is not logged into PacketCraft.");
            return true;
        }

        plugin.getSidecarClient().post("/api/friends", Map.of(
                "token", token,
                "friendAccountId", targetAccountId
        )).thenAccept(response -> plugin.getServer().getScheduler().runTask(plugin, () -> {
            if (response.has("friend")) {
                player.sendMessage("\u00a7a[PacketCraft] \u00a7fFriend request sent to \u00a7e" + target.getName());
                target.sendMessage("\u00a7a[PacketCraft] \u00a7e" + player.getName() + "\u00a7f sent you a friend request!");
            } else {
                String error = response.has("error") ? response.get("error").getAsString() : "unable to add friend";
                player.sendMessage("\u00a7c[PacketCraft] \u00a7f" + error);
            }
        })).exceptionally(ex -> {
            plugin.getServer().getScheduler().runTask(plugin, () ->
                    player.sendMessage("\u00a7c[PacketCraft] \u00a7fError sending friend request."));
            return null;
        });
        return true;
    }

    private boolean handleRemove(Player player, String token, String[] args) {
        if (args.length < 2) {
            player.sendMessage("\u00a7c[PacketCraft] \u00a7fUsage: /friends remove <player>");
            return true;
        }

        Player target = Bukkit.getPlayer(args[1]);
        String targetAccountId = target != null ? AccountIdCache.get(target.getUniqueId().toString()) : null;

        if (targetAccountId == null) {
            player.sendMessage("\u00a7c[PacketCraft] \u00a7fPlayer not found or not online.");
            return true;
        }

        plugin.getSidecarClient().post("/api/friends?_method=DELETE", Map.of(
                "token", token,
                "friendAccountId", targetAccountId
        )).thenAccept(response -> plugin.getServer().getScheduler().runTask(plugin, () -> {
            if (response.has("ok") && response.get("ok").getAsBoolean()) {
                player.sendMessage("\u00a7a[PacketCraft] \u00a7fRemoved \u00a7e" + args[1] + "\u00a7f from friends.");
            } else {
                player.sendMessage("\u00a7c[PacketCraft] \u00a7fFriend not found.");
            }
        })).exceptionally(ex -> {
            plugin.getServer().getScheduler().runTask(plugin, () ->
                    player.sendMessage("\u00a7c[PacketCraft] \u00a7fError removing friend."));
            return null;
        });
        return true;
    }

    private boolean handleMessages(Player player, String token) {
        plugin.getSidecarClient().get("/api/messages/offline?token=" + token + "&limit=10")
                .thenAccept(response -> plugin.getServer().getScheduler().runTask(plugin, () -> {
                    if (!response.has("messages") || !response.get("messages").isJsonArray()) {
                        player.sendMessage("\u00a7e[PacketCraft] \u00a7fNo messages.");
                        return;
                    }

                    JsonArray messages = response.getAsJsonArray("messages");
                    if (messages.isEmpty()) {
                        player.sendMessage("\u00a7e[PacketCraft] \u00a7fNo offline messages.");
                        return;
                    }

                    player.sendMessage("\u00a76[PacketCraft] Offline Messages (" + messages.size() + "):");
                    for (JsonElement el : messages) {
                        JsonObject msg = el.getAsJsonObject();
                        String from = msg.has("fromDisplayName") ? msg.get("fromDisplayName").getAsString() : "?";
                        String text = msg.has("message") ? msg.get("message").getAsString() : "";
                        boolean read = msg.has("read") && msg.get("read").getAsBoolean();
                        String prefix = read ? "\u00a77" : "\u00a7f";
                        player.sendMessage("  " + prefix + from + ": " + text);
                    }
                }))
                .exceptionally(ex -> {
                    plugin.getServer().getScheduler().runTask(plugin, () ->
                            player.sendMessage("\u00a7c[PacketCraft] \u00a7fFailed to load messages."));
                    return null;
                });
        return true;
    }

    private void sendUsage(Player player) {
        player.sendMessage("\u00a76[PacketCraft] Friends commands:");
        player.sendMessage("  \u00a7f/friends list \u00a77- List all friends");
        player.sendMessage("  \u00a7f/friends add <player> \u00a77- Send friend request");
        player.sendMessage("  \u00a7f/friends remove <player> \u00a77- Remove friend");
        player.sendMessage("  \u00a7f/friends messages \u00a77- View offline messages");
    }

    @Override
    public List<String> onTabComplete(CommandSender sender, Command command, String alias, String[] args) {
        if (args.length == 1) {
            return List.of("list", "add", "remove", "messages").stream()
                    .filter(s -> s.startsWith(args[0].toLowerCase()))
                    .toList();
        }
        if (args.length == 2 && ("add".equals(args[0]) || "remove".equals(args[0]))) {
            return Bukkit.getOnlinePlayers().stream()
                    .map(Player::getName)
                    .filter(n -> n.toLowerCase().startsWith(args[1].toLowerCase()))
                    .toList();
        }
        return List.of();
    }
}
