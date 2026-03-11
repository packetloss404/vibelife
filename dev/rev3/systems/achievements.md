# System: Achievements & Leaderboards

## Backend Endpoints
- `GET /api/achievements` — list all achievements
- `GET /api/progress?token=` — player progress
- `GET /api/progress/challenges?token=` — daily/weekly challenges
- `GET /api/leaderboard?category=` — leaderboard by category
- `GET /api/titles?token=` — available titles
- `POST /api/titles/set` — set active title

## GUI Components

### Achievements Panel (achievements_panel.gd)
- **Achievement Grid:**
  - Card per achievement: icon, name, description, XP reward
  - Progress bar on each (current/required)
  - Locked: grayscale + lock icon overlay
  - Unlocked: full color + checkmark
  - Category tabs: All, Explorer, Builder, Social, Collector, Warrior

- **Challenges Section:**
  - "Daily Challenges" header with refresh timer
  - Each challenge: description, progress bar, XP, expiry countdown
  - "Weekly Challenges" below with same format
  - Completed challenges: strikethrough + green check

- **Leaderboard Tab:**
  - Category dropdown
  - Ranked list: #, name, score
  - Current player highlighted
  - Top 3 get special styling

- **Titles Tab:**
  - List of unlocked titles
  - "Equip" button on each
  - Current active title highlighted
  - Locked titles shown as grayed out with unlock requirement

### Integration Points
- Achievement unlock -> toast notification + sound
- Challenge complete -> toast + progress update
- Level up -> XP bar update + toast
