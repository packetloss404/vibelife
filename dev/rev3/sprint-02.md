# Sprint 2: Social & Presence (Week 2)

## Goal
Full social system GUI — friends list, friend requests, blocking, profiles, presence status, offline messages.

## Systems
- [Social](systems/social.md)

## Tasks

### 2.1 Social Panel Tab
**Owner:** Dev 1 + Dev 2
**Files:** New `native-client/godot/scripts/ui/panels/social_panel.gd`

- Register "Social" tab in panel manager
- Sub-tabs: Friends, Requests, Blocked, Messages
- Friends list with online/offline/away indicators (colored dots)
- Each friend entry: name, status, region, last seen
- Context menu: Whisper, Visit, Unfriend, Block

### 2.2 Friend Request Flow
**Owner:** Dev 3
**Files:** Modify `social_panel.gd`

- "Add Friend" button with name input dialog
- Incoming request list with Accept/Decline buttons
- Outgoing pending requests display
- Toast notification on new friend request

### 2.3 Player Profile Panel
**Owner:** Dev 4
**Files:** New `native-client/godot/scripts/ui/panels/profile_panel.gd`

- View own profile: bio, stats, world visits, play time
- Edit bio text field
- View other player profiles (right-click avatar -> View Profile)
- Profile shows: display name, title, level, achievements count

### 2.4 Presence Status Selector
**Owner:** Dev 5
**Files:** Modify `social_panel.gd`, `main.gd`

- Status dropdown in sidebar or social panel header: Online, Busy, Away, Invisible
- Custom status message input
- Status persists via REST call
- Friends list updates reflect real-time presence

### 2.5 Offline Messages
**Owner:** Dev 6
**Files:** Modify `social_panel.gd`

- Messages sub-tab shows unread offline messages
- Mark as read on open
- Reply button opens whisper
- Tab badge shows unread count
- Send offline message to friends who are offline

## WS Events Handled
- None new (social is REST-based, presence updates on polling)

## Definition of Done
- [ ] Friends list shows all friends with presence indicators
- [ ] Can add/remove/block friends via GUI
- [ ] Can view and edit own profile
- [ ] Can set presence status from dropdown
- [ ] Offline messages send and receive
- [ ] Tab badge shows unread message count
