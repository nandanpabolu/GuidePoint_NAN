# Changelog

All notable dated releases tracked for collaborators and reviewers.

## 1.3.4 — Stakeholder handbook (2026-05)

### Added
- **`docs/GUIDEPOINT_USER_GUIDE.md`** with end-to-end usage, clone/run, QA checklist, demos, troubleshooting, deployment pointers, repo URLs, plus exporting **`docs/GUIDEPOINT_USER_GUIDE.pdf`**.

### Changed
- **`README.md`** and **`docs/README.md`** cite the handbook (**`flutter_app`** version **1.3.4+9`).

## 1.3.3 — Documentation polish (2026-05)

### Changed
- **`docs/SETUP_FLUTTER_AND_RUN.md`** and **`docs/ANDROID_EMULATOR_SETUP.md`** use clone-relative paths (`cd flutter_app`) instead of machine-local absolute paths.
- Root **`README.md`** and **`flutter_app/README.md`** wording adjusted for shipping (no syllabus-only phrasing).

## 1.3.2 — Contributors & attribution (2026-05)

### Changed
- Root **`README.md`** Contributors section lists the full UT Dallas CS EPICS roster; **`LICENSE`** reflects UT Dallas copyright only.

## 1.3.1 — Documentation trim (2026-05)

### Removed
- **`docs/handoff/`** mirrored Wiki Markdown and **`docs/SUBMISSION_CHECKLIST_ISSUE_180.md`** — redundant once the GitHub Wiki is the canonical process doc.
- Reference-only **`README.md`** stubs under **`figma/`**, **`navigation/`**, **`scripts/`** (folders retained; **`figma/.gitkeep`** keeps an empty assets directory in Git).

### Changed
- Root **`README.md`** and **`docs/README.md`** indexes updated so links match the trimmed tree.

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
