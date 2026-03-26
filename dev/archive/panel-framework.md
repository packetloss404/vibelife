# System: Panel Framework & Tab System

## Overview
Replace the hard-coded RightDock with a tabbed panel system that can host unlimited feature panels. Each panel is a self-contained Control node that manages its own UI and data.

## Architecture

### PanelManager (panel_manager.gd)
```gdscript
class_name PanelManager extends Control

var tabs: Dictionary = {}  # name -> { control: Control, badge: int }
var active_tab: String = ""

func register_tab(tab_name: String, control: Control, icon: String = "") -> void
func switch_to(tab_name: String) -> void
func set_badge(tab_name: String, count: int) -> void
func get_active_panel() -> Control
```

### Tab Bar
- Horizontal tab buttons at top of right panel
- Icons + text labels
- Badge circles for unread counts (red dot with number)
- Scrollable if too many tabs (overflow arrows)
- Ctrl+1 through Ctrl+0 for quick switch

### BasePanel (base_panel.gd)
```gdscript
class_name BasePanel extends Control

var main  # reference to main node

func init(main_node) -> void
func _get_base_url() -> String
func _get_token() -> String
func _make_request(method: String, path: String, body: Dictionary = {}) -> Dictionary
func _show_toast(message: String, type: String = "info") -> void
func _on_ws_event(event_type: String, data: Dictionary) -> void
```

### ToastManager (toast_manager.gd)
- Singleton accessible from any panel
- Toasts stack from bottom-right, auto-dismiss after 3-5 seconds
- Types: info (blue), success (green), warning (yellow), error (red)
- Click to dismiss immediately
- Max 5 visible at once

## Default Tabs (in order)
1. Chat
2. Inventory
3. Social
4. Economy
5. Market
6. Guild
7. Achievements
8. Events
9. Pets
10. Photos
11. Home
12. Radio
13. Seasonal
14. Voice
15. Creator (conditional)
16. Admin (conditional)

## WS Event Router
Session coordinator emits a signal for all events. Panels subscribe:
```gdscript
# In session_coordinator.gd
signal ws_event_received(event_type: String, data: Dictionary)

# In any panel
main.session_flow.ws_event_received.connect(_on_ws_event)
```

## Files
- New: `native-client/godot/scripts/ui/panel_manager.gd`
- New: `native-client/godot/scripts/ui/base_panel.gd`
- New: `native-client/godot/scripts/ui/toast_manager.gd`
- Modified: `native-client/godot/scripts/main.gd`
- Modified: `native-client/godot/scenes/main.tscn`
