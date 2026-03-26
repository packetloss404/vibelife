# System: Guilds & Group Chat

## Backend Endpoints
- `POST /api/groups` — create group
- `GET /api/groups?token=` — list my groups
- `GET /api/groups/:id/details` — group details
- `POST /api/groups/:id/join` — join group
- `POST /api/groups/:id/leave` — leave group
- `GET /api/groups/:id/members` — member list
- `PATCH /api/groups/:id/members/:accountId/role` — change role
- `DELETE /api/groups/:id/members/:accountId` — kick member
- `POST /api/groups/:id/treasury/deposit` — deposit currency
- `POST /api/groups/:id/treasury/withdraw` — withdraw currency
- `GET /api/groups/:id/treasury/balance` — treasury balance
- `GET /api/groups/:id/treasury/history` — treasury history
- `PATCH /api/groups/:id/emblem` — set emblem
- `PATCH /api/groups/:id/banner` — set banner
- `POST /api/groups/:id/parcels` — assign parcel
- `GET /api/groups/:id/parcels` — list parcels
- `DELETE /api/groups/:id/parcels` — unassign parcel
- `POST /api/groups/:id/alliances` — propose alliance
- `GET /api/groups/:id/alliances` — list alliances
- `DELETE /api/groups/:id/alliances/:allyId` — dissolve alliance

## GUI Components

### Guild Panel (guild_panel.gd)
- **No Guild State:**
  - "Create Guild" button with name/description input
  - Browse guilds list with join button

- **In Guild State:**
  - Guild header: name, emblem, member count
  - Sub-tabs: Members, Treasury, Settings, Alliances

- **Members Tab:**
  - Member roster with role badges (crown/shield/person)
  - Promote/demote buttons (officer+)
  - Kick button (officer+)
  - Invite button

- **Treasury Tab:**
  - Balance display
  - Deposit amount input + button
  - Withdraw amount input + button (restricted)
  - Transaction history list

- **Settings Tab (owner/officer):**
  - Description editor
  - Emblem color picker
  - Banner color picker
  - Parcel assignment list

- **Alliances Tab:**
  - Current allies list
  - Send alliance request
  - Accept/decline incoming

### Group Chat
- Chat tab gets channel selector: Region | Guild
- Guild messages prefixed with guild tag
- WS group:chat events display in guild channel

## Existing Code
- `guild_manager.gd` — partial functions
- `guild-service.ts` — full backend
