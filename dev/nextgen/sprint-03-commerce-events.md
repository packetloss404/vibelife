# Sprint 3: Commerce & Events

**Duration:** 1 week
**Goal:** Complete the marketplace buy/sell flow, event creation and participation,
parcel tier upgrades, and social screen actions.
**Prerequisite:** Sprint 2 complete.

---

## 1. Complete Marketplace Flow

### Paper Commands

**Command:** `/market`

| Subcommand | Description |
|-----------|-------------|
| `/market list <item> <price>` | List held item for sale |
| `/market browse [category]` | Open marketplace (chat-based summary + keybind hint) |
| `/market cancel <id>` | Cancel own listing |
| `/market search <query>` | Search listings by name |

### Fabric MarketplaceScreen Enhancements

The existing `MarketplaceScreen` shows listings but lacks buy/sell actions.

**Add:**
- "Buy" button on each listing row (calls `POST /api/marketplace/buy`)
- "My Listings" tab showing player's active listings with cancel buttons
- Category filter buttons (Blocks, Tools, Equipment, Cosmetics, Other)
- Pagination (Previous/Next buttons, 20 items per page)
- Confirmation dialog before purchase (shows item, price, balance after)
- Sort options: Price Low-High, Price High-Low, Newest, Oldest

**API calls to wire:**
- `POST /api/marketplace/buy` -- purchase a listing
- `DELETE /api/marketplace/listings/:id` -- cancel listing (needs SidecarApi.delete())
- `GET /api/marketplace/listings?category=X&page=N&sort=Y` -- filtered browse

---

## 2. Event Creation and Participation

### Paper Commands

**Command:** `/event`

| Subcommand | Description | Permission |
|-----------|-------------|------------|
| `/event list` | Show upcoming events | default |
| `/event info <id>` | Show event details | default |
| `/event join <id>` | RSVP to an event | default |
| `/event leave <id>` | Cancel RSVP | default |
| `/event create <name>` | Create an event (interactive) | `packetcraft.admin` |

### Fabric EventsScreen Enhancements

**Add:**
- "Join" / "Leave" buttons on each event card
- RSVP count display
- Event countdown timer (time until start)
- "My Events" tab showing events the player has joined
- For admins: "Create Event" button opening a form

**API calls to wire:**
- `POST /api/events/:id/rsvp` -- join event
- `DELETE /api/events/:id/rsvp` -- leave event
- `POST /api/events` -- create event (admin only)

---

## 3. Parcel Tier Upgrades

### Paper Command

| Subcommand | Description |
|-----------|-------------|
| `/parcel upgrade` | Upgrade current parcel to next tier |
| `/parcel info` | Show parcel details including tier |

### Sidecar Changes

- `POST /api/parcels/:id/upgrade` -- upgrade parcel tier
- Deduct upgrade cost from player's economy balance
- Tier progression: Basic (free) -> Standard (500) -> Premium (2000) -> Elite (5000)
- Each tier increases build height limit and block count

### Fabric Integration

- Show parcel tier and upgrade button in a "My Parcel" section (can be part of HomeScreen)
- Display cost of next tier, current balance, and confirmation dialog

---

## 4. Social Screen Actions

### Fabric SocialScreen Enhancements

The existing `SocialScreen` shows a friend list but lacks action buttons.

**Add:**
- "Add Friend" button with player name input field
- "Remove Friend" button on each friend row
- "Block" / "Unblock" toggle on each player
- "Send Message" button opening a DM input
- Online/offline status indicator (green/grey dot)
- "Pending Requests" section showing incoming friend requests with Accept/Reject

**API calls to wire:**
- `POST /api/social/friend-request` -- send friend request
- `POST /api/social/friend-request/:id/accept` -- accept request
- `POST /api/social/friend-request/:id/reject` -- reject request
- `DELETE /api/social/friends/:id` -- remove friend
- `POST /api/social/block` -- block player
- `DELETE /api/social/block/:id` -- unblock player

---

## Acceptance Criteria

- [ ] Full buy flow: browse -> select -> confirm -> purchase -> balance updated
- [ ] Full sell flow: `/market list` -> appears in MarketplaceScreen -> other player buys
- [ ] Events can be created by admins and joined/left by players
- [ ] Parcel upgrade deducts currency and increases tier
- [ ] Social screen friend actions work end-to-end
- [ ] All new endpoints have test coverage (from Sprint 1 patterns)
- [ ] `npm run check` and `./gradlew build` pass
