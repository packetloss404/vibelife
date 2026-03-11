# System: Admin Panel

## Backend Endpoints
- `POST /api/admin/parcels/assign` — assign parcel
- `POST /api/admin/objects/delete` — delete object
- `GET /api/admin/audit-logs` — audit log
- `POST /api/admin/ban` — ban account
- `DELETE /api/admin/ban` — unban account
- `GET /api/avatar/ban/status?token=` — ban status

## GUI Components

### Admin Panel (admin_panel.gd)
- **Conditional visibility:** Only show tab if account role is "admin"

- **Player Management:**
  - Search player by name
  - Ban button: duration input (hours), reason text
  - Unban button
  - View ban status

- **Parcel Management:**
  - Select parcel from list or click in world
  - Assign owner: account name input
  - Force release button

- **Object Management:**
  - Select object from list or click in world
  - Delete with reason input
  - Bulk operations

- **Audit Log:**
  - Paginated log viewer
  - Filter by: action type, account, date range
  - Each entry: timestamp, actor, action, target, details
  - Migrate existing AdminAuditLog from build panel here
  - Export/search functionality
