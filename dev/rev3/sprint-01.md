# Sprint 1: Foundation (Week 1)

## Goal
Fix viewport scaling, build the panel/tab framework, create WS event router. This sprint produces zero user-visible features but is the foundation everything else depends on.

## Tasks

### 1.1 Viewport & Resolution Fix
**Owner:** Dev 1
**Files:** `native-client/godot/project.godot`, `native-client/godot/scenes/main.tscn`

- Set `window/stretch/mode` to `canvas_items`
- Set `window/stretch/aspect` to `expand`
- Set base resolution to 1280x720
- Convert all UI nodes from absolute positioning to anchor-based layout
- Sidebar: anchor LEFT, full height
- TopBar: anchor TOP, full width
- BuildPanel: anchor BOTTOM_LEFT
- RightDock: anchor RIGHT, full height
- Test at 1280x720, 1920x1080, 2560x1440, windowed resize
- Ensure 3D viewport fills remaining space

### 1.2 Tabbed Panel System
**Owner:** Dev 2
**Files:** New `native-client/godot/scripts/ui/panel_manager.gd`

- Create TabContainer or custom tab bar on the right side
- Default tabs: Chat, Inventory
- Tab registration API: `panel_manager.register_tab(name, control_node)`
- Tab switching with keyboard shortcuts (Ctrl+1 through Ctrl+9)
- Tab notification badges (unread count indicator)
- Responsive height — fills available space

### 1.3 WebSocket Event Router
**Owner:** Dev 3
**Files:** Modify `native-client/godot/scripts/network/session_coordinator.gd`

- Add signal-based event routing system
- `signal ws_event(event_type: String, data: Dictionary)`
- Session coordinator emits signal for every WS event
- Panels connect to `ws_event` and filter by type
- Handle ALL 14 currently-ignored event types:
  - `pet:summoned`, `pet:dismissed`, `pet:trick`, `pet:state_updated`
  - `media:created`, `media:updated`, `media:removed`
  - `voice:participant_joined`, `voice:participant_left`, `voice:speaking_changed`
  - `group:chat`
  - `home:doorbell`
  - `event:started`, `event:ended`

### 1.4 Base Panel Template
**Owner:** Dev 4
**Files:** New `native-client/godot/scripts/ui/base_panel.gd`

- Abstract base class for all feature panels
- Provides: `_get_base_url()`, `_get_token()`, `_make_request()`, `_show_toast()`
- Standard header/body/footer layout
- Loading spinner for async operations
- Error display pattern
- Scroll container for long content

### 1.5 Toast/Notification System
**Owner:** Dev 5
**Files:** New `native-client/godot/scripts/ui/toast_manager.gd`

- Floating notifications that stack and auto-dismiss
- Types: info, success, warning, error
- Used by all panels for feedback
- Replaces current `status_label.text` pattern for in-game feedback
- Handles doorbell, level up, loot, achievement unlock notifications

### 1.6 Migrate Existing UI
**Owner:** Dev 6
**Files:** `main.gd`, `main.tscn`

- Move chat into Chat tab of new panel system
- Move inventory into Inventory tab
- Preserve all existing signal wiring
- Remove hard-coded RightDock layout
- Ensure build panel still works alongside new tabs

## Definition of Done
- [ ] Window resizes correctly at all tested resolutions
- [ ] Tab system shows Chat and Inventory tabs
- [ ] WS events route to panels via signals
- [ ] Toast notifications appear and auto-dismiss
- [ ] All existing features still work (regression check)
