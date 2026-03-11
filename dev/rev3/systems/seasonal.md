# System: Seasonal Content

## Backend Endpoints
- `GET /api/seasonal/current` — current season + holidays
- `GET /api/seasonal/items` — available seasonal items
- `POST /api/seasonal/items/:id/collect` — collect item
- `GET /api/seasonal/progress?token=` — collection progress
- `GET /api/seasonal/decorations/:regionId` — region decorations
- `POST /api/seasonal/decorations` — place decoration
- `GET /api/seasonal/achievements` — seasonal achievements
- `GET /api/seasonal/leaderboard` — seasonal leaderboard
- `GET /api/seasonal/theme/:regionId` — region visual theme

## GUI Components

### Seasonal Panel (seasonal_panel.gd)
- **Season Header:**
  - Current season name + icon (flower/sun/leaf/snowflake)
  - Active holiday name if applicable
  - Season progress bar (days remaining)

- **Items Tab:**
  - Grid of seasonal items with rarity color borders
  - Each item: icon, name, rarity, type badge
  - "Collect" button on available items
  - Collected items show checkmark
  - Collection progress: X/Y items collected

- **Achievements Tab:**
  - Seasonal-specific achievements
  - Same format as main achievements

- **Leaderboard Tab:**
  - Seasonal collection leaderboard
  - Rank, name, items collected

### World Theme Integration
- `seasonal_manager.gd` applies theme to sky, fog, particles
- Fetch theme on region join
- Holiday decorations spawn as objects in world
- Ambient particle type changes per season (cherry blossoms, fireflies, leaves, snow)
