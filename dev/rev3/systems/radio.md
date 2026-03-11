# System: Radio

## Backend Endpoints
- `GET /api/radio/stations` — list stations
- WS: `radio:tune` command — tune to station
- WS: `radio:skip` command — skip track
- WS: `radio:changed` event — station changed

## GUI Components

### Radio Panel / Mini-Player
- **Mini-Player (TopBar):**
  - Station name + current track name (scrolling text if long)
  - Play/pause (visual only), skip button
  - Click to expand full panel

- **Radio Panel (radio_panel.gd):**
  - Station list with genre labels
  - Each station: name, genre badge, track count
  - "Tune" button on each (sends radio:tune WS command)
  - Currently playing station highlighted
  - Now Playing section: station name, track name, track progress
  - Skip button (sends radio:skip WS command)
  - Volume slider (client-side AudioStreamPlayer volume)

### Integration
- `radio_controller.gd` already handles audio playback
- Panel provides the missing visual controls
- radio:changed WS event updates the now-playing display

## Existing Code
- `radio_controller.gd` — handles playback, no UI
- `radio-service.ts` — station management backend
