# Parcel Traffic Analytics

## Overview

Traffic analytics provide parcel owners with insights into visitor patterns, popular times, and engagement metrics. This helps land owners understand their space usage and make informed decisions.

## Data Collection

### Events to Track

| Event | Description |
|-------|-------------|
| `parcel.enter` | Avatar enters parcel bounds |
| `parcel.exit` | Avatar leaves parcel bounds |
| `parcel.presence` | Periodic presence ping (every 30s) |
| `object.interact` | Avatar clicks/interacts with object |
| `object.script_run` | Script executed on object |

### Collection Frequency

- Entry/Exit: On event
- Presence: Every 30 seconds per avatar
- Interactions: On occurrence

## Database Schema

```sql
-- Traffic events table
CREATE TABLE parcel_traffic_events (
  id UUID PRIMARY KEY,
  parcel_id TEXT NOT NULL REFERENCES parcels(id),
  account_id UUID REFERENCES accounts(id),
  event_type VARCHAR(30) NOT NULL,
  duration_seconds INTEGER, -- for exit events
  created_at TIMESTAMPTZ NOT NULL
);

-- Indexes for analytics queries
CREATE INDEX idx_traffic_parcel_time ON parcel_traffic_events(parcel_id, created_at);
CREATE INDEX idx_traffic_account ON parcel_traffic_events(account_id, created_at);

-- Daily aggregate table (pre-computed)
CREATE TABLE parcel_daily_stats (
  parcel_id TEXT NOT NULL REFERENCES parcels(id),
  date DATE NOT NULL,
  unique_visitors INTEGER DEFAULT 0,
  total_visits INTEGER DEFAULT 0,
  total_time_seconds INTEGER DEFAULT 0,
  peak_concurrent INTEGER DEFAULT 0,
  interactions INTEGER DEFAULT 0,
  PRIMARY KEY (parcel_id, date)
);
```

## Analytics API

### Get Daily Stats

```typescript
GET /api/parcels/:parcelId/analytics/daily
GET /api/parcels/:parcelId/analytics/daily?start=2026-01-01&end=2026-01-31

// Response:
{
  stats: {
    parcelId: string;
    date: string;
    uniqueVisitors: number;
    totalVisits: number;
    avgDuration: number;
    peakConcurrent: number;
  }[]
}
```

### Get Hourly Distribution

```typescript
GET /api/parcels/:parcelId/analytics/hourly?date=2026-01-15

// Response:
{
  hourly: {
    hour: number;      // 0-23
    visitors: number;
    avgDuration: number;
  }[]
}
```

### Get Weekly Trends

```typescript
GET /api/parcels/:parcelId/analytics/trends?weeks=4

// Response:
{
  trends: {
    dayOfWeek: number; // 0-6
    avgVisitors: number;
    avgDuration: number;
  }[]
}
```

### Get Popular Objects

```typescript
GET /api/parcels/:parcelId/analytics/objects

// Response:
{
  objects: {
    objectId: string;
    interactions: number;
    uniqueInteractors: number;
  }[]
}
```

## Implementation

### 1. Event Collection

Add to `src/world/store.ts`:

```typescript
export async function trackParcelEvent(
  parcelId: string,
  accountId: string | null,
  eventType: string,
  metadata?: Record<string, unknown>
): Promise<void> {
  await persistence.appendTrafficEvent({
    id: randomUUID(),
    parcelId,
    accountId,
    eventType,
    metadata,
    createdAt: new Date().toISOString()
  });
}
```

### 2. Presence Tracking

Update avatar position tracking to detect parcel entry/exit:

```typescript
// In avatar movement handler
function checkParcelTransition(avatar, oldParcel, newParcel) {
  if (oldParcel !== newParcel) {
    if (oldParcel) {
      trackParcelEvent(oldParcel.id, avatar.accountId, 'parcel.exit');
      trackParcelEvent(newParcel.id, avatar.accountId, 'parcel.enter');
    }
  }
}
```

### 3. Daily Aggregation Job

```typescript
// Run daily at midnight
async function aggregateDailyStats() {
  const yesterday = new Date();
  yesterday.setDate(yesterday.getDate() - 1);
  
  // Query events and compute aggregates
  // Store in parcel_daily_stats
}
```

## Privacy Considerations

- Opt-in for detailed tracking (tier-based)
- Anonymize data in public dashboards
- GDPR compliance: allow data export/deletion
- Don't track guest visitors by default

## UI Integration (Godot)

### Owner Dashboard

- **Overview Card**: Today's visitors, trend indicator
- **Hourly Chart**: Bar chart of hourly traffic
- **Weekly Heatmap**: 7-day × 24-hour grid
- **Object Stats**: Click to see object interaction breakdown

### Parcel Overlay

- Green tint: High traffic
- Yellow tint: Medium traffic  
- Red tint: Low traffic
- Owners can toggle traffic visualization

## Tier Access

| Feature | Estate | Commercial |
|---------|--------|------------|
| Daily Stats | ✅ | ✅ |
| Hourly Distribution | ✅ | ✅ |
| Weekly Trends | ❌ | ✅ |
| Object Interactions | ❌ | ✅ |
| Export Data | ❌ | ✅ |
| Real-time Viewers | ❌ | ✅ |

## Future Enhancements

1. Geographic distribution (where visitors came from)
2. Return visitor tracking
3. Object heatmaps
4. Time-series forecasting
5. Integration with Linden-style land metrics
