# Roles & responsibilities

## End traveler (primary persona)

Someone navigating inside a mapped building with impaired sight or situational blindness.

**Can:**
- Launch app, grant camera/mic/motion prompts.
- Scan a venue QR embedding JSON or pointing to public map JSON HTTP URL.
- Speak a destination that fuzzy-matches a node name.
- Follow live navigation cues (speech + preview camera + stepping).

**Cannot:**
- Automatically modify graph topology without authoring new JSON externally.

---

## Venue / accessibility champion (“map owner”)

Campus accessibility staff or partner org producing printable QR payloads.

**Can:**
- Author `building/floors/nodes/edges` JSON referencing real paths.
- Distribute laminated QR flyers or kiosk displays.
- Optional: host JSON on HTTPS and encode URL-only QR payloads.

---

## Developer / researcher (next cohort)

Adds models, adjusts thresholds, validates devices.

**Can:**
- Run `flutter test`, replace TFLite drop-ins under `flutter_app/assets/models/`.
- Regenerate Ultralytics checkpoints under **`models/runs/train/guidepoint`**.
- Maintain Python env via **`requirements.txt`**.

---

## Third-party integration pages (recommended child wiki pages)

- `Integration-mobile-scanner.md` — QR ingestion & camera UX
- `Integration-speech-io.md` — Speech-to-text + TTS
- `Integration-http-maps.md` — Optional networked map payloads
- `Integration-camera-tflite.md` — On-device inference & confirmation loop
- `Integration-pedometer.md` — Step-based distance heuristic
