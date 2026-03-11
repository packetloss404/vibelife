# System: Storefronts & Commissions

## Backend Endpoints
- `POST /api/storefronts` — create storefront
- `GET /api/storefronts/:accountId` — get storefront
- `PATCH /api/storefronts` — update storefront
- `GET /api/storefronts` — list all storefronts
- `POST /api/storefronts/:accountId/rate` — rate storefront
- `GET /api/marketplace/trending` — trending items
- `POST /api/commissions` — create commission
- `POST /api/commissions/:id/accept` — accept commission
- `PATCH /api/commissions/:id` — update status
- `POST /api/commissions/:id/complete` — complete commission
- `GET /api/commissions?token=` — list commissions

## GUI Components

### Storefront Panel (storefront_panel.gd)
- **Browse Storefronts:**
  - List of storefronts with name, owner, rating
  - Click to view: items, description, rating
  - Rate button (1-5 stars)

- **Trending Items:**
  - Popular items section
  - Price, seller, buy button

- **My Storefront:**
  - Create storefront (name, description)
  - Edit storefront details
  - Add/remove items
  - View ratings and feedback

- **Commissions Tab:**
  - Create commission request: description, budget, deadline
  - Incoming commissions (accept/decline)
  - Active commissions with status tracker
  - Mark complete button
  - Commission history
