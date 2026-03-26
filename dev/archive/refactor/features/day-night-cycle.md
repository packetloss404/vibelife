# Feature: Day/Night Cycle

**Sprint**: 6
**Status**: Not Started
**Priority**: Medium-High

## Summary

Implement a 20-minute real-time day/night cycle with sun/moon orbit, sky color transitions, star field, and mob spawning tied to time of day. Server tracks and broadcasts world time.

## Current State

`day_night_cycle.gd` exists with basic time-of-day tracking but no sun/moon meshes, no server sync, and no mob spawning integration.

## Target State

### Time System

```
Total cycle: 20 real minutes = 1200 seconds = 24000 ticks (1 tick = 0.05s)

Day:     tick 0 - 12000 (10 minutes)
Sunset:  tick 12000 - 13800 (1.5 minutes)
Night:   tick 13800 - 22200 (7 minutes)
Sunrise: tick 22200 - 24000 (1.5 minutes)

Server broadcasts world_time tick every 5 seconds for sync.
Client interpolates between syncs.
```

### Server

```typescript
// In region state
let worldTime = 0  // 0-23999
const TICK_INTERVAL = 50  // 50ms per tick = 20 ticks/second

setInterval(() => {
  worldTime = (worldTime + 1) % 24000
  // Broadcast every 100 ticks (5 seconds)
  if (worldTime % 100 === 0) {
    broadcastToRegion(regionId, { type: "world:time", tick: worldTime })
  }
}, TICK_INTERVAL)

// Bed sleeping: if all players in region are in bed, skip to tick 0
function trySkipNight(regionId: string): void {
  const players = getPlayersInRegion(regionId)
  if (players.every(p => p.inBed) && worldTime > 12000) {
    worldTime = 0
    broadcastToRegion(regionId, { type: "world:time", tick: 0 })
    broadcastToRegion(regionId, { type: "chat", message: "Good morning!", channel: "system" })
  }
}
```

### Client: Sky

```gdscript
func _get_sky_color(tick: int) -> Color:
    var t := float(tick) / 24000.0  # 0.0 to 1.0

    # Day: bright blue
    # Sunset: orange/pink
    # Night: dark blue
    # Sunrise: pink/orange

    if t < 0.5:  # Day
        return Color(0.45, 0.65, 1.0)
    elif t < 0.575:  # Sunset transition
        var blend := (t - 0.5) / 0.075
        return Color(0.45, 0.65, 1.0).lerp(Color(0.9, 0.5, 0.3), blend)
    elif t < 0.6:  # Late sunset
        var blend := (t - 0.575) / 0.025
        return Color(0.9, 0.5, 0.3).lerp(Color(0.05, 0.05, 0.15), blend)
    elif t < 0.925:  # Night
        return Color(0.05, 0.05, 0.15)
    else:  # Sunrise
        var blend := (t - 0.925) / 0.075
        return Color(0.05, 0.05, 0.15).lerp(Color(0.45, 0.65, 1.0), blend)
```

### Sun/Moon

```gdscript
func _update_celestials(tick: int) -> void:
    var angle := (float(tick) / 24000.0) * TAU  # Full rotation

    # Sun
    sun_mesh.position = Vector3(
        cos(angle) * 200.0,
        sin(angle) * 200.0,
        0
    )
    sun_mesh.visible = sin(angle) > -0.1  # Visible during day + horizon

    # Moon (opposite side)
    moon_mesh.position = Vector3(
        cos(angle + PI) * 200.0,
        sin(angle + PI) * 200.0,
        0
    )
    moon_mesh.visible = sin(angle + PI) > -0.1

    # Directional light follows sun
    sun_light.rotation.x = -angle + PI/2
    sun_light.light_energy = clamp(sin(angle) * 2.0, 0.1, 1.5)
```

## Files Modified

| File | Changes |
|------|---------|
| `day_night_cycle.gd` | 20-min cycle, server sync, celestial positions |
| `sky_manager.gd` | Time-based sky gradient |
| `src/server.ts` | World time tick loop, broadcast |
| `src/contracts.ts` | Add `world:time` event, bed sleep command |

## Acceptance Criteria

- [ ] 20-minute full day/night cycle
- [ ] Sun and moon visible in sky
- [ ] Sky color transitions smoothly
- [ ] Stars at night
- [ ] Server tracks and broadcasts time
- [ ] Client syncs to server time
- [ ] Bed sleeping skips to dawn (when all players sleep)
- [ ] Hostile mobs spawn at night
- [ ] Light level changes with time of day
