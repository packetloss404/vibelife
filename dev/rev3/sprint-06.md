# Sprint 6: Achievements & Events (Week 6)

## Goal
Achievement progress display, daily/weekly challenges, leaderboards, titles, and event calendar.

## Systems
- [Achievements](systems/achievements.md)
- [Events](systems/events.md)

## Tasks

### 6.1 Achievements Panel Tab
**Owner:** Dev 1 + Dev 2
**Files:** New `native-client/godot/scripts/ui/panels/achievements_panel.gd`

- Register "Achievements" tab in panel manager
- Grid of achievement cards with progress bars
- Category filter: Explorer, Builder, Social, Collector, Warrior
- Locked vs unlocked visual state (grayscale vs color)
- XP reward displayed on each achievement
- Total XP and current level display

### 6.2 Daily & Weekly Challenges
**Owner:** Dev 3
**Files:** Modify `achievements_panel.gd`

- Sub-section: "Today's Challenges" and "Weekly Challenges"
- Each challenge: description, progress bar, XP reward
- Auto-refresh on timer
- Toast notification when challenge completed
- Expiry countdown

### 6.3 Leaderboard Browser
**Owner:** Dev 4
**Files:** Modify `achievements_panel.gd`

- Sub-tab: Leaderboards
- Category selector: XP, Builder, Social, Combat, etc.
- Top 10/25/50 display with rank, name, score
- Highlight current player's rank
- GET /api/leaderboard?category=

### 6.4 Title Selector
**Owner:** Dev 3
**Files:** Modify `achievements_panel.gd`

- List of unlocked titles
- "Set Active" button
- Title shows next to display name in chat/profile
- GET /api/titles, POST /api/titles/set

### 6.5 Events Panel Tab
**Owner:** Dev 5 + Dev 6
**Files:** New `native-client/godot/scripts/ui/panels/events_panel.gd`

- Register "Events" tab in panel manager
- Upcoming events list with type icons
- Each event: name, type, time, region, RSVP count, creator
- RSVP button (toggle)
- "Create Event" dialog: name, type, region, start/end time, description
- My Events sub-tab

### 6.6 Event WS Handlers
**Owner:** Dev 6
**Files:** Modify `session_coordinator.gd`

- Handle `event:started` — toast notification + highlight in events panel
- Handle `event:ended` — remove from active events

## WS Events Handled
- `event:started` — show notification and update events panel
- `event:ended` — update events panel

## Definition of Done
- [ ] Achievement grid with progress bars
- [ ] Daily/weekly challenges with countdown
- [ ] Leaderboard browser works
- [ ] Can select and display titles
- [ ] Event calendar shows upcoming events
- [ ] Can create events and RSVP
- [ ] Event start/end notifications work
