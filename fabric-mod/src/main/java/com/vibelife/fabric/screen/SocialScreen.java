package com.vibelife.fabric.screen;

import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.vibelife.fabric.VibeLifeClient;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.client.gui.screen.Screen;
import net.minecraft.client.gui.widget.ButtonWidget;
import net.minecraft.text.Text;

import java.util.ArrayList;
import java.util.List;

/**
 * Social GUI screen with three tabs:
 *   - Friends: list of friends with online status
 *   - Groups: list of groups the player belongs to
 *   - Messages: offline messages inbox
 *
 * Opened via N keybind. All data fetched from sidecar REST API.
 */
public class SocialScreen extends Screen {

    private enum Tab { FRIENDS, GROUPS, MESSAGES }

    private Tab activeTab = Tab.FRIENDS;
    private final List<FriendEntry> friends = new ArrayList<>();
    private final List<GroupEntry> groups = new ArrayList<>();
    private final List<MessageEntry> messages = new ArrayList<>();
    private boolean dataLoaded = false;

    public SocialScreen() {
        super(Text.literal("VibeLife Social"));
    }

    @Override
    protected void init() {
        super.init();

        int centerX = this.width / 2;

        // Tab buttons
        this.addDrawableChild(ButtonWidget.builder(Text.literal("Friends"), b -> { activeTab = Tab.FRIENDS; refreshTab(); })
                .dimensions(centerX - 105, 30, 65, 20).build());
        this.addDrawableChild(ButtonWidget.builder(Text.literal("Groups"), b -> { activeTab = Tab.GROUPS; refreshTab(); })
                .dimensions(centerX - 35, 30, 65, 20).build());
        this.addDrawableChild(ButtonWidget.builder(Text.literal("Messages"), b -> { activeTab = Tab.MESSAGES; refreshTab(); })
                .dimensions(centerX + 35, 30, 70, 20).build());

        // Close button
        this.addDrawableChild(ButtonWidget.builder(Text.literal("Close"), b -> close())
                .dimensions(centerX - 30, this.height - 30, 60, 20).build());

        fetchAll();
    }

    private void fetchAll() {
        dataLoaded = false;
        var api = VibeLifeClient.getInstance().getSidecarApi();
        String token = VibeLifeClient.getInstance().getSessionToken();
        if (token == null) return;

        api.get("/api/friends?token=" + token).thenAccept(resp -> {
            friends.clear();
            if (resp.has("friends") && resp.get("friends").isJsonArray()) {
                for (JsonElement el : resp.getAsJsonArray("friends")) {
                    JsonObject f = el.getAsJsonObject();
                    friends.add(new FriendEntry(
                            f.has("friendDisplayName") ? f.get("friendDisplayName").getAsString() : "?",
                            f.has("status") ? f.get("status").getAsString() : "?"
                    ));
                }
            }
            dataLoaded = true;
        });

        api.get("/api/groups?token=" + token).thenAccept(resp -> {
            groups.clear();
            if (resp.has("groups") && resp.get("groups").isJsonArray()) {
                for (JsonElement el : resp.getAsJsonArray("groups")) {
                    JsonObject g = el.getAsJsonObject();
                    groups.add(new GroupEntry(
                            g.has("name") ? g.get("name").getAsString() : "?",
                            g.has("description") ? g.get("description").getAsString() : ""
                    ));
                }
            }
        });

        api.get("/api/messages/offline?token=" + token + "&limit=20").thenAccept(resp -> {
            messages.clear();
            if (resp.has("messages") && resp.get("messages").isJsonArray()) {
                for (JsonElement el : resp.getAsJsonArray("messages")) {
                    JsonObject m = el.getAsJsonObject();
                    messages.add(new MessageEntry(
                            m.has("fromDisplayName") ? m.get("fromDisplayName").getAsString() : "?",
                            m.has("message") ? m.get("message").getAsString() : "",
                            m.has("read") && m.get("read").getAsBoolean()
                    ));
                }
            }
        });
    }

    private void refreshTab() {
        fetchAll();
    }

    @Override
    public void render(DrawContext context, int mouseX, int mouseY, float delta) {
        this.renderBackground(context, mouseX, mouseY, delta);
        super.render(context, mouseX, mouseY, delta);

        int centerX = this.width / 2;

        // Title
        context.drawCenteredTextWithShadow(this.textRenderer, Text.literal("\u00a76\u00a7lVibeLife Social"), centerX, 12, 0xFFFFFF);

        // Active tab indicator
        String tabName = switch (activeTab) {
            case FRIENDS -> "Friends";
            case GROUPS -> "Groups";
            case MESSAGES -> "Messages";
        };
        context.drawCenteredTextWithShadow(this.textRenderer, Text.literal("\u00a7e" + tabName), centerX, 55, 0xFFFFFF);

        int listY = 70;

        switch (activeTab) {
            case FRIENDS -> renderFriends(context, centerX, listY);
            case GROUPS -> renderGroups(context, centerX, listY);
            case MESSAGES -> renderMessages(context, centerX, listY);
        }
    }

    private void renderFriends(DrawContext context, int centerX, int y) {
        if (friends.isEmpty()) {
            context.drawCenteredTextWithShadow(this.textRenderer, Text.literal("\u00a77No friends yet. Use /friends add <player>"), centerX, y, 0xAAAAAA);
            return;
        }

        int maxVisible = Math.min(friends.size(), (this.height - y - 40) / 14);
        for (int i = 0; i < maxVisible; i++) {
            FriendEntry f = friends.get(i);
            String statusColor = "accepted".equals(f.status) ? "\u00a7a" : "\u00a7e";
            String line = "\u00a7f" + f.name + " " + statusColor + "[" + f.status + "]";
            context.drawTextWithShadow(this.textRenderer, Text.literal(line), centerX - 120, y + i * 14, 0xFFFFFF);
        }
    }

    private void renderGroups(DrawContext context, int centerX, int y) {
        if (groups.isEmpty()) {
            context.drawCenteredTextWithShadow(this.textRenderer, Text.literal("\u00a77No groups. Use /group create <name>"), centerX, y, 0xAAAAAA);
            return;
        }

        int maxVisible = Math.min(groups.size(), (this.height - y - 40) / 14);
        for (int i = 0; i < maxVisible; i++) {
            GroupEntry g = groups.get(i);
            String line = "\u00a7f" + g.name + " \u00a77" + g.description;
            context.drawTextWithShadow(this.textRenderer, Text.literal(line), centerX - 120, y + i * 14, 0xFFFFFF);
        }
    }

    private void renderMessages(DrawContext context, int centerX, int y) {
        if (messages.isEmpty()) {
            context.drawCenteredTextWithShadow(this.textRenderer, Text.literal("\u00a77No messages"), centerX, y, 0xAAAAAA);
            return;
        }

        int maxVisible = Math.min(messages.size(), (this.height - y - 40) / 14);
        for (int i = 0; i < maxVisible; i++) {
            MessageEntry m = messages.get(i);
            String prefix = m.read ? "\u00a78" : "\u00a7f";
            String line = prefix + m.from + ": \u00a77" + m.message;
            context.drawTextWithShadow(this.textRenderer, Text.literal(line), centerX - 120, y + i * 14, 0xFFFFFF);
        }
    }

    @Override
    public boolean shouldPause() {
        return false;
    }

    private record FriendEntry(String name, String status) {}
    private record GroupEntry(String name, String description) {}
    private record MessageEntry(String from, String message, boolean read) {}
}
