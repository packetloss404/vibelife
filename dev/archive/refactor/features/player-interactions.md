# Feature: Player Interactions

**Sprint**: 9
**Status**: Not Started
**Priority**: Medium

## Summary

Right-clicking another player opens a radial interaction menu: trade, friend, whisper, inspect, party invite, guild invite, report. Replaces the current context menu.

## Current State

`context_menu.gd` has basic right-click menu with limited options.

## Target State

### Radial Menu

```gdscript
# Right-click while looking at another player (crosshair on them)
# Opens circular menu around cursor position

var radial_options := [
    { "label": "Trade", "icon": "💰", "action": "trade" },
    { "label": "Add Friend", "icon": "👤", "action": "friend" },
    { "label": "Whisper", "icon": "💬", "action": "whisper" },
    { "label": "Inspect", "icon": "🔍", "action": "inspect" },
    { "label": "Invite to Party", "icon": "👥", "action": "party" },
    { "label": "Invite to Guild", "icon": "🏰", "action": "guild_invite" },
    { "label": "Report", "icon": "⚠", "action": "report" },
]

func _build_radial_menu(target_player_id: String, screen_pos: Vector2) -> void:
    var menu := Control.new()
    var radius := 80.0
    var count := radial_options.size()

    for i in range(count):
        var angle := (float(i) / count) * TAU - PI/2
        var btn := Button.new()
        btn.text = radial_options[i].label
        btn.position = screen_pos + Vector2(cos(angle), sin(angle)) * radius
        btn.pressed.connect(_on_radial_action.bind(radial_options[i].action, target_player_id))
        menu.add_child(btn)
```

### Actions

- **Trade**: Opens trade window (uses existing marketplace-service.ts)
- **Add Friend**: Sends friend request (uses existing social-service.ts)
- **Whisper**: Opens chat with /w <playername> pre-filled
- **Inspect**: Shows popup with player's level, equipment, guild, stats
- **Party Invite**: Sends party invitation
- **Guild Invite**: Sends guild invitation (requires officer role)
- **Report**: Opens report dialog

## Files Modified

| File | Changes |
|------|---------|
| `context_menu.gd` | Refactor to radial menu, connect to existing services |

## Acceptance Criteria

- [ ] Right-click on player opens radial menu
- [ ] All 7 actions functional
- [ ] Menu closes on action or clicking away
- [ ] Inspect shows player info popup
- [ ] Uses existing backend services
