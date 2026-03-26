package com.packetcraft.fabric.screen;

import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.packetcraft.fabric.PacketCraftClient;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.client.gui.screen.Screen;
import net.minecraft.client.gui.widget.ButtonWidget;
import net.minecraft.text.Text;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * Marketplace GUI screen showing:
 *   - Active listings (item name, kind, price, seller)
 *   - Buy button for fixed-price items
 *   - Sort controls (newest, price low/high)
 *   - User's own listing history tab
 *
 * Opened via M keybind. All data from sidecar REST API (token-based).
 */
public class MarketplaceScreen extends Screen {

    private enum Tab { BROWSE, MY_LISTINGS, TRADES }

    private Tab activeTab = Tab.BROWSE;
    private final List<ListingEntry> listings = new ArrayList<>();
    private final List<ListingEntry> myListings = new ArrayList<>();
    private final List<TradeEntry> trades = new ArrayList<>();
    private boolean dataLoaded = false;
    private String statusMessage = "";
    private int statusColor = 0xFFFFFF;
    private String currentSort = "newest";

    public MarketplaceScreen() {
        super(Text.literal("PacketCraft Marketplace"));
    }

    @Override
    protected void init() {
        super.init();
        int centerX = this.width / 2;

        // Tab buttons
        this.addDrawableChild(ButtonWidget.builder(Text.literal("Browse"), b -> { activeTab = Tab.BROWSE; fetchData(); })
                .dimensions(centerX - 120, 30, 70, 20).build());
        this.addDrawableChild(ButtonWidget.builder(Text.literal("My Listings"), b -> { activeTab = Tab.MY_LISTINGS; fetchData(); })
                .dimensions(centerX - 45, 30, 80, 20).build());
        this.addDrawableChild(ButtonWidget.builder(Text.literal("Trades"), b -> { activeTab = Tab.TRADES; fetchData(); })
                .dimensions(centerX + 40, 30, 60, 20).build());

        // Sort buttons (browse only)
        this.addDrawableChild(ButtonWidget.builder(Text.literal("Newest"), b -> { currentSort = "newest"; fetchData(); })
                .dimensions(centerX - 120, 55, 55, 15).build());
        this.addDrawableChild(ButtonWidget.builder(Text.literal("Price \u2191"), b -> { currentSort = "price_asc"; fetchData(); })
                .dimensions(centerX - 60, 55, 55, 15).build());
        this.addDrawableChild(ButtonWidget.builder(Text.literal("Price \u2193"), b -> { currentSort = "price_desc"; fetchData(); })
                .dimensions(centerX, 55, 55, 15).build());

        // Close
        this.addDrawableChild(ButtonWidget.builder(Text.literal("Close"), b -> close())
                .dimensions(centerX - 30, this.height - 30, 60, 20).build());

        fetchData();
    }

    private void fetchData() {
        dataLoaded = false;
        statusMessage = "";
        var api = PacketCraftClient.getInstance().getSidecarApi();
        String token = PacketCraftClient.getInstance().getSessionToken();

        // Browse listings (no token needed)
        String sortParam = "newest".equals(currentSort) ? "" : "&sort=" + currentSort;
        api.get("/api/marketplace?" + sortParam).thenAccept(resp -> {
            listings.clear();
            if (resp.has("listings") && resp.get("listings").isJsonArray()) {
                for (JsonElement el : resp.getAsJsonArray("listings")) {
                    listings.add(parseListingEntry(el.getAsJsonObject()));
                }
            }
            dataLoaded = true;
        });

        if (token != null) {
            // My listings
            api.get("/api/marketplace/history?token=" + token).thenAccept(resp -> {
                myListings.clear();
                if (resp.has("listings") && resp.get("listings").isJsonArray()) {
                    for (JsonElement el : resp.getAsJsonArray("listings")) {
                        myListings.add(parseListingEntry(el.getAsJsonObject()));
                    }
                }
            });

            // Trades
            api.get("/api/trades?token=" + token).thenAccept(resp -> {
                trades.clear();
                if (resp.has("trades") && resp.get("trades").isJsonArray()) {
                    for (JsonElement el : resp.getAsJsonArray("trades")) {
                        JsonObject t = el.getAsJsonObject();
                        trades.add(new TradeEntry(
                                t.has("id") ? t.get("id").getAsString() : "",
                                t.has("fromDisplayName") ? t.get("fromDisplayName").getAsString() : "?",
                                t.has("offeredCurrency") ? t.get("offeredCurrency").getAsInt() : 0,
                                t.has("requestedCurrency") ? t.get("requestedCurrency").getAsInt() : 0,
                                t.has("status") ? t.get("status").getAsString() : "?"
                        ));
                    }
                }
            });
        }
    }

    private ListingEntry parseListingEntry(JsonObject obj) {
        return new ListingEntry(
                obj.has("id") ? obj.get("id").getAsString() : "",
                obj.has("itemName") ? obj.get("itemName").getAsString() : "?",
                obj.has("itemKind") ? obj.get("itemKind").getAsString() : "?",
                obj.has("price") ? obj.get("price").getAsInt() : 0,
                obj.has("sellerDisplayName") ? obj.get("sellerDisplayName").getAsString() : "?",
                obj.has("listingType") ? obj.get("listingType").getAsString() : "fixed",
                obj.has("status") ? obj.get("status").getAsString() : "active",
                obj.has("currentBid") ? obj.get("currentBid").getAsInt() : 0
        );
    }

    private void buyListing(String listingId) {
        String token = PacketCraftClient.getInstance().getSessionToken();
        if (token == null) {
            statusMessage = "Not logged in";
            statusColor = 0xFF5555;
            return;
        }

        statusMessage = "Purchasing...";
        statusColor = 0xFFFF55;

        PacketCraftClient.getInstance().getSidecarApi()
                .post("/api/marketplace/" + listingId + "/buy", Map.of("token", token))
                .thenAccept(resp -> {
                    if (resp.has("ok") && resp.get("ok").getAsBoolean()) {
                        statusMessage = "Purchase successful!";
                        statusColor = 0x55FF55;
                        fetchData();
                    } else {
                        statusMessage = resp.has("error") ? resp.get("error").getAsString() : "Purchase failed";
                        statusColor = 0xFF5555;
                    }
                })
                .exceptionally(ex -> {
                    statusMessage = "Error: " + ex.getMessage();
                    statusColor = 0xFF5555;
                    return null;
                });
    }

    @Override
    public void render(DrawContext context, int mouseX, int mouseY, float delta) {
        this.renderBackground(context, mouseX, mouseY, delta);
        super.render(context, mouseX, mouseY, delta);

        int centerX = this.width / 2;

        // Title
        context.drawCenteredTextWithShadow(this.textRenderer, Text.literal("\u00a76\u00a7lPacketCraft Marketplace"), centerX, 12, 0xFFFFFF);

        // Status
        if (!statusMessage.isEmpty()) {
            context.drawCenteredTextWithShadow(this.textRenderer, Text.literal(statusMessage), centerX, this.height - 45, statusColor);
        }

        int listY = 75;

        switch (activeTab) {
            case BROWSE -> renderBrowse(context, centerX, listY, mouseX, mouseY);
            case MY_LISTINGS -> renderMyListings(context, centerX, listY);
            case TRADES -> renderTrades(context, centerX, listY);
        }
    }

    private void renderBrowse(DrawContext context, int centerX, int y, int mouseX, int mouseY) {
        if (!dataLoaded) {
            context.drawCenteredTextWithShadow(this.textRenderer, Text.literal("\u00a77Loading..."), centerX, y, 0xAAAAAA);
            return;
        }
        if (listings.isEmpty()) {
            context.drawCenteredTextWithShadow(this.textRenderer, Text.literal("\u00a77No listings available"), centerX, y, 0xAAAAAA);
            return;
        }

        // Header
        context.drawTextWithShadow(this.textRenderer, Text.literal("\u00a76Item"), centerX - 150, y, 0xFFFFFF);
        context.drawTextWithShadow(this.textRenderer, Text.literal("\u00a76Type"), centerX - 30, y, 0xFFFFFF);
        context.drawTextWithShadow(this.textRenderer, Text.literal("\u00a76Price"), centerX + 40, y, 0xFFFFFF);
        context.drawTextWithShadow(this.textRenderer, Text.literal("\u00a76Seller"), centerX + 90, y, 0xFFFFFF);
        y += 14;

        int maxVisible = Math.min(listings.size(), (this.height - y - 50) / 14);
        for (int i = 0; i < maxVisible; i++) {
            ListingEntry l = listings.get(i);
            int lineY = y + i * 14;

            context.drawTextWithShadow(this.textRenderer, Text.literal("\u00a7f" + truncate(l.itemName, 18)), centerX - 150, lineY, 0xFFFFFF);
            context.drawTextWithShadow(this.textRenderer, Text.literal("\u00a77" + l.itemKind), centerX - 30, lineY, 0xAAAAAA);

            String priceText = "auction".equals(l.listingType) && l.currentBid > 0
                    ? l.currentBid + " (bid)"
                    : String.valueOf(l.price);
            context.drawTextWithShadow(this.textRenderer, Text.literal("\u00a7e" + priceText), centerX + 40, lineY, 0xFFFFFF);
            context.drawTextWithShadow(this.textRenderer, Text.literal("\u00a77" + truncate(l.seller, 12)), centerX + 90, lineY, 0xAAAAAA);

            // Click to buy (for fixed listings)
            if ("fixed".equals(l.listingType) && mouseX >= centerX - 150 && mouseX <= centerX + 155 && mouseY >= lineY && mouseY < lineY + 14) {
                context.drawTextWithShadow(this.textRenderer, Text.literal("\u00a7a[Click to Buy]"), centerX - 150, lineY + 1, 0x55FF55);
            }
        }
    }

    @Override
    public boolean mouseClicked(double mouseX, double mouseY, int button) {
        if (button == 0 && activeTab == Tab.BROWSE) {
            int centerX = this.width / 2;
            int y = 89; // 75 + 14 header
            for (int i = 0; i < listings.size(); i++) {
                int lineY = y + i * 14;
                if (mouseX >= centerX - 150 && mouseX <= centerX + 155 && mouseY >= lineY && mouseY < lineY + 14) {
                    ListingEntry l = listings.get(i);
                    if ("fixed".equals(l.listingType)) {
                        buyListing(l.id);
                        return true;
                    }
                }
            }
        }
        return super.mouseClicked(mouseX, mouseY, button);
    }

    private void renderMyListings(DrawContext context, int centerX, int y) {
        if (myListings.isEmpty()) {
            context.drawCenteredTextWithShadow(this.textRenderer, Text.literal("\u00a77No listings yet"), centerX, y, 0xAAAAAA);
            return;
        }

        int maxVisible = Math.min(myListings.size(), (this.height - y - 50) / 14);
        for (int i = 0; i < maxVisible; i++) {
            ListingEntry l = myListings.get(i);
            String statusColor = switch (l.status) {
                case "active" -> "\u00a7a";
                case "sold" -> "\u00a7e";
                case "cancelled" -> "\u00a7c";
                default -> "\u00a77";
            };
            String line = "\u00a7f" + l.itemName + " \u00a7e" + l.price + "V " + statusColor + "[" + l.status + "]";
            context.drawTextWithShadow(this.textRenderer, Text.literal(line), centerX - 150, y + i * 14, 0xFFFFFF);
        }
    }

    private void renderTrades(DrawContext context, int centerX, int y) {
        if (trades.isEmpty()) {
            context.drawCenteredTextWithShadow(this.textRenderer, Text.literal("\u00a77No pending trades"), centerX, y, 0xAAAAAA);
            return;
        }

        int maxVisible = Math.min(trades.size(), (this.height - y - 50) / 14);
        for (int i = 0; i < maxVisible; i++) {
            TradeEntry t = trades.get(i);
            String line = "\u00a7f" + t.from + " offers \u00a7e" + t.offeredCurrency + "V\u00a7f, wants \u00a7e" + t.requestedCurrency + "V";
            context.drawTextWithShadow(this.textRenderer, Text.literal(line), centerX - 150, y + i * 14, 0xFFFFFF);
        }
    }

    private String truncate(String s, int max) {
        return s.length() > max ? s.substring(0, max - 1) + "\u2026" : s;
    }

    @Override
    public boolean shouldPause() {
        return false;
    }

    private record ListingEntry(String id, String itemName, String itemKind, int price, String seller, String listingType, String status, int currentBid) {}
    private record TradeEntry(String id, String from, int offeredCurrency, int requestedCurrency, String status) {}
}
