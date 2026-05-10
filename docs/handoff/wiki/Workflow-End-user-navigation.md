# Workflow — End user navigation

**Actor:** Blind/low-vision traveler (or QA tester emulating traveler)

**Screens / modules involved**

1. `TermsScreen` — first launch acknowledgement  
2. `QRScannerScreen` — scans QR (`mobile_scanner`), stores raw JSON pref via `SharedPreferences`  
3. Voice capture — listens for destination substring match against node **`name`**  
4. `NavigationScreen` — TTS cues, periodic camera grabs, **`StepCountService`**, **`YoloDetector`**, optional **`SceneClassifier`**

**Happy path**

1. Accept Terms.  
2. Scan organization-provided QR.  
3. When prompted, clearly say `"Seminar Hall"` (phrase must appear in canonical node **`name`**).  
4. Follow automated guidance; allow camera + mic + motion prompts.

**Failures & mitigations**

- Network timeout when QR was URL-hosted → regenerate offline JSON QR fallback.  
- Mic rejected → FAB mic retry (`QRScannerScreen`).  
- Emulator missing step sensor → waypoint confirmation still reachable via proximity models or debug-only previews.
