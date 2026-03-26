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

/**
 * Achievements GUI showing:
 *   - Player level, XP, title
 *   - Unlocked and locked achievements
 *   - Daily/weekly challenges with progress bars
 *
 * Opened via J keybind.
 */
public class AchievementsScreen extends Screen {

    private enum Tab { ACHIEVEMENTS, CHALLENGES, LEADERBOARD }

    private Tab activeTab = Tab.ACHIEVEMENTS;
    private int playerLevel = 0;
    private int playerXp = 0;
    private String playerTitle = "";
    private final List<AchEntry> achievements = new ArrayList<>();
    private final List<String> unlocked = new ArrayList<>();
    private final List<ChallengeEntry> dailies = new ArrayList<>();
    private final List<ChallengeEntry> weeklies = new ArrayList<>();
    private final List<LeaderEntry> leaders = new ArrayList<>();

    public AchievementsScreen() {
        super(Text.literal("PacketCraft Achievements"));
    }

    @Override
    protected void init() {
        super.init();
        int centerX = this.width / 2;

        this.addDrawableChild(ButtonWidget.builder(Text.literal("Achievements"), b -> { activeTab = Tab.ACHIEVEMENTS; })
                .dimensions(centerX - 120, 30, 85, 20).build());
        this.addDrawableChild(ButtonWidget.builder(Text.literal("Challenges"), b -> { activeTab = Tab.CHALLENGES; })
                .dimensions(centerX - 30, 30, 75, 20).build());
        this.addDrawableChild(ButtonWidget.builder(Text.literal("Leaderboard"), b -> { activeTab = Tab.LEADERBOARD; fetchLeaderboard(); })
                .dimensions(centerX + 50, 30, 80, 20).build());

        this.addDrawableChild(ButtonWidget.builder(Text.literal("Close"), b -> close())
                .dimensions(centerX - 30, this.height - 30, 60, 20).build());

        fetchData();
    }

    private void fetchData() {
        var api = PacketCraftClient.getInstance().getSidecarApi();
        String token = PacketCraftClient.getInstance().getSessionToken();
        if (token == null) return;

        // All achievements
        api.get("/api/achievements").thenAccept(resp -> {
            achievements.clear();
            if (resp.has("achievements") && resp.get("achievements").isJsonArray()) {
                for (JsonElement el : resp.getAsJsonArray("achievements")) {
                    JsonObject a = el.getAsJsonObject();
                    achievements.add(new AchEntry(
                            a.has("id") ? a.get("id").getAsString() : "",
                            a.has("name") ? a.get("name").getAsString() : "?",
                            a.has("description") ? a.get("description").getAsString() : "",
                            a.has("category") ? a.get("category").getAsString() : "",
                            a.has("xpReward") ? a.get("xpReward").getAsInt() : 0
                    ));
                }
            }
        });

        // Player progress
        api.get("/api/progress?token=" + token).thenAccept(resp -> {
            if (resp.has("progress")) {
                JsonObject p = resp.getAsJsonObject("progress");
                playerLevel = p.has("level") ? p.get("level").getAsInt() : 0;
                playerXp = p.has("xp") ? p.get("xp").getAsInt() : 0;
                playerTitle = p.has("title") ? p.get("title").getAsString() : "";
                unlocked.clear();
                if (p.has("unlockedAchievements") && p.get("unlockedAchievements").isJsonArray()) {
                    for (JsonElement el : p.getAsJsonArray("unlockedAchievements")) {
                        unlocked.add(el.getAsString());
                    }
                }
            }
        });

        // Challenges
        api.get("/api/progress/challenges?token=" + token).thenAccept(resp -> {
            dailies.clear();
            weeklies.clear();
            if (resp.has("dailyChallenges") && resp.get("dailyChallenges").isJsonArray()) {
                for (JsonElement el : resp.getAsJsonArray("dailyChallenges")) {
                    dailies.add(parseChallengeEntry(el.getAsJsonObject()));
                }
            }
            if (resp.has("weeklyChallenges") && resp.get("weeklyChallenges").isJsonArray()) {
                for (JsonElement el : resp.getAsJsonArray("weeklyChallenges")) {
                    weeklies.add(parseChallengeEntry(el.getAsJsonObject()));
                }
            }
        });
    }

    private void fetchLeaderboard() {
        PacketCraftClient.getInstance().getSidecarApi().get("/api/leaderboard?limit=10").thenAccept(resp -> {
            leaders.clear();
            if (resp.has("leaderboard") && resp.get("leaderboard").isJsonArray()) {
                for (JsonElement el : resp.getAsJsonArray("leaderboard")) {
                    JsonObject e = el.getAsJsonObject();
                    leaders.add(new LeaderEntry(
                            e.has("displayName") ? e.get("displayName").getAsString() : "?",
                            e.has("level") ? e.get("level").getAsInt() : 0,
                            e.has("xp") ? e.get("xp").getAsInt() : 0
                    ));
                }
            }
        });
    }

    private ChallengeEntry parseChallengeEntry(JsonObject obj) {
        return new ChallengeEntry(
                obj.has("description") ? obj.get("description").getAsString() : "?",
                obj.has("progress") ? obj.get("progress").getAsInt() : 0,
                obj.has("requirement") && obj.getAsJsonObject("requirement").has("count")
                        ? obj.getAsJsonObject("requirement").get("count").getAsInt() : 1,
                obj.has("completed") && obj.get("completed").getAsBoolean(),
                obj.has("xpReward") ? obj.get("xpReward").getAsInt() : 0
        );
    }

    @Override
    public void render(DrawContext context, int mouseX, int mouseY, float delta) {
        this.renderBackground(context, mouseX, mouseY, delta);
        super.render(context, mouseX, mouseY, delta);

        int centerX = this.width / 2;

        context.drawCenteredTextWithShadow(this.textRenderer, Text.literal("\u00a76\u00a7lPacketCraft Achievements"), centerX, 12, 0xFFFFFF);

        // Player info bar
        String info = "\u00a7eLv." + playerLevel + " \u00a77| \u00a7bXP: " + playerXp;
        if (!playerTitle.isEmpty()) info += " \u00a77| \u00a7d" + playerTitle;
        context.drawCenteredTextWithShadow(this.textRenderer, Text.literal(info), centerX, 55, 0xFFFFFF);

        int listY = 70;
        switch (activeTab) {
            case ACHIEVEMENTS -> renderAchievements(context, centerX, listY);
            case CHALLENGES -> renderChallenges(context, centerX, listY);
            case LEADERBOARD -> renderLeaderboard(context, centerX, listY);
        }
    }

    private void renderAchievements(DrawContext context, int centerX, int y) {
        if (achievements.isEmpty()) {
            context.drawCenteredTextWithShadow(this.textRenderer, Text.literal("\u00a77Loading..."), centerX, y, 0xAAAAAA);
            return;
        }

        int maxVisible = Math.min(achievements.size(), (this.height - y - 40) / 14);
        for (int i = 0; i < maxVisible; i++) {
            AchEntry a = achievements.get(i);
            boolean done = unlocked.contains(a.id);
            String check = done ? "\u00a7a\u2714 " : "\u00a78\u2718 ";
            String color = done ? "\u00a7f" : "\u00a77";
            String line = check + color + a.name + " \u00a78- " + a.description + " \u00a7e(+" + a.xpReward + "xp)";
            context.drawTextWithShadow(this.textRenderer, Text.literal(line), centerX - 155, y + i * 14, 0xFFFFFF);
        }
    }

    private void renderChallenges(DrawContext context, int centerX, int y) {
        context.drawTextWithShadow(this.textRenderer, Text.literal("\u00a7eDaily Challenges:"), centerX - 140, y, 0xFFFFFF);
        y += 14;
        if (dailies.isEmpty()) {
            context.drawTextWithShadow(this.textRenderer, Text.literal("\u00a77  No challenges"), centerX - 140, y, 0xAAAAAA);
            y += 14;
        } else {
            for (ChallengeEntry c : dailies) {
                String check = c.completed ? "\u00a7a\u2714 " : "\u00a7f  ";
                String bar = "[" + c.progress + "/" + c.required + "]";
                context.drawTextWithShadow(this.textRenderer, Text.literal(check + c.description + " \u00a7e" + bar + " \u00a78+" + c.xpReward + "xp"), centerX - 140, y, 0xFFFFFF);
                y += 14;
            }
        }

        y += 6;
        context.drawTextWithShadow(this.textRenderer, Text.literal("\u00a7eWeekly Challenges:"), centerX - 140, y, 0xFFFFFF);
        y += 14;
        if (weeklies.isEmpty()) {
            context.drawTextWithShadow(this.textRenderer, Text.literal("\u00a77  No challenges"), centerX - 140, y, 0xAAAAAA);
        } else {
            for (ChallengeEntry c : weeklies) {
                String check = c.completed ? "\u00a7a\u2714 " : "\u00a7f  ";
                String bar = "[" + c.progress + "/" + c.required + "]";
                context.drawTextWithShadow(this.textRenderer, Text.literal(check + c.description + " \u00a7e" + bar + " \u00a78+" + c.xpReward + "xp"), centerX - 140, y, 0xFFFFFF);
                y += 14;
            }
        }
    }

    private void renderLeaderboard(DrawContext context, int centerX, int y) {
        if (leaders.isEmpty()) {
            context.drawCenteredTextWithShadow(this.textRenderer, Text.literal("\u00a77Loading..."), centerX, y, 0xAAAAAA);
            return;
        }

        context.drawCenteredTextWithShadow(this.textRenderer, Text.literal("\u00a76Top Players"), centerX, y, 0xFFFFFF);
        y += 16;
        for (int i = 0; i < leaders.size(); i++) {
            LeaderEntry l = leaders.get(i);
            String medal = switch (i) { case 0 -> "\u00a7e\u2B50 "; case 1 -> "\u00a77\u2B50 "; case 2 -> "\u00a76\u2B50 "; default -> "\u00a78" + (i + 1) + ". "; };
            String line = medal + "\u00a7f" + l.name + " \u00a7eLv." + l.level + " \u00a7b" + l.xp + "xp";
            context.drawTextWithShadow(this.textRenderer, Text.literal(line), centerX - 100, y + i * 14, 0xFFFFFF);
        }
    }

    @Override
    public boolean shouldPause() { return false; }

    private record AchEntry(String id, String name, String description, String category, int xpReward) {}
    private record ChallengeEntry(String description, int progress, int required, boolean completed, int xpReward) {}
    private record LeaderEntry(String name, int level, int xp) {}
}
