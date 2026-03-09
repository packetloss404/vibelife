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
- includes a cleaner docked HUD with top status, left login/build controls, and right inventory/chat panels
- supports click-selecting world objects and dragging native gizmo axes
- supports equip and use actions from the native inventory panel
- saves backend/display-name profiles locally in the native client
- draws parcel overlays and ownership colors directly in the 3D world
- can claim active parcels from the native HUD
- can also release parcels you own from the native HUD
- saves fullscreen, mouse sensitivity, invert look, FOV, and shadow settings locally
- supports guest, register, and login account modes, plus admin parcel/object moderation when logged into an admin account
- saved backend profiles now remember the selected auth mode for faster account switching
- admin accounts can now review audit history directly in the native HUD
- for admin bootstrap in development, set `ADMIN_BOOTSTRAP_TOKEN` on the backend and use that token during registration

## Open it

1. Install Godot 4.2+.
2. Open `native-client/godot/project.godot`.
3. Run the project.
4. Point the backend field to your server, for example `http://127.0.0.1:3000`.

## Desktop export scaffold

- export presets now live in `native-client/godot/export_presets.cfg`
- default outputs target:
  - `build/windows/ThirdLifeNative.exe`
  - `build/linux/thirdlife-native.x86_64`
  - `build/macos/ThirdLifeNative.zip`
- in Godot, install the matching export templates, then use `Project -> Export`
- update icons, signing, and bundle identifiers before shipping

## Notes

- The client first tries imported local glTF assets and falls back to simple native placeholder geometry when needed.
- Build mode in the native client currently uses click-to-place plus keyboard transforms: arrows move, `Q/E` rotate, `R/F` scale, `Delete` removes.
- Native manipulation modes let you drag selected objects, rotate them with the wheel, or scale them without dropping back to the browser client.
- Godot-authored gizmo handles now appear around the current selection for clearer native editing feedback.
- It already connects to the real backend API and WebSocket flow.
- The browser client remains in `public/` as a debug/admin prototype, not the primary viewer.
