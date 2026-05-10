# Changelog

All notable dated releases tracked for reviewers / next cohort handoff.

## 1.3.0 — Fall 2025 semester handoff (2026-05)

### Added
- Comprehensive root **README** (conceptual overview, functional requirements per screen, stack, syllabus mapping).
- **`.env.example`** placeholder for optional future HTTPS map API keys.
- **`figma/README.md`** with instructions when no bundled Figma file exists.
- **`docs/MAP_DATA_SCHEMA.md`** — canonical description of navigation JSON (“data schema” without SQL DB).
- **`docs/handoff/`** Markdown export pack for copying into GitHub Wiki (Issue `#180`).
- **`navigation/README.md`** explaining intentional empty routing placeholder folder.

### Changed
- **Android Gradle** portability: deprecated experimental ARCore/flutter_vision fusion removed (upstream plugin lacked AGP namespace; not referenced by UI flows).
- **MaterialApp** now honors saved Terms acceptance via **`initialRoute`**.

### Removed
- Orphan **`navigation_graph.png`** from repository root (`data/maps/` keeps canonical plot).

### Operational notes for partners
Production deploy = mobile store packaging with generated signing configs (see **`flutter_app/android/key.properties.example`**).
