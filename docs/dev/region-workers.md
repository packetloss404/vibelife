# Region Simulation Workers

## Overview

Region simulation workers enable horizontal scaling of world simulation by distributing region load across multiple processes or machines. This supports larger populations and more complex physics/logic.

## Current Architecture (Single Process)

```
                    ┌─────────────────────┐
                    │     Fastify API     │
                    │   (Main Server)     │
                    └──────────┬──────────┘
                               │
                    ┌──────────▼──────────┐
                    │    World Store      │
                    │  (In-Memory/PG)    │
                    └──────────┬──────────┘
                               │
                    ┌──────────▼──────────┐
                    │    WebSocket        │
                    │    Broadcast        │
                    └─────────────────────┘
```

## Proposed Architecture (Worker Pool)

```
┌─────────────────────────────────────────────────────────────┐
│                        Load Balancer                        │
└───────────────────────────┬─────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
        ▼                   ▼                   ▼
┌───────────────┐   ┌───────────────┐   ┌───────────────┐
│   Worker 1    │   │   Worker 2    │   │   Worker N    │
│ Region: Aurora│   │ Region: Glass │   │ Region: ...   │
│   + Aurora    │   │   + Aurora    │   │               │
│  (backup)     │   │  (backup)     │   │               │
└───────┬───────┘   └───────┬───────┘   └───────┬───────┘
        │                   │                   │
        └───────────────────┼───────────────────┘
                            │
                    ┌───────▼───────┐
                    │   Redis Pub/Sub │
                    │   (Message Bus) │
                    └───────┬───────┘
                            │
                    ┌───────▼───────┐
                    │    Database    │
                    │   (Postgres)   │
                    └────────────────┘
```

## Worker Design

### Worker Responsibilities

1. **Simulation Loop**: Process avatar movement, physics, scripts
2. **State Management**: Maintain in-memory region state
3. **Event Broadcasting**: Push updates to connected clients
4. **Persistence Sync**: Periodic save to database
5. **Cross-Region Events**: Handle teleportation

### Worker Types

| Type | Responsibility |
|------|----------------|
| `region-worker` | Single region simulation |
| `gateway-worker` | Auth, API routing |
| `analytics-worker` | Traffic aggregation |

## Implementation

### 1. Message Bus (Redis Pub/Sub)

```typescript
// Channel patterns
"region:{regionId}:events"    // Region events to broadcast
"region:{regionId}:state"     // State sync between workers
"region:{regionId}:teleport"  // Cross-region teleports
"worker:heartbeat"             // Worker health checks
```

### 2. Worker Process

```typescript
// src/workers/region-worker.ts
class RegionWorker {
  private regionId: string;
  private state: RegionState;
  private clients: Map<string, WebSocket>;
  
  async start() {
    // Subscribe to region channels
    await this.subscribe(`${this.regionId}:events`);
    
    // Start simulation loop (30Hz)
    setInterval(() => this.tick(), 33);
  }
  
  private tick() {
    // Process pending commands
    // Update physics
    // Run scripts
    // Broadcast state
  }
}
```

### 3. Gateway Routing

```typescript
// Route requests to appropriate worker
app.get("/ws/regions/:regionId", async (socket, req) => {
  const worker = await workerPool.getWorker(req.params.regionId);
  await worker.addClient(socket);
});
```

### 4. Interest Management

Only send relevant updates to clients:

```typescript
interface InterestSet {
  avatars: Set<string>;      // Avatar IDs in view
  objects: Set<string>;      // Object IDs in view
  parcels: Set<string>;      // Parcel IDs in view
}

function computeInterest(avatar, region) {
  // Avatar sees: nearby avatars, objects in range, current parcel
  const range = 30; // meters
  return {
    avatars: findAvatarsInRange(avatar, range),
    objects: findObjectsInRange(avatar, range),
    parcels: findParcelsInRange(avatar, range)
  };
}
```

### 5. State Synchronization

```typescript
// Periodic state snapshot to database
async function persistState() {
  await db.transaction(async () => {
    await saveAvatarPositions(state.avatars);
    await saveObjectPositions(state.objects);
  });
}

// Every 30 seconds
setInterval(persistState, 30000);
```

## Worker Pool Management

### Worker Registry

```typescript
// src/workers/registry.ts
interface WorkerInfo {
  id: string;
  type: string;
  regions: string[];
  capacity: number;
  load: number;
  status: "active" | "draining" | "dead";
  lastHeartbeat: number;
}

class WorkerRegistry {
  private workers = new Map<string, WorkerInfo>();
  
  async register(worker: WorkerInfo) {
    this.workers.set(worker.id, worker);
  }
  
  async getWorkerForRegion(regionId: string): Promise<WorkerInfo> {
    // Find worker with lowest load that has the region
    // Or assign to new worker
  }
}
```

### Health Checks

```typescript
// Worker heartbeat every 10 seconds
setInterval(async () => {
  await redis.publish("worker:heartbeat", {
    workerId,
    regions,
    load,
    timestamp: Date.now()
  });
}, 10000);

// Remove workers that haven't heartbeated in 30 seconds
```

## Scaling Strategy

### Auto-Scaling Rules

```yaml
# worker-scaling-config.yaml
scaling:
  - metric: region_population
    condition: > 20 avatars
    action: scale_up
    max_workers: 4
    
  - metric: region_population
    condition: < 5 avatars
    action: scale_down
    min_workers: 1
    
  - metric: script_execution_time
    condition: > 50ms average
    action: scale_up
```

### Region Distribution

```
Initial Distribution:
- 1 worker = 1 region
- Backup worker for failover

Scaling:
- Split large regions at 50 concurrent users
- Merge small regions at < 5 users
```

## Database Schema

```sql
-- Worker registry (could use Redis instead)
CREATE TABLE workers (
  id VARCHAR(50) PRIMARY KEY,
  type VARCHAR(20) NOT NULL,
  regions TEXT[] NOT NULL,
  capacity INTEGER NOT NULL,
  status VARCHAR(20) DEFAULT 'active',
  last_heartbeat TIMESTAMPTZ NOT NULL
);

-- Region-to-worker mapping cache
CREATE TABLE region_assignments (
  region_id TEXT PRIMARY KEY,
  worker_id VARCHAR(50) REFERENCES workers(id),
  updated_at TIMESTAMPTZ NOT NULL
);
```

## Docker Deployment

```yaml
# docker-compose.yml
services:
  gateway:
    image: thirdlife/gateway
    ports:
      - "3000:3000"
      
  region-worker:
    image: thirdlife/region-worker
    deploy:
      replicas: 2-10
    environment:
      - WORKER_ID=${HOSTNAME}
      - REDIS_URL=redis://redis:6379
      - DATABASE_URL=postgres://...
      
  redis:
    image: redis:7-alpine
    
  postgres:
    image: postgres:15
```

## Failure Handling

| Scenario | Recovery |
|----------|----------|
| Worker crash | Clients reconnect to new worker |
| Database failure | In-memory fallback, queue writes |
| Redis disconnect | Local Pub/Sub fallback |
| Network partition | Clients enter offline mode |

## Migration Path

1. Add Redis dependency
2. Implement message bus interface
3. Create worker process entry point
4. Add worker registry
5. Update gateway to route to workers
6. Implement interest management
7. Add health monitoring

## Performance Targets

| Metric | Target |
|--------|--------|
| Avatar update latency | < 50ms |
| Script execution | < 16ms (60fps) |
| Worker failover | < 5 seconds |
| Max avatars per region | 100 |
| Max regions per worker | 4 |
