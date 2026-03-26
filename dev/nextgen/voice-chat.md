# Voice Chat (VoIP)

## Overview

Voice chat enables real-time spatial audio communication between avatars in the same region. This feature uses WebRTC for peer-to-peer audio transmission with the backend coordinating signaling and presence.

## Architecture

```
┌─────────────┐     WebRTC Signaling      ┌─────────────┐
│   Client   │◄─────────────────────────►│   Backend   │
│  (Godot)   │                           │  (Fastify)  │
└──────┬──────┘                           └──────┬──────┘
       │                                          │
       │  Direct WebRTC Audio Streams            │
       │◄────────────────────────────────────────►│
       │                                          │
       ▼                                          ▼
┌─────────────┐                           ┌─────────────┐
│  Nearby    │                           │  STUN/TURN  │
│  Avatars   │                           │   Servers   │
└─────────────┘                           └─────────────┘
```

## Implementation Plan

### 1. Signaling Server (Backend)

Add WebRTC signaling endpoints to `src/server.ts`:

```typescript
// Proposed endpoints
app.post("/api/voice/join", ...)  // Join voice channel for region
app.post("/api/voice/leave", ...) // Leave voice channel
app.get("/ws/voice/:regionId", ...) // WebRTC signaling WebSocket
```

### 2. Client Integration (Godot)

- Integrate Godot 4.x WebRTC module
- Create voice chat UI (mute/deafen controls)
- Implement proximity-based audio attenuation
- Add push-to-talk option

### 3. Audio Processing

- Spatial audio: volume decreases with distance
- Voice activity detection (VAD)
- Echo cancellation using WebRTC AEC
- Noise suppression

## API Contracts

### Join Voice Channel
```typescript
POST /api/voice/join
{
  token: string;
  regionId: string;
}
// Returns: { iceServers: RTCIceServer[] }
```

### WebRTC Signaling Messages
```typescript
type VoiceSignal = 
  | { type: "offer"; sdp: string; from: string; to: string }
  | { type: "answer"; sdp: string; from: string; to: string }
  | { type: "ice-candidate"; candidate: RTCIceCandidate; from: string; to: string };
```

## Dependencies

- `wrtc` or Godot's native WebRTC support
- STUN server (included in common WebRTC setups)
- TURN server for NAT traversal (production)

## Configuration

```typescript
// Environment variables
VOICE_ENABLED=true
STUN_SERVER=stun:stun.l.google.com:19302
TURN_SERVER=turn:turn.example.com:3478
TURN_USERNAME=
TURN_PASSWORD=
```

## Future Enhancements

1. Voice channels (group voice chats)
2. Voice morphing/effects
3. Spatial chat rooms
4. Recording capabilities
