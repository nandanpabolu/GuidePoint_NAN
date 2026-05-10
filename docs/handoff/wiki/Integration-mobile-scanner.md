# Integration — Mobile scanner (`mobile_scanner`)

**What:** Reads QR payloads (inline JSON strings or redirect URLs pointing at JSON).

**Used in:** `flutter_app/lib/screens/qr_scanner_screen.dart`

**Permissions:** Camera (Android Manifest + runtime request).

**Privacy:** Frames stay on-device unless user-configured outbound URL fetch retrieves map JSON (`http` GET).
