package com.vibelife.spigot.parcels;

import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.vibelife.spigot.VibeLifePlugin;

import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;

/**
 * Manages parcel data synced from the Fastify sidecar.
 *
 * On startup (and periodically), fetches all parcels for each configured region
 * and caches them locally. Block place/break events are checked against this cache
 * first (fast path), falling back to a sidecar REST call for edge cases.
 *
 * If WorldGuard is present, parcels are also synced to WorldGuard regions for
 * native MC protection. Without WorldGuard, we rely on the ParcelListener to
 * cancel unauthorized block events.
 */
public class ParcelManager {

    private final VibeLifePlugin plugin;

    /** regionId -> list of cached parcels */
    private final Map<String, List<ParcelData>> parcelCache = new ConcurrentHashMap<>();

    public ParcelManager(VibeLifePlugin plugin) {
        this.plugin = plugin;
    }

    /**
     * Fetch all parcels for a region from the sidecar and update the local cache.
     */
    public void syncRegion(String regionId) {
        plugin.getSidecarClient().get("/api/parcels/by-region/" + regionId)
                .thenAccept(response -> {
                    if (!response.has("parcels")) {
                        plugin.getLogger().warning("No parcels in response for region " + regionId);
                        return;
                    }

                    JsonArray arr = response.getAsJsonArray("parcels");
                    List<ParcelData> parcels = new CopyOnWriteArrayList<>();

                    for (JsonElement el : arr) {
                        JsonObject obj = el.getAsJsonObject();
                        ParcelData p = new ParcelData();
                        p.id = obj.get("id").getAsString();
                        p.regionId = obj.get("regionId").getAsString();
                        p.name = obj.get("name").getAsString();
                        p.ownerAccountId = obj.has("ownerAccountId") && !obj.get("ownerAccountId").isJsonNull()
                                ? obj.get("ownerAccountId").getAsString() : null;
                        p.minX = obj.get("minX").getAsInt();
                        p.maxX = obj.get("maxX").getAsInt();
                        p.minZ = obj.get("minZ").getAsInt();
                        p.maxZ = obj.get("maxZ").getAsInt();
                        p.tier = obj.has("tier") ? obj.get("tier").getAsString() : "standard";

                        // Parse collaborator account IDs
                        if (obj.has("collaboratorAccountIds") && obj.get("collaboratorAccountIds").isJsonArray()) {
                            for (JsonElement collab : obj.getAsJsonArray("collaboratorAccountIds")) {
                                p.collaboratorAccountIds.add(collab.getAsString());
                            }
                        }

                        parcels.add(p);
                    }

                    parcelCache.put(regionId, parcels);
                    plugin.getLogger().info("Synced " + parcels.size() + " parcels for region " + regionId);
                })
                .exceptionally(ex -> {
                    plugin.getLogger().warning("Failed to sync parcels for " + regionId + ": " + ex.getMessage());
                    return null;
                });
    }

    /**
     * Sync all configured regions.
     */
    public void syncAll() {
        var regionSection = plugin.getConfig().getConfigurationSection("regions");
        if (regionSection == null) return;

        for (String worldName : regionSection.getKeys(false)) {
            String regionId = regionSection.getString(worldName);
            if (regionId != null) {
                syncRegion(regionId);
            }
        }
    }

    /**
     * Fast local check: can this accountId build at (x, z) in this region?
     * Returns null if no cached data — caller should fall back to sidecar REST call.
     */
    public BuildCheckResult checkLocal(String accountId, String regionId, int x, int z) {
        List<ParcelData> parcels = parcelCache.get(regionId);
        if (parcels == null) return null; // No cache, caller should use REST

        ParcelData match = null;
        for (ParcelData p : parcels) {
            if (x >= p.minX && x <= p.maxX && z >= p.minZ && z <= p.maxZ) {
                match = p;
                break;
            }
        }

        // No parcel at this location — deny (builds must be in a parcel)
        if (match == null) {
            return new BuildCheckResult(false, "builds must be placed inside a parcel");
        }

        // Public parcels — allow
        if ("public".equals(match.tier)) {
            return new BuildCheckResult(true, null);
        }

        // Owner — allow
        if (accountId.equals(match.ownerAccountId)) {
            return new BuildCheckResult(true, null);
        }

        // Collaborator — allow
        if (match.collaboratorAccountIds.contains(accountId)) {
            return new BuildCheckResult(true, null);
        }

        // Unclaimed — deny
        if (match.ownerAccountId == null) {
            return new BuildCheckResult(false, "claim this parcel before building here");
        }

        // Other player's parcel — deny
        return new BuildCheckResult(false, "parcel owned by another resident");
    }

    /**
     * Get the parcel at a given location, or null.
     */
    public ParcelData getParcelAt(String regionId, int x, int z) {
        List<ParcelData> parcels = parcelCache.get(regionId);
        if (parcels == null) return null;

        for (ParcelData p : parcels) {
            if (x >= p.minX && x <= p.maxX && z >= p.minZ && z <= p.maxZ) {
                return p;
            }
        }
        return null;
    }

    /**
     * Get all cached parcels for a region.
     */
    public List<ParcelData> getParcels(String regionId) {
        return parcelCache.getOrDefault(regionId, List.of());
    }

    public record BuildCheckResult(boolean allowed, String reason) {}

    public static class ParcelData {
        public String id;
        public String regionId;
        public String name;
        public String ownerAccountId;
        public int minX, maxX, minZ, maxZ;
        public String tier;
        public List<String> collaboratorAccountIds = new CopyOnWriteArrayList<>();
    }
}
