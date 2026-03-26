package com.packetcraft.fabric.network;

import com.packetcraft.fabric.PacketCraftClient;
import com.packetcraft.fabric.hud.AchievementToast;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.fabricmc.fabric.api.networking.v1.PayloadTypeRegistry;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.network.codec.PacketCodec;
import net.minecraft.network.packet.CustomPayload;
import net.minecraft.util.Identifier;

import java.io.ByteArrayInputStream;
import java.io.DataInputStream;
import java.io.IOException;

/**
 * Handles incoming plugin messages from the Paper plugin via custom payload.
 *
 * Message types (encoded as DataOutputStream UTF strings):
 *   - "session" + token -> store session token for API calls
 *   - "achievement" + id + name + description -> show achievement toast
 *   - "balance" + amount -> update cached balance
 *   - "event_start" + eventId + eventName -> show event notification
 *   - "event_end" + eventId -> clear event notification
 */
public class PluginChannelHandler {

    public record PacketCraftPayload(byte[] data) implements CustomPayload {
        public static final Id<PacketCraftPayload> ID = new Id<>(Identifier.of("packetcraft", "main"));
        public static final PacketCodec<PacketByteBuf, PacketCraftPayload> CODEC = PacketCodec.of(
                (payload, buf) -> buf.writeByteArray(payload.data),
                buf -> new PacketCraftPayload(buf.readByteArray())
        );

        @Override
        public Id<? extends CustomPayload> getId() {
            return ID;
        }
    }

    public static void register() {
        PayloadTypeRegistry.playS2C().register(PacketCraftPayload.ID, PacketCraftPayload.CODEC);

        ClientPlayNetworking.registerGlobalReceiver(PacketCraftPayload.ID, (payload, context) -> {
            byte[] data = payload.data();
            context.client().execute(() -> handleMessage(data));
        });

        PacketCraftClient.LOGGER.info("Plugin channel registered: " + PacketCraftPayload.ID.id());
    }

    private static void handleMessage(byte[] data) {
        try {
            DataInputStream in = new DataInputStream(new ByteArrayInputStream(data));
            String type = in.readUTF();

            switch (type) {
                case "session" -> {
                    String token = in.readUTF();
                    PacketCraftClient.getInstance().setSessionToken(token);
                }
                case "achievement" -> {
                    String id = in.readUTF();
                    String name = in.readUTF();
                    String description = in.readUTF();
                    AchievementToast.show(name, description);
                }
                case "balance" -> {
                    String amount = in.readUTF();
                    PacketCraftClient.LOGGER.debug("Balance updated: " + amount);
                }
                case "event_start" -> {
                    String eventId = in.readUTF();
                    String eventName = in.readUTF();
                    PacketCraftClient.LOGGER.info("Event started: " + eventName);
                }
                case "event_end" -> {
                    String eventId = in.readUTF();
                    PacketCraftClient.LOGGER.info("Event ended: " + eventId);
                }
                case "pong" -> PacketCraftClient.LOGGER.debug("Pong received");
                default -> PacketCraftClient.LOGGER.warn("Unknown plugin message type: " + type);
            }
        } catch (IOException e) {
            PacketCraftClient.LOGGER.error("Failed to read plugin message", e);
        }
    }
}
