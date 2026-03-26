# System: Marketplace & Trading

## Backend Endpoints
- `GET /api/marketplace?token=&search=&category=&sort=` — browse listings
- `POST /api/marketplace/list` — create listing
- `POST /api/marketplace/:id/buy` — buy item
- `POST /api/marketplace/:id/bid` — place auction bid
- `DELETE /api/marketplace/:id` — cancel listing
- `GET /api/marketplace/history?token=` — listing history
- `GET /api/marketplace/prices/:itemName` — price history
- `GET /api/marketplace/trending` — trending items
- `POST /api/trades` — create trade offer
- `GET /api/trades?token=` — list trade offers
- `POST /api/trades/:id/accept` — accept trade
- `POST /api/trades/:id/decline` — decline trade

## GUI Components

### Marketplace Panel (marketplace_panel.gd)
- **Browse View:**
  - Search bar at top
  - Category filter dropdown
  - Sort dropdown: Price Low-High, Price High-Low, Newest, Ending Soon
  - Grid of listing cards
  - Each card: item name, price, seller, type badge, time remaining (auction)

- **Listing Detail (popup):**
  - Item name, description, seller
  - Fixed: "Buy Now" button
  - Auction: current bid, your bid input, "Place Bid" button, countdown timer
  - Price history section

- **Sell Tab:**
  - Select from inventory
  - Price input
  - Listing type: Fixed / Auction
  - Auction: starting bid + duration
  - "List Item" button

- **My Listings Tab:**
  - Active listings with cancel button
  - Sold/expired history

- **Trades Tab:**
  - Incoming offers: item lists, accept/decline
  - Outgoing offers: status, cancel
  - "New Trade" button: select player, add items/currency, send

## Existing Code
- `marketplace_manager.gd` — has REST functions, zero UI
- `marketplace-service.ts` — full backend
