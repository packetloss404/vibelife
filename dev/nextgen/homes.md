# System: Homes

## Backend Endpoints
- `POST /api/homes/set` — set home parcel (token, parcelId)
- `GET /api/homes?token=` — get my home
- `POST /api/homes/teleport` — teleport home
- `DELETE /api/homes` — clear home
- `POST /api/homes/privacy` — set privacy (token, privacy: public|friends|private)
- `POST /api/homes/rate` — rate home (token, parcelId, rating)
- `POST /api/homes/favorite` — favorite home (token, parcelId)
- `GET /api/homes/:parcelId/ratings` — get ratings
- `GET /api/homes/featured` — featured homes
- `GET /api/homes/favorites?token=` — my favorites
- `GET /api/homes/:parcelId/visitors` — visitor count

## GUI Components

### Home Panel (home_panel.gd)
- **My Home Section:**
  - Current home parcel name and location
  - "Set Home" button (sets current parcel)
  - "Teleport Home" button
  - "Clear Home" button
  - Privacy dropdown: Public, Friends Only, Private
  - Visitor count display
  - Average rating display

- **Featured Homes Tab:**
  - Top-rated homes list
  - Each: parcel name, owner, rating stars, visitor count
  - "Visit" button (teleports to home)
  - "Favorite" button (heart toggle)

- **My Favorites Tab:**
  - Favorited homes list with visit/unfavorite buttons

- **Rating Dialog (when visiting someone's home):**
  - 1-5 star selector
  - Submit rating button
  - Shows current average

### WS Events
- `home:doorbell` -> toast: "PlayerName is visiting your home!"
