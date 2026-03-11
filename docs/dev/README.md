# Development Documentation

This directory contains technical documentation for features not yet implemented in the ThirdLife backend.

## Implemented Features

The following features have been implemented and are ready to use:

- [Inter-region Teleportation](../README.md)
- [Avatar Animations (Godot)](../native-client/godot)
- [In-world Scripting](./in-world-scripting.md)
- [Asset Library System](./asset-library.md)
- [Friend/Block Lists](./friends.md)
- [Group/Guild System](./groups.md)
- [Instant Messaging](./messaging.md)
- [Linden-like Currency](./currency.md)
- [Object Permissions](./object-permissions.md)
- [Region Events/Notices](./region-notices.md)
- [Avatar Profiles](./profiles.md)
- [Teleport Landing Points](./teleport-points.md)
- [Multi-region Persistence](./persistence.md)
- [Texture/Skin Upload](./texture-upload.md)
- [Moderation Tools](./moderation.md)

## Pending Features

Documentation for features still in the planning phase:

| Feature | Description | Priority |
|---------|-------------|----------|
| [Voice Chat (VoIP)](voice-chat.md) | Real-time spatial audio | Medium |
| [Parcel Tier Upgrades](parcel-tier-upgrades.md) | Premium land tiers with expanded features | Medium |
| [Parcel Traffic Analytics](parcel-tier-upgrades.md) | Visitor tracking and analytics | Low |
| [Region Simulation Workers](region-workers.md) | Horizontal scaling for world simulation | High |
| [Mobile Client](mobile-client.md) | React Native iOS/Android app | Low |

## Contributing

To add documentation for a new feature:

1. Create a markdown file in this directory
2. Follow the existing document structure
3. Include API contracts, database schemas, and implementation details
4. Update this index to reference the new document
