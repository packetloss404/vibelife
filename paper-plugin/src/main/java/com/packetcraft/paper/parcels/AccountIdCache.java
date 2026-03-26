package com.packetcraft.paper.parcels;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Simple in-memory cache of MC UUID -> PacketCraft accountId mappings.
 * Populated on player login, cleared on quit.
 */
public class AccountIdCache {

    private static final Map<String, String> cache = new ConcurrentHashMap<>();

    public static void put(String mcUuid, String accountId) {
        cache.put(mcUuid, accountId);
    }

    public static String get(String mcUuid) {
        return cache.get(mcUuid);
    }

    public static void remove(String mcUuid) {
        cache.remove(mcUuid);
    }
}
