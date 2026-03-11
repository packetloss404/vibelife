# Sprint 8: Photography & Media (Week 8)

## Goal
Camera mode with filters, photo gallery, sharing, and in-world media objects.

## Systems
- [Photography](systems/photography.md)

## Tasks

### 8.1 Camera Mode Toggle
**Owner:** Dev 1 + Dev 2
**Files:** Modify `camera_manager.gd`, `main.gd`

- Hotkey (C) or button to enter camera mode
- First-person camera with mouse look
- Hide all UI except camera overlay
- Crosshair/viewfinder overlay
- Exit with ESC or C again

### 8.2 Photo Capture & Filters
**Owner:** Dev 3
**Files:** Modify `camera_manager.gd`

- Filter selector bar at bottom of screen (8 filters)
- Filter preview: vintage, noir, warm, cool, dreamy, pixel, posterize
- Capture button (or spacebar) takes viewport screenshot
- POST /api/photos with capture data
- Flash animation on capture
- Toast: "Photo saved!"

### 8.3 Photo Gallery Panel
**Owner:** Dev 4 + Dev 5
**Files:** New `native-client/godot/scripts/ui/panels/photos_panel.gd`

- Register "Photos" tab in panel manager
- Sub-tabs: My Photos, Feed, Featured
- Photo grid with thumbnails
- Click photo -> detail view: full image, title, description, likes, comments
- Edit title/description on own photos
- Delete own photos

### 8.4 Photo Social Features
**Owner:** Dev 4
**Files:** Modify `photos_panel.gd`

- Like button (heart) with count
- Comment input + comment list
- Share button (copies link or highlights in feed)
- Visibility toggle: public, friends, private

### 8.5 Media Objects in World
**Owner:** Dev 6
**Files:** Modify `media_manager.gd`, `session_coordinator.gd`

- Handle media:created/updated/removed WS events
- Render media objects in 3D world (photo frames, billboards)
- Photo frames display thumbnail texture on a plane mesh
- Slideshow objects cycle through photos
- Media placement via build mode

## WS Events Handled
- `media:created` — spawn media object in world
- `media:updated` — update media display
- `media:removed` — remove media object

## Definition of Done
- [ ] Camera mode toggles with C key
- [ ] 8 filters selectable and visible
- [ ] Photos capture and upload to server
- [ ] Gallery shows own photos and feed
- [ ] Can like and comment on photos
- [ ] Media objects render in 3D world
- [ ] WS media events handled
