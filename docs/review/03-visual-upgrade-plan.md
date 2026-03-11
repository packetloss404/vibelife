# Visual Upgrade Plan - Making VibeLife Beautiful

## Current State

The visual presentation is "developer prototype" - functional but not inviting. The procedurally generated glTF assets are geometric placeholders. The UI is clean but generic. There's no visual identity that says "this is VibeLife."

## The Vibe We're Going For

VibeLife should feel like stepping into a lo-fi hip-hop album cover that came alive. Think:
- **Studio Ghibli meets Minecraft meets Animal Crossing** - warm, handcrafted, inviting
- **Lo-fi aesthetic** - soft lighting, warm colors, slight grain/noise, dreamy atmospherics
- **Cozy creative space** - like a well-decorated room where you want to spend time
- **Sunset/golden hour** - perpetual magic hour lighting as the default mood

## Visual Identity System

### Color Palette
```
Primary:     #FF9B71 (Warm Sunset Orange)
Secondary:   #7EC8E3 (Soft Sky Blue)
Accent:      #C8B6FF (Lo-fi Purple)
Chill:       #98D8AA (Garden Green)
Warm:        #FFD6A5 (Honey Gold)
Dark:        #1A1B2E (Night Indigo)
Surface:     #2D2E4A (Deep Twilight)
Text:        #E8E4F0 (Soft Lavender White)
```

### Typography
- **Display:** A rounded, friendly font (Nunito, Quicksand, or custom)
- **Body:** Clean sans-serif (Inter, Plus Jakarta Sans)
- **Monospace:** For builder/code elements (JetBrains Mono)

### Logo Direction
- Wordmark with gentle wave/pulse animation
- Could incorporate a sunset, vinyl record, or plant motif
- Must work at small sizes (avatar badges, favicon)

## Godot Client Visual Upgrades

### 1. Shader System (HIGH PRIORITY)
```
Implement custom shaders for:
- Toon/cel-shading for characters and objects
- Soft ambient occlusion
- Distance fog with color gradients
- Water shader with reflections
- Grass/foliage sway shader
- Day/night cycle with color temperature shifts
- Particle systems (fireflies, dust motes, cherry blossoms)
```

### 2. Lighting Overhaul
- Replace single directional light with a full lighting rig
- Add warm point lights around lanterns and buildings
- Volumetric light shafts through trees
- Ambient light color based on time of day
- Light probes for indirect illumination
- Emissive materials on windows, lanterns, screens

### 3. Post-Processing Stack
- Subtle bloom on light sources
- Chromatic aberration (very light)
- Film grain overlay (optional, togglable)
- Color grading LUT for warm/cool moods
- Depth of field for screenshot mode
- Vignette on edges

### 4. Terrain System
- Replace flat plane with sculpted terrain
- Painted texture splatmaps (grass, dirt, stone, sand)
- Edge blending between materials
- Normal maps for surface detail
- Procedural grass placement
- Water bodies with shore foam

### 5. Sky System
- Dynamic skybox with cloud layers
- Gradient sky with color transitions
- Sun/moon cycle
- Star field at night
- Aurora borealis for special regions
- Weather particles (rain, snow, fog)

### 6. Avatar Upgrade
- Replace capsule geometry with proper rigged mesh
- Facial expressions (idle blink, happy, surprised)
- Clothing system with material swaps
- Hair physics (simple jiggle bone)
- Emote animations (wave, dance, sit, meditate)
- Customizable particle trails

### 7. Building Assets
- Redesign all 6 existing assets with more detail:
  - Skyport Tower: Add antenna, blinking lights, dock platforms
  - Market Hall: Add stall awnings, hanging signs, window displays
  - Garden Tree: Add falling leaves particle, bird sounds
  - Park Bench: Add cushions, nearby flowers
  - Street Lantern: Add warm glow, moth particles
  - Dock Crate: Add rope, stamps, stacking variants
- Add 20+ new assets:
  - Lo-fi Radio (animated, plays ambient music zones)
  - Cozy Tent / Blanket Fort
  - Campfire with particle smoke
  - Fountain with water particles
  - Vinyl Record Player
  - Neon Signs (customizable text)
  - Planter Boxes with flowers
  - Hammock
  - String Lights
  - Bookshelf
  - Coffee Cart
  - Telescope
  - Bridge segments
  - Dock/pier segments
  - Archway/Gate
  - Fence segments
  - Pond/water feature
  - Statue/sculpture
  - Windmill
  - Balloon cluster

### 8. UI/HUD Redesign
- Glassmorphism panels with backdrop blur
- Smooth slide-in/out animations
- Custom icon set matching the vibe
- Mini-map with stylized terrain view
- Toast notifications with easing
- Loading screens with tips and art
- Context-sensitive cursor changes
- Radial menu for quick actions

## Browser Client Visual Upgrades

### 1. Complete Rebrand
- Update all "ThirdLife" references to "VibeLife"
- New color scheme matching the visual identity
- Animated background gradient
- Custom scrollbar styling
- Loading skeleton states

### 2. Three.js Renderer Improvements
- Add fog and environment map
- Implement shadow maps properly
- Add SSAO (screen space ambient occlusion)
- Tone mapping (ACES filmic)
- Anti-aliasing (FXAA or SMAA)

## Asset Pipeline Upgrade

### Current Pipeline
```
generate-assets.mjs (Three.js) -> public/assets/models/*.gltf
                                -> native-client/godot/assets/models/*.gltf
```

### Proposed Pipeline
```
Blender source files (.blend)
  -> Export as optimized glTF (.glb)
  -> Draco compression for geometry
  -> KTX2/Basis for textures
  -> Multiple LOD levels
  -> Auto-generate thumbnails
  -> CDN deployment
  -> Both clients load from CDN
```

## Performance Budget

| Asset Type | Target Size | Max Triangles |
|-----------|-------------|---------------|
| Avatar | < 50KB | 3,000 |
| Building (small) | < 100KB | 5,000 |
| Building (large) | < 250KB | 15,000 |
| Terrain chunk | < 200KB | 10,000 |
| Tree/vegetation | < 30KB | 2,000 |
| Props | < 20KB | 1,000 |

## Implementation Priority

1. **Week 1-2:** Color palette, lighting overhaul, post-processing
2. **Week 3-4:** Terrain system, sky system
3. **Week 5-6:** Avatar upgrade, animation system
4. **Week 7-8:** Asset redesign (existing 6)
5. **Week 9-12:** New assets (20+), UI/HUD redesign
6. **Week 13-16:** Polish, optimization, LOD system
