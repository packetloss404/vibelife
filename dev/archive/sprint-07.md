# Sprint 7: Pets & Homes (Week 7)

## Goal
Full pet management panel and home system with privacy, ratings, and favorites.

## Systems
- [Pets](systems/pets.md)
- [Homes](systems/homes.md)

## Tasks

### 7.1 Pets Panel Tab
**Owner:** Dev 1 + Dev 2
**Files:** New `native-client/godot/scripts/ui/panels/pets_panel.gd`

- Register "Pets" tab in panel manager
- My Pets list with species icon, name, happiness/energy bars
- Active pet highlight
- "Adopt Pet" button -> species selection + naming dialog

### 7.2 Pet Interaction Buttons
**Owner:** Dev 3
**Files:** Modify `pets_panel.gd`

- Selected pet detail view
- Action buttons: Summon, Dismiss, Feed, Play, Pet, Trick
- Trick selector dropdown (only learned tricks)
- Happiness and energy bars update after actions
- Level and XP progress bar

### 7.3 Pet Customization
**Owner:** Dev 4
**Files:** Modify `pets_panel.gd`

- Rename input field
- Color pickers for body/accent color
- Accessory selector: none, bow, hat, scarf, collar, wings, crown
- Preview updates in real-time
- PATCH /api/pets/:id

### 7.4 Pet WS Events & 3D Display
**Owner:** Dev 3 + Dev 4
**Files:** Modify `session_coordinator.gd`, `pet_manager.gd`

- Route pet:summoned/dismissed/trick/state_updated to pet_manager
- Pet appears as 3D mesh following owner avatar
- Trick animation plays on pet:trick event
- Other players' pets visible in world

### 7.5 Home Panel Tab
**Owner:** Dev 5 + Dev 6
**Files:** New `native-client/godot/scripts/ui/panels/home_panel.gd`

- Register "Home" tab in panel manager
- Set Home button (sets current parcel as home)
- Teleport Home button
- Clear Home button
- Privacy selector: Public, Friends Only, Private
- Current home info display

### 7.6 Home Ratings & Favorites
**Owner:** Dev 5 + Dev 6
**Files:** Modify `home_panel.gd`

- Rate other players' homes (1-5 stars)
- Favorite button (heart icon)
- Featured Homes browser (GET /api/homes/featured)
- My Favorites list
- Visitor count display
- Home:doorbell WS event -> toast notification

## WS Events Handled
- `pet:summoned` — spawn pet in world
- `pet:dismissed` — remove pet from world
- `pet:trick` — play trick animation
- `pet:state_updated` — update pet position/state
- `home:doorbell` — show doorbell toast notification

## Definition of Done
- [ ] Can adopt, summon, dismiss pets from GUI
- [ ] Pet interaction buttons all work (feed, play, pet, trick)
- [ ] Pet customization (colors, accessory, rename) works
- [ ] Pets visible in 3D world following owners
- [ ] Home set/teleport/clear works
- [ ] Privacy selector works
- [ ] Can rate and favorite homes
- [ ] Doorbell notifications appear
