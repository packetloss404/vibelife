# Feature: Chat Overhaul

**Sprint**: 9
**Status**: Not Started
**Priority**: Medium

## Summary

Refactor chat to Minecraft style: messages appear bottom-left and fade after 10 seconds. T opens chat input. / opens with command prefix. Tab-completes player names. Channel colors. Death/achievement/join messages styled.

## Current State

`chat_controller.gd` with always-visible chat log and input in bottom bar. Messages don't fade.

## Target State

### Chat Display

```gdscript
# Messages appear in bottom-left, above hearts
# Each message is a Label that fades after 10 seconds
# Max 10 visible messages at a time
# When chat input is open, all recent messages visible (no fade)

var chat_messages: Array[Dictionary] = []  # { label, timer, max_time }

func add_chat_message(text: String, color: Color = Color.WHITE) -> void:
    var label := RichTextLabel.new()
    label.text = text
    label.fit_content = true
    label.bbcode_enabled = true
    label.add_theme_color_override("default_color", color)
    label.modulate = Color(1, 1, 1, 1)
    chat_container.add_child(label)

    chat_messages.append({ "label": label, "timer": 0.0, "max_time": 10.0 })

    # Remove oldest if > 100 total
    while chat_messages.size() > 100:
        var old: Dictionary = chat_messages.pop_front()
        old.label.queue_free()

func _process_chat_fade(delta: float) -> void:
    if chat_input_open:
        # Show all messages while typing
        for msg in chat_messages:
            msg.label.modulate.a = 1.0
        return

    for msg in chat_messages:
        msg.timer += delta
        if msg.timer > msg.max_time - 2.0:
            # Fade out over last 2 seconds
            msg.label.modulate.a = max(0.0, (msg.max_time - msg.timer) / 2.0)
```

### Chat Input

```gdscript
var chat_input_open := false
var chat_input: LineEdit

func open_chat(prefix: String = "") -> void:
    chat_input_open = true
    chat_input.text = prefix
    chat_input.visible = true
    chat_input.grab_focus()
    main.release_mouse()

func close_chat() -> void:
    chat_input_open = false
    chat_input.visible = false
    main.capture_mouse()

# Input handling:
# T key → open_chat("")
# / key → open_chat("/")
# Enter → send message, close chat
# Escape → close chat without sending
# Up arrow → cycle through message history
# Tab → autocomplete player name
```

### Commands

```
/w <player> <message>  → Whisper (uses existing whisper system)
/r <message>           → Reply to last whisper
/me <action>           → Action message: "* PlayerName action"
/home                  → Teleport home
/spawn                 → Teleport to spawn
/guild <message>       → Guild chat
/party <message>       → Party chat
/trade <message>       → Trade channel
```

### Message Formatting

```
Player chat:    <PlayerName> message          (white)
Whisper in:     PlayerName whispers: message  (light purple)
Whisper out:    You whisper to Player: msg    (light purple)
System:         message                       (yellow)
Death:          PlayerName was slain by Mob   (red)
Achievement:    Player earned [Achievement]!  (green)
Join:           PlayerName joined the game    (yellow)
Leave:          PlayerName left the game      (yellow)
Action:         * PlayerName does something   (italic, light gray)
Guild:          [Guild] PlayerName: message   (green)
Party:          [Party] PlayerName: message   (cyan)
Trade:          [Trade] PlayerName: message   (light orange)
```

## Files Modified

| File | Changes |
|------|---------|
| `chat_controller.gd` | Complete rewrite for fade system |
| `main.gd` | T and / key handling, chat state |

## Acceptance Criteria

- [ ] Messages fade after 10 seconds
- [ ] T opens chat input at bottom
- [ ] / opens chat with "/" prefix
- [ ] Enter sends, Escape cancels
- [ ] Tab autocompletes player names
- [ ] Up arrow cycles history
- [ ] Commands work: /w, /r, /me, /home, /spawn
- [ ] Channel color prefixes
- [ ] Death/achievement/join messages styled
- [ ] All messages visible while input is open
