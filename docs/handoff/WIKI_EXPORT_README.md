# GitHub Wiki (UTDesign / Issue `#180`)

GitHub Wikis live in **their own repo** (`https://github.com/YOUR_ORG/YOUR_REPO.wiki.git`). Markdown in **`docs/handoff/wiki/`** is intentionally kept **in main** so graders can clone one branch and still create Wiki pages from it.

---

## What you do

1. Open **`https://github.com/nandanpabolu/GuidePoint_NAN/wiki`** (adjust org/name if forked).

2. If the Wiki tab says **Create the first page**:
   - Click **Create first page**.
   - Page name: **`Home`**.
   - Open `docs/handoff/wiki/Home.md` in your editor → **copy all** → paste into the Wiki editor → Save.

3. For **each remaining page**, click **New page** (or **Edit → New Page** depending on GitHub UI):
   - Paste the Markdown from the matching file below.
   - Use the suggested **Wiki page title** (appears as the human-readable sidebar link).

---

## Mapping (copy source → Wiki title)

| Wiki page title (sidebar) | Copy entire contents from this repo file |
|----------------------------|-------------------------------------------|
| `Home` | `docs/handoff/wiki/Home.md` |
| `Roles` | `docs/handoff/wiki/Roles.md` |
| `Workflow — End user navigation` | `docs/handoff/wiki/Workflow-End-user-navigation.md` |
| `Workflow — Facilities map rollout` | `docs/handoff/wiki/Workflow-Facilities-map-rollout.md` |
| `Workflow — Developer environment` | `docs/handoff/wiki/Workflow-Developer-environment.md` |
| `Integration — mobile scanner` | `docs/handoff/wiki/Integration-mobile-scanner.md` |
| `Integration — speech IO` | `docs/handoff/wiki/Integration-speech-io.md` |
| `Integration — HTTP maps` | `docs/handoff/wiki/Integration-http-maps.md` |
| `Integration — Camera & TFLite` | `docs/handoff/wiki/Integration-camera-tflite.md` |
| `Integration — pedometer` | `docs/handoff/wiki/Integration-pedometer.md` |

4. Optionally add a **`Sidebar`** Wiki page customizing navigation (GitHub feature) — paste a simple list of wiki links `[Home](../Home)`, etc., if your course wants it.

---

## Alternate (advanced): Wiki as git repo

```bash
git clone https://github.com/nandanpabolu/GuidePoint_NAN.wiki.git guidepoint-wiki
# copy markdown files renaming to Page-Name.md per GitWiki conventions if needed
# git push
```

Paste workflow is simpler for short semester deadlines unless you automate.

---

Done when graders can browse **Wiki** and see Roles + three workflows + five integration stubs without errors.
