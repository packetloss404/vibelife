# System: Creator Tools

## Backend Endpoints
- `POST /api/creator/assets/submit` — submit asset
- `GET /api/creator/assets/submit/:id` — submission status
- `GET /api/creator/assets/submissions?token=` — my submissions
- `GET /api/creator/assets/review` — review queue (admin)
- `POST /api/creator/assets/review` — approve/reject (admin)
- `GET /api/creator/analytics?token=` — analytics
- `POST /api/creator/analytics/view` — record view
- `POST /api/creator/analytics/sale` — record sale
- `GET /api/creator/revenue?token=` — revenue summary
- `POST /api/creator/revenue/split` — configure split (admin)
- `GET /api/creator/revenue/payouts?token=` — payout history
- `POST /api/creator/revenue/payouts` — request payout
- `POST /api/creator/plugins/:id` — register plugin
- `GET /api/creator/plugins` — list plugins
- `PATCH /api/creator/plugins/:id` — update plugin
- `DELETE /api/creator/plugins/:id` — remove plugin
- `POST /api/creator/plugins/:id/regenerate-key` — new API key
- `POST /api/creator/webhooks` — register webhook
- `GET /api/creator/webhooks?token=` — list webhooks
- `PATCH /api/creator/webhooks/:id` — update webhook
- `DELETE /api/creator/webhooks/:id` — remove webhook

## GUI Components

### Creator Panel (creator_panel.gd)
- **Conditional visibility:** Only show tab if account has creator flag or assets

- **Submit Asset:**
  - Name, description, category inputs
  - File reference (asset path)
  - Submit button
  - Submission status tracker (pending/approved/rejected)

- **My Assets Tab:**
  - Submitted assets list with status badges
  - View count and sale count per asset

- **Analytics Tab:**
  - Total views, total sales, total revenue
  - Per-asset breakdown list

- **Revenue Tab:**
  - Total earned, pending payout
  - Payout history list
  - "Request Payout" button

- **Plugins Tab (advanced):**
  - Registered plugins list
  - API key display (masked)
  - Regenerate key button
  - Webhook management
