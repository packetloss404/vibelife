# ThirdLife Native Client

This Godot 4 project is now the primary client direction for ThirdLife.

## What it does today

- loads regions from the existing TypeScript backend
- authenticates with the guest login endpoint
- connects to the existing region WebSocket
- renders avatars and world objects in a native 3D scene
- loads imported glTF world assets from `native-client/godot/assets/models`
- supports basic third-person camera orbit and WASD movement
- includes native login, region selection, chat, and inventory panels
- includes native object placement, selection, duplication, deletion, and transform hotkeys
- includes parcel-aware build checks and native move/rotate/scale manipulation modes

## Open it

1. Install Godot 4.2+.
2. Open `native-client/godot/project.godot`.
3. Run the project.
4. Point the backend field to your server, for example `http://127.0.0.1:3000`.

## Notes

- The client first tries imported local glTF assets and falls back to simple native placeholder geometry when needed.
- Build mode in the native client currently uses click-to-place plus keyboard transforms: arrows move, `Q/E` rotate, `R/F` scale, `Delete` removes.
- Native manipulation modes let you drag selected objects, rotate them with the wheel, or scale them without dropping back to the browser client.
- It already connects to the real backend API and WebSocket flow.
- The browser client remains in `public/` as a debug/admin prototype, not the primary viewer.
