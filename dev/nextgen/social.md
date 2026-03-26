# System: Social

## Backend Endpoints
- `GET /api/friends?token=` — list friends
- `POST /api/friends` — send friend request (token, friendAccountId)
- `DELETE /api/friends` — remove friend (token, friendAccountId)
- `POST /api/friends/block` — block account
- `DELETE /api/friends/block` — unblock account
- `GET /api/presence/:accountId` — get presence
- `POST /api/presence/status` — set status (token, status, customMessage)
- `GET /api/presence/friends?token=` — friends presence
- `GET /api/messages/offline?token=` — get offline messages
- `POST /api/messages/offline` — send offline message
- `PATCH /api/messages/offline/read` — mark as read
- `GET /api/avatar/profile/:accountId` — view profile
- `PATCH /api/avatar/profile` — edit profile (token, bio)

## GUI Components

### Social Panel (social_panel.gd)
- **Friends Sub-Tab:**
  - VBoxContainer of friend entries
  - Each entry: ColorRect row with avatar icon, name, status dot (green/yellow/red/gray), region name
  - Right-click: Whisper, Visit, Unfriend, Block
  - "Add Friend" button at bottom with popup dialog

- **Requests Sub-Tab:**
  - Incoming requests with Accept/Decline buttons
  - Outgoing pending requests with Cancel button

- **Blocked Sub-Tab:**
  - Blocked accounts list with Unblock button

- **Messages Sub-Tab:**
  - Offline message list: sender, preview, timestamp
  - Click to expand and read
  - Mark as read automatically
  - Reply button
  - Badge count on tab

### Profile Viewer
- Triggered by right-click avatar -> "View Profile"
- Popup window showing: name, title, bio, level, playtime, achievements count
- Edit button for own profile

### Presence Selector
- Dropdown in sidebar or social panel header
- Options: Online, Busy, Away, Invisible
- Custom status text input below dropdown

## Existing Code
- `social_manager.gd` — has REST call functions, no UI
- Backend: `social-service.ts`, `routes/social.ts`
