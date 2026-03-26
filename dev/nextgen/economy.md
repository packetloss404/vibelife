# System: Economy & Currency

## Backend Endpoints
- `GET /api/currency/balance?token=` — get balance
- `POST /api/currency/send` — send currency (token, toAccountId, amount)
- `GET /api/currency/transactions?token=` — transaction history

## GUI Components

### Currency HUD (in TopBar)
- Coin icon + amount label, always visible when in-world
- Animated count change (lerp to new value)
- Click to open Economy panel

### Economy Panel (economy_panel.gd)
- **Balance Display:** Large number with coin icon
- **Send Currency:**
  - Recipient name input
  - Amount input (number)
  - "Send" button with confirm dialog
  - Validation: can't send more than balance

- **Transaction History:**
  - Scrollable list
  - Each entry: icon (by type), description, amount (+green/-red), timestamp
  - Type icons: gift, cart, sword, skull, coin, tax
  - Filter buttons: All, Income, Expenses

### Integration Points
- `combat:loot` WS event -> update balance + floating "+X coins"
- `combat:death` WS event -> update balance + floating "-X coins"
- Marketplace buy/sell -> update balance
- Friend gift -> update balance + toast

## Existing Code
- `economy-service.ts` — full backend
- `routes/economy.ts` — all endpoints
- No client GUI exists
