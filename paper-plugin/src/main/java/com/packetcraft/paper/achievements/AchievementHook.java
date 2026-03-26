package com.packetcraft.paper.achievements;

import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.packetcraft.paper.PacketCraftPlugin;
import com.packetcraft.paper.parcels.AccountIdCache;
import org.bukkit.entity.Player;
import org.bukkit.event.EventHandler;
import org.bukkit.event.EventPriority;
import org.bukkit.event.Listener;
import org.bukkit.event.block.BlockBreakEvent;
import org.bukkit.event.block.BlockPlaceEvent;
import org.bukkit.event.entity.EntityDeathEvent;
import org.bukkit.event.player.PlayerChangedWorldEvent;

import java.util.Map;

/**
 * Listens to MC events and forwards stat increments to the Fastify sidecar
 * for achievement tracking. If any achievements unlock, sends a notification
 * to the player's Fabric mod via plugin message channel.
 *
 * Tracked events:
 *   - BlockPlaceEvent -> blocksPlaced
 *   - BlockBreakEvent -> blocksBroken
 *   - EntityDeathEvent (mob killed by player) -> enemiesDefeated
 *   - PlayerChangedWorldEvent -> regionVisited
 */
public class AchievementHook implements Listener {

    private final PacketCraftPlugin plugin;

    public AchievementHook(PacketCraftPlugin plugin) {
        this.plugin = plugin;
    }

    @EventHandler(priority = EventPriority.MONITOR, ignoreCancelled = true)
    public void onBlockPlace(BlockPlaceEvent event) {
        incrementStat(event.getPlayer(), "blocksPlaced", null);
    }

    @EventHandler(priority = EventPriority.MONITOR, ignoreCancelled = true)
    public void onBlockBreak(BlockBreakEvent event) {
        incrementStat(event.getPlayer(), "blocksBroken", null);
    }

    @EventHandler(priority = EventPriority.MONITOR)
    public void onEntityDeath(EntityDeathEvent event) {
        Player killer = event.getEntity().getKiller();
        if (killer == null) return;

        // Only track mob kills, not player kills
        if (event.getEntity() instanceof Player) return;

        incrementStat(killer, "enemiesDefeated", null);
    }

    @EventHandler(priority = EventPriority.MONITOR)
    public void onWorldChange(PlayerChangedWorldEvent event) {
        Player player = event.getPlayer();
        String regionId = plugin.getRegionId(player.getWorld().getName());
        incrementStat(player, "regionVisited", regionId);
    }

    private void incrementStat(Player player, String stat, String regionId) {
        String mcUuid = player.getUniqueId().toString();
        String accountId = AccountIdCache.get(mcUuid);
        if (accountId == null) return;

        var body = regionId != null
                ? Map.of("accountId", accountId, "stat", stat, "regionId", regionId)
                : Map.of("accountId", accountId, "stat", stat);

        plugin.getSidecarClient().post("/api/achievements/increment", body)
                .thenAccept(response -> {
                    if (!response.has("unlocked")) return;

                    JsonArray unlocked = response.getAsJsonArray("unlocked");
                    if (unlocked.isEmpty()) return;

                    // Send each achievement unlock to the Fabric mod
                    for (JsonElement el : unlocked) {
                        JsonObject ach = el.getAsJsonObject();
                        String id = ach.has("id") ? ach.get("id").getAsString() : "";
                        String name = ach.has("name") ? ach.get("name").getAsString() : "Achievement";
                        String desc = ach.has("description") ? ach.get("description").getAsString() : "";

                        plugin.getPluginMessageHandler().sendAchievementUnlock(player, id, name, desc);

                        // Also send a chat message as fallback
                        plugin.getServer().getScheduler().runTask(plugin, () ->
                                player.sendMessage("\u00a76\u00a7l[Achievement] \u00a7e" + name + " \u00a77- " + desc)
                        );
                    }
                })
                .exceptionally(ex -> {
                    plugin.getLogger().fine("Achievement increment failed: " + ex.getMessage());
                    return null;
                });
    }
}
