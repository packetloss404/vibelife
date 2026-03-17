package com.vibelife.fabric.network;

import com.vibelife.fabric.VibeLifeClient;
import com.vibelife.fabric.hud.AchievementToast;
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
 * Handles incoming plugin messages from the Spigot plugin via custom payload.
 *
 * Message types (encoded as DataOutputStream UTF strings):
 *   - "session" + token -> store session token for API calls
 *   - "achievement" + id + name + description -> show achievement toast
 *   - "balance" + amount -> update cached balance
 *   - "event_start" + eventId + eventName -> show event notification
 *   - "event_end" + eventId -> clear event notification
 */
public class PluginChannelHandler {

    public record VibeLifePayload(byte[] data) implements CustomPayload {
        public static final Id<VibeLifePayload> ID = new Id<>(Identifier.of("vibelife", "main"));
        public static final PacketCodec<PacketByteBuf, VibeLifePayload> CODEC = PacketCodec.of(
                (payload, buf) -> buf.writeByteArray(payload.data),
                buf -> new VibeLifePayload(buf.readByteArray())
        );

        @Override
        public Id<? extends CustomPayload> getId() {
            return ID;
        }
    }

    public static void register() {
        PayloadTypeRegistry.playS2C().register(VibeLifePayload.ID, VibeLifePayload.CODEC);

        ClientPlayNetworking.registerGlobalReceiver(VibeLifePayload.ID, (payload, context) -> {
            byte[] data = payload.data();
            context.client().execute(() -> handleMessage(data));
        });

        VibeLifeClient.LOGGER.info("Plugin channel registered: " + VibeLifePayload.ID.id());
    }

    private static void handleMessage(byte[] data) {
        try {
            DataInputStream in = new DataInputStream(new ByteArrayInputStream(data));
            String type = in.readUTF();

            switch (type) {
                case "session" -> {
                    String token = in.readUTF();
                    VibeLifeClient.getInstance().setSessionToken(token);
                }
                case "achievement" -> {
                    String id = in.readUTF();
                    String name = in.readUTF();
                    String description = in.readUTF();
                    AchievementToast.show(name, description);
                }
                case "balance" -> {
                    String amount = in.readUTF();
                    VibeLifeClient.LOGGER.debug("Balance updated: " + amount);
                }
                case "event_start" -> {
                    String eventId = in.readUTF();
                    String eventName = in.readUTF();
                    VibeLifeClient.LOGGER.info("Event started: " + eventName);
                }
                case "event_end" -> {
                    String eventId = in.readUTF();
                    VibeLifeClient.LOGGER.info("Event ended: " + eventId);
                }
                case "pong" -> VibeLifeClient.LOGGER.debug("Pong received");
                default -> VibeLifeClient.LOGGER.warn("Unknown plugin message type: " + type);
            }
        } catch (IOException e) {
            VibeLifeClient.LOGGER.error("Failed to read plugin message", e);
        }
    }
}
