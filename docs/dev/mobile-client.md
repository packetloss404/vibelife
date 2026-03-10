# Mobile Client

## Overview

A React Native mobile client enables players to access the virtual world from iOS and Android devices. The client connects to the existing backend APIs and WebSocket for real-time updates.

## Technology Stack

```yaml
Framework: React Native 0.76+
Language: TypeScript
State: Zustand
3D Engine: React Native Skia / Three.js RN
Navigation: React Navigation 7
Networking: Fetch API + Socket.io-client
Styling: NativeWind (Tailwind CSS)
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Mobile App                             │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │  Auth    │  │  World   │  │ Inventory│  │ Profile  │  │
│  │  Screen  │  │  Screen  │  │  Screen  │  │  Screen  │  │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘  │
│       │             │             │             │          │
│  ┌────▼─────────────▼─────────────▼─────────────▼─────┐  │
│  │                    API Layer                         │  │
│  │  - REST Client (fetch)                              │  │
│  │  - WebSocket Manager                                │  │
│  │  - Auth Token Handler                               │  │
│  └──────────────────────┬──────────────────────────────┘  │
│                         │                                   │
│  ┌──────────────────────▼──────────────────────────────┐  │
│  │               State Management (Zustand)            │  │
│  │  - Session Store                                    │  │
│  │  - World State                                      │  │
│  │  - Inventory                                        │  │
│  └─────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                      Backend                                │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐       │
│  │ REST API    │  │ WebSocket   │  │   Postgres  │       │
│  │  (Fastify)  │  │  (Region)   │  │             │       │
│  └─────────────┘  └─────────────┘  └─────────────┘       │
└─────────────────────────────────────────────────────────────┘
```

## Screen Design

### 1. Login Screen
- Guest/Register/Login tabs
- Backend URL configuration
- Remember me checkbox

### 2. Region Browser
- Grid/list of available regions
- Population indicators
- Region preview thumbnail
- Teleport button

### 3. World Screen (3D View)
- Simplified 3D avatar representation
- Touch joystick for movement
- Mini-map in corner
- Quick action bar (chat, inventory, map)
- Gesture controls (pinch zoom, rotate)

### 4. Inventory Screen
- Tabbed categories (Wearables, Objects, Land)
- Item cards with icons
- Equip/wear actions
- Drag to organize

### 5. Profile Screen
- Avatar preview
- Bio editor
- Stats (world visits, member since)
- Friend list
- Settings

### 6. Map Screen
- Region map overlay
- Parcel boundaries
- Teleport to locations
- Friend locations

### 7. Chat Screen
- Region chat
- Friend whispers
- Group chat
- Message history

## Implementation

### 1. Project Setup

```bash
npx react-native@latest init ThirdLifeMobile
cd ThirdLifeMobile
npm install zustand @react-navigation/native @react-navigation/bottom-tabs
npm install three @react-three/fiber @react-three/drei
npm install react-native-gesture-handler react-native-reanimated
npm install socket.io-client
```

### 2. API Client

```typescript
// src/api/client.ts
import { API_BASE, WS_BASE } from '@env';

class APIClient {
  private token: string | null = null;
  
  async request<T>(endpoint: string, options?: RequestInit): Promise<T> {
    const headers: HeadersInit = {
      'Content-Type': 'application/json',
    };
    
    if (this.token) {
      headers['Authorization'] = `Bearer ${this.token}`;
    }
    
    const response = await fetch(`${API_BASE}${endpoint}`, {
      ...options,
      headers,
    });
    
    if (!response.ok) {
      throw new Error(`API Error: ${response.status}`);
    }
    
    return response.json();
  }
  
  // Auth
  async guestLogin(displayName: string) {
    return this.request<LoginResponse>('/api/auth/guest', {
      method: 'POST',
      body: JSON.stringify({ displayName }),
    });
  }
  
  // ... other endpoints
}

export const api = new APIClient();
```

### 3. WebSocket Manager

```typescript
// src/api/websocket.ts
import { io, Socket } from 'socket.io-client';

class WSManager {
  private socket: Socket | null = null;
  
  connect(token: string, regionId: string) {
    this.socket = io(`${WS_BASE}/regions/${regionId}`, {
      auth: { token },
      transports: ['websocket'],
    });
    
    this.socket.on('snapshot', (data) => {
      // Update world state
    });
    
    this.socket.on('connect', () => {
      console.log('WS connected');
    });
  }
  
  send(type: string, data: unknown) {
    this.socket?.emit(type, data);
  }
  
  disconnect() {
    this.socket?.disconnect();
  }
}

export const ws = new WSManager();
```

### 4. State Management

```typescript
// src/stores/worldStore.ts
import { create } from 'zustand';

interface WorldState {
  session: Session | null;
  avatars: Map<string, AvatarState>;
  objects: RegionObject[];
  parcels: Parcel[];
  
  // Actions
  setSession: (session: Session) => void;
  updateAvatar: (avatar: AvatarState) => void;
  removeAvatar: (avatarId: string) => void;
  // ...
}

export const useWorldStore = create<WorldState>((set) => ({
  session: null,
  avatars: new Map(),
  objects: [],
  parcels: [],
  
  setSession: (session) => set({ session }),
  updateAvatar: (avatar) => set((state) => {
    const avatars = new Map(state.avatars);
    avatars.set(avatar.avatarId, avatar);
    return { avatars };
  }),
  // ...
}));
```

### 5. 3D View Component

```typescript
// src/components/WorldView.tsx
import { Canvas } from '@react-three/fiber';
import { OrbitControls, useGLTF } from '@react-three/drei';

function Avatar({ state }) {
  const { scene } = useGLTF('/models/avatar.glb');
  return <primitive object={scene} position={[state.x, state.y, state.z]} />;
}

function WorldScene({ avatars, objects }) {
  return (
    <>
      <ambientLight />
      <directionalLight position={[10, 10, 5]} />
      {Array.from(avatars.values()).map((avatar) => (
        <Avatar key={avatar.avatarId} state={avatar} />
      ))}
      {objects.map((obj) => (
        <primitive key={obj.id} position={[obj.x, obj.y, obj.z]} {...} />
      ))}
    </>
  );
}

export function WorldView() {
  const avatars = useWorldStore((s) => s.avatars);
  const objects = useWorldStore((s) => s.objects);
  
  return (
    <Canvas camera={{ position: [0, 10, 20], fov: 60 }}>
      <WorldScene avatars={avatars} objects={objects} />
      <OrbitControls />
    </Canvas>
  );
}
```

### 6. Touch Controls

```typescript
// src/components/Joystick.tsx
import { Gesture, GestureDetector } from 'react-native-gesture-handler';
import Animated, { useSharedValue } from 'react-native-reanimated';

export function MovementJoystick() {
  const position = useSharedValue({ x: 0, y: 0 });
  
  const pan = Gesture.Pan()
    .onUpdate((e) => {
      position.value = {
        x: clamp(e.x / 150, -1, 1),
        y: clamp(e.y / 150, -1, 1),
      };
    })
    .onEnd(() => {
      position.value = { x: 0, y: 0 };
    });
  
  return (
    <GestureDetector gesture={pan}>
      <Animated.View style={styles.joystick} />
    </GestureDetector>
  );
}
```

## Mobile-Specific Features

### Offline Mode
- Cache recent regions
- Queue actions when offline
- Sync on reconnect

### Push Notifications
- Friend online status
- Group invites
- Region events

### Camera
- Front/back camera for AR features
- Photo capture for profiles

### Haptics
- Movement feedback
- Interaction feedback
- Notification alerts

## Build Configuration

### iOS (Xcode)
- Minimum iOS 14
- Device families: iPhone, iPad
- Capabilities: Push Notifications

### Android (Gradle)
- minSdkVersion: 24
- targetSdkVersion: 34
- Required: INTERNET, ACCESS_NETWORK_STATE

## Performance Considerations

| Optimization | Implementation |
|--------------|----------------|
| 3D LOD | Reduce geometry at distance |
| Texture compression | ASTC format |
| Frustum culling | Only render visible objects |
| Texture atlasing | Combine small textures |
| Code splitting | Lazy load screens |

## API Coverage

The mobile client uses the same backend APIs:

| Feature | Endpoint |
|---------|----------|
| Auth | `/api/auth/*` |
| Regions | `/api/regions` |
| Objects | `/api/regions/:id/objects` |
| Inventory | `/api/inventory/*` |
| Chat | WebSocket |
| Movement | WebSocket |
| Profile | `/api/avatar/profile` |
| Friends | `/api/friends` |
| Currency | `/api/currency/*` |

## Testing

```bash
# iOS Simulator
npm run ios

# Android Emulator
npm run android

# E2E Tests
npx detox test
```

## Future Enhancements

1. AR passthrough mode
2. Voice chat integration
3. Video streaming
4. Screen sharing
5. Social features (events, groups)
