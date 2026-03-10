# Parcel Tier Upgrades

## Overview

Parcel tiers define different levels of land ownership with varying capabilities, build limits, and features. Higher tiers provide more resources and exclusive features.

## Current Tiers

The system already supports basic tier classification:

| Tier | Build Area | Features |
|------|-------------|----------|
| `public` | Shared | Open building, no ownership |
| `homestead` | 20x20 | Basic parcel ownership |
| `premium` | 30x30 | Extended features |

## Proposed Tier System

### Extended Tier Definitions

```typescript
enum ParcelTier {
  PUBLIC = "public",      // Free, shared space
  HOMESTEAD = "homestead", // Basic ownership (L$50/week)
  ESTATE = "estate",       // Large plot (L$200/week)
  COMMERCIAL = "commercial" // Business use (L$500/week)
}

interface ParcelTierConfig {
  tier: ParcelTier;
  maxBuildArea: number;      // square meters
  maxObjects: number;
  maxScripts: number;
  maxScriptsPerObject: number;
  allowTerraforming: boolean;
  allowVoiceChat: boolean;
  allowTrafficAnalytics: boolean;
  tierMaintenanceFee: number;  // L$ per week
}
```

### Tier Features Matrix

| Feature | Public | Homestead | Estate | Commercial |
|---------|--------|-----------|--------|------------|
| Max Objects | 50 | 150 | 500 | 2000 |
| Max Scripts | 0 | 10 | 50 | 200 |
| Traffic Stats | ❌ | ❌ | ✅ | ✅ |
| Custom Audio | ❌ | ❌ | ✅ | ✅ |
| Teleport Links | ❌ | 3 | 10 | Unlimited |
| Group Members | 0 | 3 | 10 | 25 |

## Database Schema

```sql
-- Add to existing parcels table
ALTER TABLE parcels ADD COLUMN tier VARCHAR(20) DEFAULT 'homestead';
ALTER TABLE parcels ADD COLUMN tier_expires_at TIMESTAMPTZ;
ALTER TABLE parcels ADD COLUMN tier_auto_renew BOOLEAN DEFAULT TRUE;

-- New table for tier upgrades
CREATE TABLE parcel_tier_upgrades (
  id UUID PRIMARY KEY,
  parcel_id TEXT NOT NULL REFERENCES parcels(id),
  from_tier VARCHAR(20) NOT NULL,
  to_tier VARCHAR(20) NOT NULL,
  purchased_by UUID REFERENCES accounts(id),
  price INTEGER NOT NULL,
  duration_days INTEGER NOT NULL,
  created_at TIMESTAMPTZ NOT NULL
);
```

## API Endpoints

### Upgrade Tier

```typescript
POST /api/parcels/:parcelId/upgrade
{
  token: string;
  tier: "homestead" | "estate" | "commercial";
  durationDays: number; // 1-52 weeks
}

// Returns: { success: boolean; newTier: ParcelTierConfig; expiresAt: string }
```

### Get Tier Info

```typescript
GET /api/parcels/:parcelId/tier
// Returns: { tier: ParcelTierConfig; expiresAt: string | null }
```

### List Available Tiers

```typescript
GET /api/parcels/tiers
// Returns: { tiers: ParcelTierConfig[] }
```

## Implementation in store.ts

```typescript
export async function upgradeParcelTier(
  token: string,
  parcelId: string,
  newTier: ParcelTier,
  durationDays: number
): Promise<Parcel | undefined> {
  // 1. Verify ownership
  // 2. Check currency balance
  // 3. Deduct L$
  // 4. Update parcel tier
  // 5. Return updated parcel
}
```

## Tier Upgrade UI (Godot)

- Parcel info panel shows current tier
- "Upgrade" button opens tier selection dialog
- Features comparison table
- Duration selector (weekly/monthly/yearly)
- Payment confirmation

## Auto-Renewal

- System deducts weekly fee automatically
- Grace period of 3 days before tier downgrade
- Email/notification reminder before expiry

## Migration Path

1. Add tier field to parcels (default: homestead)
2. Create tier config constants
3. Implement upgrade endpoint
4. Add balance deduction logic
5. Build UI for tier management
