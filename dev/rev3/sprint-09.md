# Sprint 9: Radio, Seasonal, Voice (Week 9)

## Goal
Radio station picker, seasonal content browser, and voice chat indicators.

## Systems
- [Radio](systems/radio.md)
- [Seasonal](systems/seasonal.md)
- [Voice](systems/voice.md)

## Tasks

### 9.1 Radio Panel
**Owner:** Dev 1 + Dev 2
**Files:** New `native-client/godot/scripts/ui/panels/radio_panel.gd`

- Register "Radio" tab in panel manager (or mini-player in TopBar)
- Station list with genre labels
- Current station highlight
- Now Playing display: station name + track name
- Tune button (sends radio:tune WS command)
- Skip button (sends radio:skip WS command)
- Volume slider (client-side only)
- Mini-player mode: small bar at top showing current track

### 9.2 Seasonal Panel Tab
**Owner:** Dev 3 + Dev 4
**Files:** New `native-client/godot/scripts/ui/panels/seasonal_panel.gd`

- Register "Seasonal" tab in panel manager
- Current season display with themed header
- Active holidays list
- Seasonal items grid: collectible items with rarity badges
- "Collect" button on available items
- Collection progress bar
- Seasonal achievements list
- Seasonal leaderboard

### 9.3 Seasonal Theme Application
**Owner:** Dev 4
**Files:** Modify `seasonal_manager.gd`, `sky_manager.gd`, `weather_system.gd`

- Fetch region theme (GET /api/seasonal/theme/:regionId)
- Apply fog color, sun color, sky tint from theme
- Spawn seasonal ambient particles
- Seasonal decorations in world

### 9.4 Voice Chat Panel
**Owner:** Dev 5 + Dev 6
**Files:** New `native-client/godot/scripts/ui/panels/voice_panel_ui.gd`

- Voice indicator in TopBar (mic icon)
- Join/Leave voice channel button
- Mute toggle button (mic on/off)
- Deafen toggle button (headphone on/off)
- Participant list with speaking indicators (green glow when speaking)
- Spatial audio: volume adjusts based on distance

### 9.5 Voice WS Events
**Owner:** Dev 6
**Files:** Modify `session_coordinator.gd`

- Handle voice:participant_joined -> add to participant list
- Handle voice:participant_left -> remove from list
- Handle voice:speaking_changed -> update speaking indicator
- Speaking avatar gets indicator above their 3D model

## WS Events Handled
- `radio:changed` — already handled, add panel update
- `voice:participant_joined` — update voice panel
- `voice:participant_left` — update voice panel
- `voice:speaking_changed` — update speaking indicator

## Definition of Done
- [ ] Radio station list with tune/skip controls
- [ ] Now Playing display updates in real-time
- [ ] Seasonal items browsable and collectible
- [ ] Season theme applies to world visuals
- [ ] Voice join/leave/mute/deafen controls work
- [ ] Voice participant list with speaking indicators
- [ ] All 3 systems at 100% GUI coverage
