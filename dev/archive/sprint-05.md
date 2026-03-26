# Sprint 5: Guilds & Group Chat (Week 5)

## Goal
Full guild management panel with treasury, roles, alliances, and real-time group chat.

## Systems
- [Guilds](systems/guilds.md)

## Tasks

### 5.1 Guild Panel Tab
**Owner:** Dev 1 + Dev 2
**Files:** New `native-client/godot/scripts/ui/panels/guild_panel.gd`

- Register "Guild" tab in panel manager
- If no guild: "Create Guild" button + "Browse Guilds" list
- If in guild: guild name, description, member count, emblem display
- Sub-tabs: Members, Treasury, Settings, Alliances

### 5.2 Guild Members & Roles
**Owner:** Dev 3
**Files:** Modify `guild_panel.gd`

- Member roster with role badges (Owner, Officer, Member)
- Role management: promote/demote (if officer+)
- Invite player button
- Kick member button (if officer+)
- Leave guild button

### 5.3 Guild Treasury
**Owner:** Dev 4
**Files:** Modify `guild_panel.gd`

- Treasury balance display
- Deposit button with amount input
- Withdraw button (owner/officer only)
- Transaction history for guild treasury
- GET/POST /api/groups/:id/treasury/*

### 5.4 Guild Customization
**Owner:** Dev 5
**Files:** Modify `guild_panel.gd`

- Emblem color picker (PATCH /api/groups/:id/emblem)
- Banner color picker (PATCH /api/groups/:id/banner)
- Guild description editor
- Guild parcels management (assign/unassign)

### 5.5 Group Chat Integration
**Owner:** Dev 6
**Files:** Modify `session_coordinator.gd`, chat tab

- Handle `group:chat` WS event
- Group chat sub-channel in Chat tab
- Channel selector: Region | Guild | Whisper
- Guild chat messages show guild tag
- Send group_chat commands via WS

### 5.6 Alliance System
**Owner:** Dev 5 + Dev 6
**Files:** Modify `guild_panel.gd`

- Alliances sub-tab
- Send alliance request to another guild
- Accept/decline incoming requests
- List current allies

## WS Events Handled
- `group:chat` — display in guild chat channel

## Definition of Done
- [ ] Can create/join/leave guilds
- [ ] Member roster with role management
- [ ] Treasury deposit/withdraw/history works
- [ ] Guild emblem/banner customization
- [ ] Group chat works in real-time
- [ ] Alliance system functional
