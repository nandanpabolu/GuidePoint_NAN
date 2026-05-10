# GuidePoint Demo — First-Time Setup (No Flutter Experience)

Follow these steps in order. You only need to do the **Install Flutter** section once.

---

## Do this first (copy-paste in Terminal)

If Flutter is **not** installed yet, run this in **Terminal** (one line at a time). You may be asked for your Mac password for `sudo`:

```bash
# Fix Homebrew permissions if you get "Cellar is not writable"
sudo chown -R $(whoami) /opt/homebrew/Cellar /opt/homebrew/var

# Install Flutter (takes a few minutes)
brew install --cask flutter

# From your cloned repository root (where README.md is), enter the Flutter app:
cd flutter_app
flutter pub get
flutter run
```

When the app is running on your phone/emulator, open **`tools/scan_atl_qr.html`** (repo root) in your browser and scan the QR with the app. Then say **“Seminar Hall”** when prompted.

---

## Step 1: Install Flutter (one-time)

### On Mac (you're on macOS)

1. **Install Homebrew** (if you don’t have it).  
   Open **Terminal** (search “Terminal” in Spotlight). Paste and press Enter:
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```
   Follow the prompts. When it says “Next steps,” run the two commands it shows (they add `brew` to your path).

2. **Install Flutter:**
   ```bash
   brew install --cask flutter
   ```

3. **Check that it worked:**
   ```bash
   flutter doctor
   ```
   You want at least **Flutter** and **Android toolchain** (or **Xcode** for iOS) OK. If Android is “not installed,” run:
   ```bash
   flutter doctor --android-licenses
   ```
   Type `y` and Enter for each license.

4. **Plug in your Android phone** (or start an Android emulator).  
   - Enable **Developer options** and **USB debugging** on the phone.  
   - Or install [Android Studio](https://developer.android.com/studio), then: **Tools → Device Manager** and create/start a virtual device.

---

## Step 2: Run the GuidePoint app

1. Open **Terminal**.

2. From your cloned repository root, open the Flutter app directory:
   ```bash
   cd flutter_app
   ```

3. Get dependencies (first time and after any dependency change):
   ```bash
   flutter pub get
   ```

4. Run the app:
   ```bash
   flutter run
   ```
   - If you have **one** device/emulator connected, the app will install and open there.
   - If you have **more than one**, Flutter will list them; type the number of the device you want and press Enter.

Wait until you see “Flutter run key commands” and the app is open on the device. Leave this Terminal window open while you test.

---

## Step 3: Get the test QR code (for the demo)

You need a QR code that contains the building map. Easiest option:

1. On your **Mac**, open **`tools/scan_atl_qr.html`** under the repository root in your browser (double-click or drag into Chrome/Safari).
2. A **big QR code** will appear on the page.
3. Unlock your **phone** (with the GuidePoint app running), open the **QR scanner** screen in the app, and **point the phone at the QR code on your computer screen**.
4. The app should read the map and say something like “Say your destination.”

---

## Step 4: Run the demo flow

1. **Accept terms** (first time only).
2. **Scan the QR** (from the HTML page on your computer, or from a printed QR).
3. When you see **“Say your destination”**, say clearly: **“Seminar Hall”** or **“Idea Labs”**.
4. The app will compute the path and open the **Navigation** screen with voice instructions.
5. (Optional) Tap the **list icon** to see and replay the full instruction list.

---

## If something goes wrong

| Problem | What to do |
|--------|------------|
| `flutter: command not found` | Close Terminal, open a new one and run `flutter doctor` again. If it still fails, add Flutter to your PATH (see [flutter.dev/docs/get-started/install/macos](https://docs.flutter.dev/get-started/install/macos)). |
| No devices found | Plug in an Android phone with USB debugging on, or start an Android emulator from Android Studio (Device Manager). Then run `flutter run` again. |
| App crashes on scan | Make sure the QR payload matches `tools/scan_atl_qr.html` (or the same schema as `data/maps/ATL_JSON.json`). |
| “Say your destination” never appears | Grant **microphone** permission when the app asks. |

---

**Quick recap:** Install Flutter with Homebrew → `cd flutter_app` → `flutter pub get` → `flutter run` → open `tools/scan_atl_qr.html` in browser → scan with phone → say “Seminar Hall”.
