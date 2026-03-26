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
 * Events GUI showing:
 *   - Upcoming events with name, type, time, attendee count
 *   - RSVP button
 *   - All events list
 *
 * Opened via K keybind.
 */
public class EventsScreen extends Screen {

    private final List<EventEntry> events = new ArrayList<>();
    private boolean dataLoaded = false;
    private String statusMessage = "";
    private int statusColor = 0xFFFFFF;

    public EventsScreen() {
        super(Text.literal("PacketCraft Events"));
    }

    @Override
    protected void init() {
        super.init();
        int centerX = this.width / 2;

        this.addDrawableChild(ButtonWidget.builder(Text.literal("Refresh"), b -> fetchData())
                .dimensions(centerX + 60, 30, 60, 20).build());
        this.addDrawableChild(ButtonWidget.builder(Text.literal("Close"), b -> close())
                .dimensions(centerX - 30, this.height - 30, 60, 20).build());

        fetchData();
    }

    private void fetchData() {
        dataLoaded = false;
        PacketCraftClient.getInstance().getSidecarApi().get("/api/events/upcoming?limit=20").thenAccept(resp -> {
            events.clear();
            if (resp.has("events") && resp.get("events").isJsonArray()) {
                for (JsonElement el : resp.getAsJsonArray("events")) {
                    JsonObject e = el.getAsJsonObject();
                    events.add(new EventEntry(
                            e.has("id") ? e.get("id").getAsString() : "",
                            e.has("name") ? e.get("name").getAsString() : "?",
                            e.has("eventType") ? e.get("eventType").getAsString() : "?",
                            e.has("regionId") ? e.get("regionId").getAsString() : "",
                            e.has("startTime") ? e.get("startTime").getAsString() : "",
                            e.has("endTime") ? e.get("endTime").getAsString() : "",
                            e.has("attendeeCount") ? e.get("attendeeCount").getAsInt() : 0,
                            e.has("maxAttendees") ? e.get("maxAttendees").getAsInt() : 0
                    ));
                }
            }
            dataLoaded = true;
        }).exceptionally(ex -> {
            dataLoaded = true;
            return null;
        });
    }

    private void rsvpEvent(String eventId) {
        String token = PacketCraftClient.getInstance().getSessionToken();
        if (token == null) {
            statusMessage = "Not logged in";
            statusColor = 0xFF5555;
            return;
        }

        statusMessage = "RSVPing...";
        statusColor = 0xFFFF55;

        PacketCraftClient.getInstance().getSidecarApi()
                .post("/api/events/" + eventId + "/rsvp", Map.of("token", token))
                .thenAccept(resp -> {
                    if (resp.has("event")) {
                        statusMessage = "RSVP confirmed!";
                        statusColor = 0x55FF55;
                        fetchData();
                    } else {
                        statusMessage = resp.has("error") ? resp.get("error").getAsString() : "RSVP failed";
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

        context.drawCenteredTextWithShadow(this.textRenderer, Text.literal("\u00a76\u00a7lPacketCraft Events"), centerX, 12, 0xFFFFFF);

        if (!statusMessage.isEmpty()) {
            context.drawCenteredTextWithShadow(this.textRenderer, Text.literal(statusMessage), centerX, this.height - 45, statusColor);
        }

        int y = 55;

        if (!dataLoaded) {
            context.drawCenteredTextWithShadow(this.textRenderer, Text.literal("\u00a77Loading..."), centerX, y, 0xAAAAAA);
            return;
        }

        if (events.isEmpty()) {
            context.drawCenteredTextWithShadow(this.textRenderer, Text.literal("\u00a77No upcoming events"), centerX, y, 0xAAAAAA);
            return;
        }

        // Header
        context.drawTextWithShadow(this.textRenderer, Text.literal("\u00a76Event"), centerX - 150, y, 0xFFFFFF);
        context.drawTextWithShadow(this.textRenderer, Text.literal("\u00a76Type"), centerX - 20, y, 0xFFFFFF);
        context.drawTextWithShadow(this.textRenderer, Text.literal("\u00a76When"), centerX + 50, y, 0xFFFFFF);
        context.drawTextWithShadow(this.textRenderer, Text.literal("\u00a76Ppl"), centerX + 130, y, 0xFFFFFF);
        y += 14;

        int maxVisible = Math.min(events.size(), (this.height - y - 50) / 16);
        for (int i = 0; i < maxVisible; i++) {
            EventEntry e = events.get(i);
            int lineY = y + i * 16;

            String name = e.name.length() > 18 ? e.name.substring(0, 17) + "\u2026" : e.name;
            context.drawTextWithShadow(this.textRenderer, Text.literal("\u00a7f" + name), centerX - 150, lineY, 0xFFFFFF);

            String typeColor = switch (e.eventType) {
                case "concert" -> "\u00a7d";
                case "build_competition" -> "\u00a7b";
                case "market_day" -> "\u00a7e";
                default -> "\u00a77";
            };
            context.drawTextWithShadow(this.textRenderer, Text.literal(typeColor + e.eventType), centerX - 20, lineY, 0xFFFFFF);

            String time = e.startTime.length() > 10 ? e.startTime.substring(5, 16).replace("T", " ") : e.startTime;
            context.drawTextWithShadow(this.textRenderer, Text.literal("\u00a77" + time), centerX + 50, lineY, 0xAAAAAA);

            String capacity = e.maxAttendees > 0 ? e.attendeeCount + "/" + e.maxAttendees : String.valueOf(e.attendeeCount);
            context.drawTextWithShadow(this.textRenderer, Text.literal("\u00a7f" + capacity), centerX + 130, lineY, 0xFFFFFF);
        }
    }

    @Override
    public boolean mouseClicked(double mouseX, double mouseY, int button) {
        if (button == 0) {
            int centerX = this.width / 2;
            int y = 69;
            for (int i = 0; i < events.size(); i++) {
                int lineY = y + i * 16;
                if (mouseX >= centerX - 150 && mouseX <= centerX + 155 && mouseY >= lineY && mouseY < lineY + 16) {
                    rsvpEvent(events.get(i).id);
                    return true;
                }
            }
        }
        return super.mouseClicked(mouseX, mouseY, button);
    }

    @Override
    public boolean shouldPause() { return false; }

    private record EventEntry(String id, String name, String eventType, String regionId, String startTime, String endTime, int attendeeCount, int maxAttendees) {}
}
