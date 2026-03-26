# Sprint 10: Creator, Storefronts, Admin & Polish (Week 10)

## Goal
Final systems, WS completeness audit, polish pass, and full regression testing.

## Systems
- [Creator Tools](systems/creator-tools.md)
- [Storefronts](systems/storefronts.md)
- [Admin](systems/admin.md)

## Tasks

### 10.1 Creator Dashboard Panel
**Owner:** Dev 1 + Dev 2
**Files:** New `native-client/godot/scripts/ui/panels/creator_panel.gd`

- Register "Creator" tab (visible only to creator-flagged accounts)
- Asset submission form: name, description, file reference
- Submission status tracker (pending, approved, rejected)
- My submissions list
- Analytics: views, sales, revenue chart (text-based)
- Revenue and payouts display
- Plugin registry management

### 10.2 Storefront Panel
**Owner:** Dev 3 + Dev 4
**Files:** New `native-client/godot/scripts/ui/panels/storefront_panel.gd`

- Register "Shop" tab in panel manager
- Browse storefronts list
- Storefront detail: name, rating, items
- Rate storefront (1-5 stars)
- Trending items section
- Commission system: create, accept, track, complete
- My Storefront sub-tab: create/edit own storefront

### 10.3 Admin Panel
**Owner:** Dev 5
**Files:** New `native-client/godot/scripts/ui/panels/admin_panel.gd`

- Register "Admin" tab (visible only to admin accounts)
- Ban/unban player: name input, reason, duration
- Ban status lookup
- Parcel assignment: select parcel, assign to account
- Object deletion: select object, delete with reason
- Full audit log browser (paginated, filterable)
- Migrate existing AdminAuditLog from build panel

### 10.4 WS Completeness Audit
**Owner:** Dev 6
**Files:** `session_coordinator.gd`

- Verify ALL 43 event types have handlers
- Add any remaining missing handlers
- Test each event type produces visible feedback
- `voxel:chunk_data` — route to voxel_mgr for streaming
- `chat:history` — route to chat panel
- Ensure no events are silently dropped

### 10.5 Polish & Regression
**Owner:** All 6 Devs
**Files:** All modified files

- Test every panel at multiple resolutions
- Keyboard navigation between tabs
- Tab notification badges update correctly
- Loading states for all async operations
- Error states for failed requests
- Consistent color theme across all panels
- Performance check: no FPS drops from UI

### 10.6 Context Menu System
**Owner:** Dev 2
**Files:** New `native-client/godot/scripts/ui/context_menu.gd`

- Right-click on player avatar: Profile, Whisper, Trade, Add Friend, Block
- Right-click on object: Interact, Info, Report
- Right-click on parcel: Claim, Visit Owner, Rate Home
- Consistent context menu pattern across all interactions

## Definition of Done
- [ ] Creator dashboard functional for asset submission and analytics
- [ ] Storefront browsing, rating, and commission system work
- [ ] Admin panel can ban, manage parcels, view audit logs
- [ ] ALL 43/43 WS events handled
- [ ] Context menus on avatars, objects, parcels
- [ ] All panels tested at 720p, 1080p, 1440p
- [ ] Zero regressions in existing features
- [ ] **100% GUI coverage across all systems**
