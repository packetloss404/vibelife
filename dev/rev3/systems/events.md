# System: Events

## Backend Endpoints
- `GET /api/events?regionId=` — list events
- `GET /api/events/upcoming` — upcoming events
- `POST /api/events` — create event
- `POST /api/events/:id/rsvp` — toggle RSVP
- `DELETE /api/events/:id` — cancel event

## GUI Components

### Events Panel (events_panel.gd)
- **Upcoming Events List:**
  - Each event: name, type icon, date/time, region, RSVP count
  - Type icons for: build_competition, dance_party, concert, workshop, etc.
  - RSVP button (toggle, shows "Going" when active)
  - Click to expand: full description, prizes, creator

- **Create Event Button:**
  - Dialog: name, type dropdown, description
  - Region selector (current region default)
  - Date/time pickers
  - Recurring: none/daily/weekly/monthly
  - Max attendees (optional)
  - Prizes description (optional)

- **My Events Tab:**
  - Events I created with edit/cancel
  - Events I RSVP'd to

### WS Events
- `event:started` -> toast: "Event X is starting now!" + highlight
- `event:ended` -> update panel, remove from active
