# System: Voice Chat

## Backend Endpoints
- `POST /api/voice/join` — join channel (token, regionId)
- `POST /api/voice/leave` — leave channel
- `POST /api/voice/mute` — toggle mute
- `POST /api/voice/deafen` — toggle deafen
- `GET /api/voice/participants?regionId=` — list participants
- `GET /api/voice/status` — speaking status
- `POST /api/voice/status` — update speaking

## GUI Components

### Voice Indicator (TopBar)
- Mic icon: green (active), gray (off), red (muted)
- Click to toggle join/leave voice channel
- Headphone icon for deafen toggle

### Voice Panel (voice_panel_ui.gd)
- **Controls:**
  - Join/Leave button
  - Mute toggle (mic icon)
  - Deafen toggle (headphone icon)
  - Status: Connected/Disconnected

- **Participants List:**
  - Each participant: name, mic icon (red if muted)
  - Speaking indicator: green glow pulse when talking
  - Spatial distance indicator (near/medium/far)

### 3D Integration
- Speaking avatar: mic icon or glow above head
- Spatial audio: volume falloff with distance
- `spatial_audio.gd` calculates volume based on position

### WS Events
- `voice:participant_joined` -> add to participant list, toast
- `voice:participant_left` -> remove from list
- `voice:speaking_changed` -> update speaking indicator glow

## Note
Actual WebRTC audio is out of scope (requires native Godot WebRTC plugin). The GUI manages the signaling and indicators. Voice data would flow peer-to-peer via WebRTC, not through our WS.
