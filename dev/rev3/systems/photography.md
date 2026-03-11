# System: Photography & Media

## Backend Endpoints
- `POST /api/photos` — take photo
- `GET /api/photos?token=&filter=&visibility=` — list photos
- `GET /api/photos/feed` — photo feed
- `GET /api/photos/featured` — featured photos
- `GET /api/photos/gallery/:accountId` — player gallery
- `GET /api/photos/:id` — single photo
- `DELETE /api/photos/:id` — delete photo
- `POST /api/photos/:id/like` — like/unlike
- `POST /api/photos/:id/comment` — add comment
- `POST /api/media` — create media object
- `PATCH /api/media/:id` — update media
- `DELETE /api/media/:id` — remove media

## GUI Components

### Camera Mode
- Toggle with C key or button
- First-person camera (hide avatar, UI)
- Viewfinder overlay (thin border frame)
- Filter bar at bottom: 8 filter buttons with preview tint
- Capture: Spacebar or click
- Flash effect on capture
- Captured photo: title/description input, visibility selector, save button

### Photos Panel (photos_panel.gd)
- **My Photos Tab:**
  - Photo grid with thumbnails
  - Click to view detail
  - Delete button on own photos

- **Feed Tab:**
  - Recent photos from all players
  - Like button (heart + count)
  - Comment count

- **Featured Tab:**
  - Curated/trending photos

- **Photo Detail View:**
  - Full-size image display
  - Title, description, photographer, timestamp
  - Filter badge
  - Like button + like count
  - Comment list + "Add Comment" input
  - Visibility toggle (own photos)

### Media Objects in World
- Photo frames: plane mesh with photo texture
- Billboards: larger plane on billboard object
- Slideshow: cycling through photos on timer
- Build mode: "Place Media" creates media object, assign photo

### WS Events
- `media:created` -> spawn media mesh in world
- `media:updated` -> refresh media texture
- `media:removed` -> despawn media mesh
