package com.packetcraft.fabric.network;

import com.google.gson.Gson;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import com.packetcraft.fabric.PacketCraftClient;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.concurrent.CompletableFuture;

/**
 * Async HTTP client for the Fabric mod to call the Fastify sidecar directly.
 * Used for pulling UI data: marketplace listings, friend lists, economy data, etc.
 *
 * All calls run off the render thread via CompletableFuture.
 */
public class SidecarApi {

    private final String baseUrl;
    private final HttpClient httpClient;
    private final Gson gson = new Gson();

    public SidecarApi(String baseUrl) {
        this.baseUrl = baseUrl.endsWith("/") ? baseUrl.substring(0, baseUrl.length() - 1) : baseUrl;
        this.httpClient = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(5))
                .build();
    }

    /**
     * GET with session token auth.
     */
    public CompletableFuture<JsonObject> get(String path) {
        String token = PacketCraftClient.getInstance().getSessionToken();
        HttpRequest.Builder builder = HttpRequest.newBuilder()
                .uri(URI.create(baseUrl + path))
                .GET();

        if (token != null) {
            builder.header("Authorization", "Bearer " + token);
        }

        return httpClient.sendAsync(builder.build(), HttpResponse.BodyHandlers.ofString())
                .thenApply(r -> JsonParser.parseString(r.body()).getAsJsonObject());
    }

    /**
     * POST with session token auth.
     */
    public CompletableFuture<JsonObject> post(String path, Object body) {
        String token = PacketCraftClient.getInstance().getSessionToken();
        String json = gson.toJson(body);
        HttpRequest.Builder builder = HttpRequest.newBuilder()
                .uri(URI.create(baseUrl + path))
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(json));

        if (token != null) {
            builder.header("Authorization", "Bearer " + token);
        }

        return httpClient.sendAsync(builder.build(), HttpResponse.BodyHandlers.ofString())
                .thenApply(r -> JsonParser.parseString(r.body()).getAsJsonObject());
    }

    // ── Convenience methods for common API calls ──────────────────────────

    public CompletableFuture<JsonObject> getBalance() {
        return get("/api/economy/balance");
    }

    public CompletableFuture<JsonObject> getTransactions(int limit) {
        return get("/api/economy/transactions?limit=" + limit);
    }

    public CompletableFuture<JsonObject> getFriends() {
        return get("/api/social/friends");
    }

    public CompletableFuture<JsonObject> getMarketplaceListings() {
        return get("/api/marketplace/listings");
    }

    public CompletableFuture<JsonObject> getAchievements() {
        return get("/api/achievements/progress");
    }

    public CompletableFuture<JsonObject> getEvents() {
        return get("/api/events");
    }
}
