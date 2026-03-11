# MMORPG & Social Feature Design

## Why MMORPG Elements Work for VibeLife

VibeLife isn't a traditional MMO, but MMO design principles drive the features that keep people coming back. The key insight: **people don't stay for the game, they stay for the people.** Every feature should strengthen social bonds.

## Social Systems Deep Dive

### 1. Presence & Status System
```
Online States:
- Online (green) - actively in a region
- Busy (yellow) - in build mode or afk
- Away (orange) - idle 10+ minutes
- Invisible (gray) - online but hidden
- Offline (dark) - not connected

Custom Status Messages:
- "Building my dream cafe"
- "Listening to beats at Aurora Docks"
- "Looking for builders for group project"
```

### 2. Social Hub / Town Square
Every server needs a social nexus point:
- **The Lobby** - a beautifully designed default region everyone sees first
- Community bulletin board (events, announcements)
- "Portal Plaza" with teleporters to popular regions
- Featured builds showcase (rotating weekly)
- Newcomer tutorial area
- Real-time population counter per region

### 3. Reputation & Trust System
```
Trust Levels:
- Newcomer (0-24 hours played)
- Resident (24+ hours, verified email)
- Trusted (100+ hours, positive community standing)
- Creator (published marketplace content)
- Mentor (opted-in to help newcomers)
- VIP (premium subscriber)

Trust unlocks:
- Script execution (Resident+)
- Marketplace selling (Creator+)
- Voice chat (Resident+)
- Event creation (Trusted+)
```

### 4. Mentorship Program
- Experienced players opt-in as mentors
- New players can request a mentor
- Mentors get exclusive cosmetic rewards
- Guided tours of best regions/builds
- Building tutorials led by mentors

### 5. Social Feeds & Activity
```
Activity Feed:
- "Diana finished building the Sunset Cafe"
- "Marcus claimed a new parcel in Neon District"
- "The Builders Guild is hosting an event at 8pm"
- "New featured build: Kenji's Zen Garden"

Player can:
- Like/react to activities
- Comment
- Share to friends
- Follow specific players/groups
```

### 6. Neighborhood System
Adjacent parcels form neighborhoods:
- Shared naming (neighborhood identity)
- Neighborhood chat channel
- Shared events calendar
- Collective traffic stats
- Neighborhood beautification competitions

### 7. Guild/Group Advanced Features
```
Guild Features:
- Guild hall (shared parcel space)
- Guild treasury (pooled currency)
- Guild projects (collaborative builds with milestones)
- Guild rankings (optional, friendly competition)
- Guild recruitment board
- Inter-guild alliances
- Guild wars? (building competitions, not combat)

Guild Roles:
- Founder - full control
- Officer - manage members, moderate
- Builder - build permission in guild spaces
- Member - basic access
- Recruit - limited access, probation period
```

### 8. Relationship Depth
```
Beyond binary friends:
- Acquaintance (met in-world)
- Friend (mutual add)
- Close Friend (interact frequently - auto-detected)
- Best Friend (manually designated, limit 5)
- Partner (mutual designation, displayed on profile)

Relationship perks:
- Close Friends: shared teleport, see each other's location
- Best Friends: co-own parcels, shared inventory vault
- Partners: linked profiles, couple emotes, shared home
```

## Chat & Communication Architecture

### Channel System
```
Channels:
- /local - avatars within 20m (default)
- /region - everyone in current region
- /whisper [name] - private 1:1
- /group [name] - group channel
- /trade - marketplace and trading
- /help - questions and support
- /event - current event discussion
- /rp - roleplay (optional per region)
```

### Chat Moderation
- Configurable word filter (region owner controls)
- Spam detection (rate limiting + similarity)
- Report system with evidence (chat logs)
- Temporary mute for violations
- Escalation to global moderators

### Rich Chat Features
- Markdown-lite support (bold, italic, links)
- Item linking (drag item to chat to show it)
- Location sharing (share coordinates as clickable teleport)
- Avatar inspection (click name in chat to view profile)
- Chat history search

## Community Infrastructure

### Events System
```
Event Types:
- Build Competition (judged, prizes)
- Dance Party (DJ sets, music)
- Grand Opening (new region/parcel launch)
- Workshop (learn building/scripting)
- Meetup (casual hangout)
- Concert (scheduled performances)
- Market Day (traders gather)
- Exploration Run (guided region tour)

Event Features:
- Calendar view (daily/weekly/monthly)
- RSVP with reminders
- Recurring events
- Event-specific decorations (auto-placed)
- Live event attendance tracking
- Post-event gallery (auto-screenshots)
```

### Moderation Hierarchy
```
Community Moderators (volunteer, trusted players):
- Can warn, mute, kick from region
- Can file escalation reports
- Get moderator badge

Staff Moderators (paid/core team):
- All community mod powers
- Can ban accounts
- Can reassign parcels
- Can delete content globally

Automated Systems:
- Chat spam detection
- Asset content scanning (future)
- AFK timeout in populated regions
- Unusual currency transaction flagging
```

## Competitive Social Features (Non-Combat)

### Leaderboards (Optional, Regional)
- Most visited parcels this week
- Most creative builds (community voted)
- Most helpful mentor
- Most active group
- Longest exploration streak

### Seasonal Competitions
- Best winter-themed build
- Most creative use of [specific asset]
- Best group collaboration
- Photography contest
- Speedbuild challenge

### Skill Trees (Non-Combat Progression)
```
Builder Track:
- Novice Builder -> Apprentice -> Journeyman -> Master -> Architect
- Each rank unlocks new tools, assets, or build limits

Social Track:
- Newcomer -> Regular -> Social Butterfly -> Community Leader
- Unlocks: chat features, event hosting, mentoring

Explorer Track:
- Tourist -> Traveler -> Explorer -> Cartographer -> World Walker
- Unlocks: fast travel, map features, region discoveries

Creator Track:
- Tinkerer -> Maker -> Creator -> Artisan -> Legendary Creator
- Unlocks: marketplace features, creator tools, custom assets
```

## Implementation Priority for Social Features

| Priority | Feature | Effort | Impact |
|----------|---------|--------|--------|
| P0 | Chat channels + bubbles | 2 weeks | Very High |
| P0 | Presence/status system | 1 week | High |
| P0 | Activity feed | 2 weeks | High |
| P1 | Events system | 3 weeks | Very High |
| P1 | Enhanced groups | 2 weeks | High |
| P1 | Reputation/trust | 2 weeks | Medium |
| P2 | Neighborhood system | 2 weeks | Medium |
| P2 | Leaderboards | 1 week | Medium |
| P2 | Mentorship | 2 weeks | Medium |
| P3 | Skill trees | 3 weeks | Medium |
| P3 | Seasonal competitions | 2 weeks | High |
