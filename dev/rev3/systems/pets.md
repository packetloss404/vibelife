# System: Pets

## Backend Endpoints
- `POST /api/pets/adopt` — adopt (token, name, species)
- `GET /api/pets?token=` — list my pets
- `GET /api/pets/active?token=` — active pet
- `POST /api/pets/:id/summon` — summon
- `POST /api/pets/:id/dismiss` — dismiss
- `POST /api/pets/:id/feed` — feed
- `POST /api/pets/:id/play` — play
- `POST /api/pets/:id/pet` — pet
- `POST /api/pets/:id/trick` — perform trick
- `PATCH /api/pets/:id` — rename, customize
- `GET /api/pets/region/:regionId` — region pets

## GUI Components

### Pets Panel (pets_panel.gd)
- **My Pets List:**
  - Each pet: species icon, name, level, happiness/energy bars
  - Active pet highlighted with glow
  - "Adopt" button at bottom

- **Adopt Dialog:**
  - Species grid: cat, dog, bird, bunny, fox, dragon, slime, owl
  - Name input
  - Random name generator button
  - "Adopt" confirm

- **Pet Detail View (selected pet):**
  - Name (editable)
  - Species, rarity, level, XP bar
  - Happiness bar + energy bar
  - Action buttons: Summon/Dismiss, Feed, Play, Pet
  - Trick selector dropdown + "Do Trick" button
  - Customize section: color pickers, accessory dropdown

### 3D Integration
- `pet_manager.gd` spawns pet mesh following owner
- Pet mesh: colored sphere with accessory (similar to avatar style)
- Trick animation: bounce/spin/flip depending on trick
- Other players' pets visible

### WS Events
- `pet:summoned` -> spawn pet in world
- `pet:dismissed` -> despawn pet
- `pet:trick` -> play trick animation + chat message
- `pet:state_updated` -> update position/animation
