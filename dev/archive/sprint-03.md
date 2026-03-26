# Sprint 3: Economy & Currency (Week 3)

## Goal
Currency balance always visible, send currency dialog, full transaction history.

## Systems
- [Economy](systems/economy.md)

## Tasks

### 3.1 Currency HUD
**Owner:** Dev 1
**Files:** Modify `main.gd`, `main.tscn`

- Persistent currency display in TopBar (coin icon + amount)
- Updates on: login, transaction, loot, death penalty
- Animated count-up/down on change
- Click opens Economy panel

### 3.2 Economy Panel Tab
**Owner:** Dev 2 + Dev 3
**Files:** New `native-client/godot/scripts/ui/panels/economy_panel.gd`

- Register "Economy" tab in panel manager
- Shows current balance prominently
- "Send Currency" button -> dialog: recipient name, amount, confirm
- Transaction history list (scrollable, paginated)
- Each transaction: type icon, amount (+/-), description, timestamp
- Filter by type: all, gifts, purchases, sales, loot, penalties

### 3.3 Transaction History
**Owner:** Dev 4
**Files:** Modify `economy_panel.gd`

- Fetch GET /api/currency/transactions
- Color-coded: green for income, red for outgoing
- Type icons: gift, cart, sword (loot), skull (death penalty)
- Date grouping (Today, Yesterday, This Week)

### 3.4 Currency Feedback Integration
**Owner:** Dev 5 + Dev 6
**Files:** Modify `combat_hud.gd`, `session_coordinator.gd`

- Loot drops show "+50 coins" floating text
- Death penalty shows "-25 coins" floating text
- Marketplace purchases/sales trigger currency HUD update
- Toast: "Received 100 coins from PlayerName"

## WS Events Handled
- `combat:loot` — already handled, add currency HUD update
- `combat:death` — already handled, add penalty display

## Definition of Done
- [ ] Currency balance visible in TopBar at all times
- [ ] Can send currency to another player via GUI
- [ ] Transaction history shows all past transactions
- [ ] Loot/death currency changes reflected immediately
- [ ] Animated balance changes
