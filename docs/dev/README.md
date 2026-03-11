# Development Documentation

This directory now serves as the live technical planning and implementation-spec index for `VibeLife`.

It contains a mix of:
- active implementation notes for features that are still evolving
- design docs for planned work that is not fully shipped yet
- references that should be verified against code before being treated as current behavior

For the current audit baseline, see `docs/audit/index.html`.

## Verified Planning Docs

These documents still match the current repo direction closely enough to keep as active planning references:

| Doc | Area | Status |
|-----|------|--------|
| [voice-chat.md](voice-chat.md) | Spatial voice | Planning / partial implementation |
| [parcel-tier-upgrades.md](parcel-tier-upgrades.md) | Parcel monetization and analytics | Planning |
| [region-workers.md](region-workers.md) | Region scaling | Planning |
| [mobile-client.md](mobile-client.md) | Mobile companion direction | Needs re-baseline |
| [traffic-analytics.md](traffic-analytics.md) | Parcel analytics | Planning |

## Known Gaps

- Older links in this directory previously pointed to missing files and to the old `ThirdLife` name.
- Several live systems already exist in code without dedicated source-of-truth docs yet, including federation, VR, NPCs, media, pets, voxel/combat systems, and the events API.
- `mobile-client.md` should be treated as exploratory design, not an exact reflection of the current transport stack.

## When Adding Docs

1. Prefer one feature per file.
2. Mark the document as `planning`, `partial`, or `verified` near the top.
3. Reference real code entry points such as `src/routes/*.ts`, `src/world/*.ts`, or `native-client/godot/scripts/*.gd`.
4. Update this index and the audit report when a doc becomes stale.
