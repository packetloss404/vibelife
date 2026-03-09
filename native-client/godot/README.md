# ThirdLife Native Client

This Godot 4 project is now the primary client direction for ThirdLife.

## What it does today

- loads regions from the existing TypeScript backend
- authenticates with the guest login endpoint
- connects to the existing region WebSocket
- renders avatars and world objects in a native 3D scene
- supports basic third-person camera orbit and WASD movement

## Open it

1. Install Godot 4.2+.
2. Open `native-client/godot/project.godot`.
3. Run the project.
4. Point the backend field to your server, for example `http://127.0.0.1:3000`.

## Notes

- The current native client uses Godot-generated placeholder geometry for backend assets.
- It already connects to the real backend API and WebSocket flow.
- The browser client remains in `public/` as a debug/admin prototype, not the primary viewer.
