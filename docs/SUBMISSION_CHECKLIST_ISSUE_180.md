# UTDesign syllabus alignment (historical Issue **#180**-style checklist)

Checklist mirrored for graders / next team (“someone must run repo without mysteries”).

Project Structure / Files
- [x] Frontend + supplementary ML/tools on **`main`** (Flutter under **`flutter_app/`**)
- [x] Database files — **Not applicable** (navigation graph is JSON documents; schema → **`docs/MAP_DATA_SCHEMA.md`**)
- [x] `docker-compose.yml` — **Not applicable** — no Postgres/MySQL footprint; rationale in root **`README.md` → Database & Docker**
- [x] `.env.example` describing non-sensitive placeholders (see repo root). Real secrets forbidden in Git (`key.properties`, keystores `.gitignored`)
- [x] `figma/` top-level placeholder (`README` explains screenshots / future link-outs)
- [x] `scripts/` gathers automation (`run_macos.sh`, `open_emulator.sh`; see `scripts/README.md`)
- [x] Additional docs consolidated under **`docs/`** (+ wiki export pack **`docs/handoff/wiki/`**)

Documentation (root `README.md`)
- [x] Conceptual overview + user roles/partnerships
- [x] Functional requirements broken down **per screen/route**
- [x] Third-party integrations enumerated with purpose statements
- [x] Stack table (Flutter, Python ML, models)
- [x] Deployment / migration realism (mobile bundle + JSON maps; SQL migration N/A)
- [x] Dev environment instructions + quick commands

Wiki (hosted on GitHub, not mirrored as normal tracked files beyond export pack)
- [ ] **Contributor action**: paste **`docs/handoff/wiki/*.md`** per **`docs/handoff/WIKI_EXPORT_README.md`**
