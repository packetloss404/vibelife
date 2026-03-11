# Experimental Godot Scripts

These scripts are intentionally parked outside the primary runtime surface.

They were generated or drafted for future feature exploration, but they are not wired into `native-client/godot/scripts/main.gd` and should not be treated as production client modules.

Current archived areas:
- `ui/mobile_companion.gd`
- `ui/creator_dashboard.gd`
- `ui/server_browser.gd`
- `ui/voice_manager.gd`
- `ui/vr_manager.gd`
- `ui/vr_hands.gd`
- `world/npc_manager.gd`

Promote a script back into the active client only after:
1. the backend contract is verified,
2. the scene/runtime wiring is implemented,
3. duplicate network plumbing is removed,
4. the feature is covered by a concrete manual or automated verification path.
