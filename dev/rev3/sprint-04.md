# Sprint 4: Marketplace & Trading (Week 4)

## Goal
Full marketplace browser, listing creation, auction bidding, and peer-to-peer trading.

## Systems
- [Marketplace](systems/marketplace.md)

## Tasks

### 4.1 Marketplace Panel Tab
**Owner:** Dev 1 + Dev 2
**Files:** New `native-client/godot/scripts/ui/panels/marketplace_panel.gd`

- Register "Market" tab in panel manager
- Browse view: grid/list toggle of active listings
- Search bar with text filter
- Category filter dropdown (by item kind)
- Sort by: price, newest, ending soon
- Each listing card: item name, price, seller, type badge (fixed/auction)

### 4.2 Buy & Bid Flow
**Owner:** Dev 3
**Files:** Modify `marketplace_panel.gd`

- Click listing -> detail view
- Fixed price: "Buy Now" button with confirm dialog
- Auction: current bid display, bid input, "Place Bid" button
- Auction timer countdown
- Toast on outbid / auction won

### 4.3 Create Listing
**Owner:** Dev 4
**Files:** Modify `marketplace_panel.gd`

- "Sell Item" button -> dialog
- Select item from inventory
- Set price (fixed) or starting bid + duration (auction)
- Preview before listing
- My Listings sub-tab with cancel option

### 4.4 Trading System
**Owner:** Dev 5 + Dev 6
**Files:** New `native-client/godot/scripts/ui/panels/trade_panel.gd`

- Trade offer creation: select items + currency to offer/request
- Pending trade offers list (incoming/outgoing)
- Accept/Decline buttons
- Trade history
- Right-click player avatar -> "Trade" option

### 4.5 Price History
**Owner:** Dev 4
**Files:** Modify `marketplace_panel.gd`

- GET /api/marketplace/prices/:itemName
- Simple price chart or text-based history
- Shows recent sale prices for an item

## Definition of Done
- [ ] Can browse all marketplace listings with search/filter
- [ ] Can buy fixed-price items
- [ ] Can bid on auctions
- [ ] Can list own items for sale
- [ ] Can create and respond to trade offers
- [ ] Price history visible per item
