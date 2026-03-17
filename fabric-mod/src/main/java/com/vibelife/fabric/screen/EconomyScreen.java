package com.vibelife.fabric.screen;

import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.vibelife.fabric.VibeLifeClient;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.client.gui.screen.Screen;
import net.minecraft.client.gui.widget.ButtonWidget;
import net.minecraft.client.gui.widget.TextFieldWidget;
import net.minecraft.text.Text;

import java.util.ArrayList;
import java.util.List;

/**
 * Economy GUI screen showing:
 *   - Current balance (top)
 *   - Send currency form (player name + amount)
 *   - Recent transaction history (scrollable list)
 *
 * Opened via V keybind.
 */
public class EconomyScreen extends Screen {

    private double balance = 0;
    private boolean balanceLoaded = false;
    private final List<TransactionEntry> transactions = new ArrayList<>();
    private boolean transactionsLoaded = false;

    private TextFieldWidget recipientField;
    private TextFieldWidget amountField;
    private String statusMessage = "";
    private int statusColor = 0xFFFFFF;

    public EconomyScreen() {
        super(Text.literal("VibeLife Economy"));
    }

    @Override
    protected void init() {
        super.init();

        int centerX = this.width / 2;
        int startY = 50;

        // Recipient field
        recipientField = new TextFieldWidget(this.textRenderer, centerX - 100, startY + 30, 120, 20, Text.literal("Player name"));
        recipientField.setPlaceholder(Text.literal("Player name"));
        recipientField.setMaxLength(32);
        this.addDrawableChild(recipientField);

        // Amount field
        amountField = new TextFieldWidget(this.textRenderer, centerX + 30, startY + 30, 60, 20, Text.literal("Amount"));
        amountField.setPlaceholder(Text.literal("Amount"));
        amountField.setMaxLength(10);
        this.addDrawableChild(amountField);

        // Send button
        this.addDrawableChild(ButtonWidget.builder(Text.literal("Send"), button -> sendCurrency())
                .dimensions(centerX + 100, startY + 30, 50, 20)
                .build());

        // Refresh button
        this.addDrawableChild(ButtonWidget.builder(Text.literal("Refresh"), button -> fetchData())
                .dimensions(centerX + 60, startY - 5, 60, 20)
                .build());

        // Close button
        this.addDrawableChild(ButtonWidget.builder(Text.literal("Close"), button -> close())
                .dimensions(centerX - 30, this.height - 30, 60, 20)
                .build());

        // Fetch data on open
        fetchData();
    }

    private void fetchData() {
        var api = VibeLifeClient.getInstance().getSidecarApi();

        api.getBalance().thenAccept(response -> {
            if (response.has("balance")) {
                balance = response.get("balance").getAsDouble();
                balanceLoaded = true;
            }
        });

        api.getTransactions(20).thenAccept(response -> {
            if (response.has("transactions") && response.get("transactions").isJsonArray()) {
                JsonArray arr = response.getAsJsonArray("transactions");
                transactions.clear();
                for (JsonElement el : arr) {
                    JsonObject tx = el.getAsJsonObject();
                    transactions.add(new TransactionEntry(
                            tx.has("type") ? tx.get("type").getAsString() : "?",
                            tx.has("amount") ? tx.get("amount").getAsInt() : 0,
                            tx.has("description") ? tx.get("description").getAsString() : "",
                            tx.has("createdAt") ? tx.get("createdAt").getAsString() : ""
                    ));
                }
                transactionsLoaded = true;
            }
        });
    }

    private void sendCurrency() {
        String recipient = recipientField.getText().trim();
        String amountText = amountField.getText().trim();

        if (recipient.isEmpty() || amountText.isEmpty()) {
            statusMessage = "Enter player name and amount";
            statusColor = 0xFF5555;
            return;
        }

        int amount;
        try {
            amount = Integer.parseInt(amountText);
        } catch (NumberFormatException e) {
            statusMessage = "Amount must be a number";
            statusColor = 0xFF5555;
            return;
        }

        if (amount <= 0) {
            statusMessage = "Amount must be positive";
            statusColor = 0xFF5555;
            return;
        }

        statusMessage = "Sending...";
        statusColor = 0xFFFF55;

        var api = VibeLifeClient.getInstance().getSidecarApi();
        String token = VibeLifeClient.getInstance().getSessionToken();

        if (token == null) {
            statusMessage = "Not logged in";
            statusColor = 0xFF5555;
            return;
        }

        // Use the token-based send endpoint (player-initiated transfer)
        api.post("/api/currency/send", java.util.Map.of(
                "token", token,
                "toAccountId", recipient, // TODO: resolve player name -> accountId
                "amount", amount,
                "description", "sent via economy screen"
        )).thenAccept(response -> {
            if (response.has("balance")) {
                balance = response.get("balance").getAsDouble();
                statusMessage = "Sent " + amount + " Vibes!";
                statusColor = 0x55FF55;
                recipientField.setText("");
                amountField.setText("");
                fetchData(); // Refresh transactions
            } else {
                String error = response.has("error") ? response.get("error").getAsString() : "transfer failed";
                statusMessage = error;
                statusColor = 0xFF5555;
            }
        }).exceptionally(ex -> {
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
        int startY = 50;

        // Title
        context.drawCenteredTextWithShadow(this.textRenderer, Text.literal("\u00a76\u00a7lVibeLife Economy"), centerX, 15, 0xFFFFFF);

        // Balance
        String balanceText = balanceLoaded ? String.format("%.0f Vibes", balance) : "Loading...";
        context.drawCenteredTextWithShadow(this.textRenderer, Text.literal("\u00a7eBalance: \u00a7f" + balanceText), centerX - 30, startY, 0xFFFFFF);

        // Send label
        context.drawTextWithShadow(this.textRenderer, Text.literal("\u00a7fSend:"), centerX - 130, startY + 35, 0xFFFFFF);

        // Status message
        if (!statusMessage.isEmpty()) {
            context.drawCenteredTextWithShadow(this.textRenderer, Text.literal(statusMessage), centerX, startY + 55, statusColor);
        }

        // Transaction history header
        int txStartY = startY + 75;
        context.drawCenteredTextWithShadow(this.textRenderer, Text.literal("\u00a76Recent Transactions"), centerX, txStartY, 0xFFFFFF);

        if (!transactionsLoaded) {
            context.drawCenteredTextWithShadow(this.textRenderer, Text.literal("\u00a77Loading..."), centerX, txStartY + 15, 0xAAAAAA);
        } else if (transactions.isEmpty()) {
            context.drawCenteredTextWithShadow(this.textRenderer, Text.literal("\u00a77No transactions yet"), centerX, txStartY + 15, 0xAAAAAA);
        } else {
            int y = txStartY + 15;
            int maxVisible = Math.min(transactions.size(), (this.height - y - 40) / 12);
            for (int i = 0; i < maxVisible; i++) {
                TransactionEntry tx = transactions.get(i);
                String color = tx.amount >= 0 ? "\u00a7a+" : "\u00a7c";
                String line = color + tx.amount + " \u00a77" + tx.type + " \u00a78" + tx.description;
                context.drawTextWithShadow(this.textRenderer, Text.literal(line), centerX - 150, y, 0xFFFFFF);
                y += 12;
            }
        }
    }

    @Override
    public boolean shouldPause() {
        return false;
    }

    private record TransactionEntry(String type, int amount, String description, String createdAt) {}
}
