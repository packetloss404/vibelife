package com.vibelife.paper.bridge;

import com.google.gson.Gson;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.Map;
import java.util.concurrent.CompletableFuture;
import java.util.logging.Logger;

/**
 * Async HTTP client for communicating with the Fastify sidecar.
 * All calls are non-blocking and return CompletableFuture.
 */
public class SidecarClient {

    private final String baseUrl;
    private final String apiKey;
    private final HttpClient httpClient;
    private final Gson gson = new Gson();
    private static final Logger LOGGER = Logger.getLogger("VibeLife-Sidecar");

    public SidecarClient(String baseUrl, String apiKey, int timeoutMs) {
        this.baseUrl = baseUrl.endsWith("/") ? baseUrl.substring(0, baseUrl.length() - 1) : baseUrl;
        this.apiKey = apiKey;
        this.httpClient = HttpClient.newBuilder()
                .connectTimeout(Duration.ofMillis(timeoutMs))
                .build();
    }

    /**
     * POST JSON to the sidecar and return the parsed response.
     */
    public CompletableFuture<JsonObject> post(String path, Object body) {
        String json = gson.toJson(body);
        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(baseUrl + path))
                .header("Content-Type", "application/json")
                .header("X-Api-Key", apiKey)
                .POST(HttpRequest.BodyPublishers.ofString(json))
                .build();

        return httpClient.sendAsync(request, HttpResponse.BodyHandlers.ofString())
                .thenApply(response -> {
                    if (response.statusCode() >= 400) {
                        LOGGER.warning("Sidecar error " + response.statusCode() + " on " + path + ": " + response.body());
                    }
                    return JsonParser.parseString(response.body()).getAsJsonObject();
                });
    }

    /**
     * GET from the sidecar and return the parsed response.
     */
    public CompletableFuture<JsonObject> get(String path) {
        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(baseUrl + path))
                .header("X-Api-Key", apiKey)
                .GET()
                .build();

        return httpClient.sendAsync(request, HttpResponse.BodyHandlers.ofString())
                .thenApply(response -> {
                    if (response.statusCode() >= 400) {
                        LOGGER.warning("Sidecar error " + response.statusCode() + " on " + path + ": " + response.body());
                    }
                    return JsonParser.parseString(response.body()).getAsJsonObject();
                });
    }

    /**
     * POST with token-based auth header (for forwarding player sessions).
     */
    public CompletableFuture<JsonObject> postWithToken(String path, String token, Object body) {
        String json = gson.toJson(body);
        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(baseUrl + path))
                .header("Content-Type", "application/json")
                .header("Authorization", "Bearer " + token)
                .POST(HttpRequest.BodyPublishers.ofString(json))
                .build();

        return httpClient.sendAsync(request, HttpResponse.BodyHandlers.ofString())
                .thenApply(response -> JsonParser.parseString(response.body()).getAsJsonObject());
    }

    /**
     * Convenience: MC login call.
     */
    public CompletableFuture<JsonObject> mcLogin(String mcUuid, String mcUsername, String regionId) {
        return post("/api/auth/mc-login", Map.of(
                "mcUuid", mcUuid,
                "mcUsername", mcUsername,
                "regionId", regionId
        ));
    }

    public void shutdown() {
        // HttpClient doesn't need explicit shutdown in Java 21
    }
}
