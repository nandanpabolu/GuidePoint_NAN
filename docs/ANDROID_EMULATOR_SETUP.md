# Run GuidePoint on an Android Emulator

You don’t need a physical Android phone. Use the emulator that comes with Android Studio.

---

## Step 1: Android Studio is installed

Android Studio is already installed (via Homebrew). You’ll use it only to create and run the emulator.

---

## Step 2: First-time setup (only once)

1. **Open Android Studio**  
   - From **Applications**, or  
   - From Terminal: `open -a "Android Studio"`

2. **Setup Wizard**  
   - If it’s the first launch, the **Setup Wizard** will run.  
   - Choose **Standard** install and click **Next** until it finishes.  
   - It will download the Android SDK (this can take a few minutes).  
   - When you see “Welcome to Android Studio,” you’re done with the wizard.

3. **Accept Android SDK license** (if asked)  
   - Click **Accept** for the license dialog.

---

## Step 3: Create an Android Virtual Device (emulator)

1. On the **Welcome** screen, click **More Actions** → **Virtual Device Manager**  
   (If you’re in a project instead, use the top menu: **Tools** → **Device Manager**.)

2. Click **Create Device** (or the **+** button).

3. **Select hardware**  
   - Category: **Phone**.  
   - Pick a device (e.g. **Pixel 6**).  
   - Click **Next**.

4. **System image**  
   - Pick a **Release** (e.g. **UpsideDownCake** API 34 or **Tiramisu** API 33).  
   - If it says **Download** next to the release, click **Download**, wait for it to finish, then click **Next**.  
   - Click **Next** again, then **Finish**.

5. You should now see your virtual device in the list (e.g. “Pixel 6 API 34”).

---

## Step 4: Start the emulator

**From the command line (no Android Studio window needed):**

```bash
./scripts/open_emulator.sh
```

Or, to launch the default GuidePoint emulator by name:

```bash
flutter emulators --launch GuidePoint_Phone
```

Wait 30–60 seconds for the emulator to boot, then run the app (Step 6).

**From Android Studio:**  
1. In **Device Manager**, find the device you created.  
2. Click the **Play** (▶) button next to it.  
3. Wait for the emulator window to open and for Android to finish booting (you’ll see the home screen).

Leave the emulator running.

---

## Step 5: Tell Flutter where the SDK is (if needed)

If Flutter can’t find the Android SDK, run this once in Terminal (then close and reopen Terminal):

```bash
# Use the default SDK path from Android Studio
flutter config --android-sdk "$HOME/Library/Android/sdk"
```

Check that Flutter sees Android:

```bash
flutter doctor
```

You should see a check (✓) for **Android toolchain**.

---

## Step 6: Run the app on the emulator

1. With the **emulator still running**, open Terminal.  
2. Run:

   ```bash
   cd /Users/nandanpabolu/Desktop/Full_Time/Projects/Project_Experiment/GuidePoint_NAN/flutter_app
   flutter pub get
   flutter run
   ```

3. When Flutter asks **which device**, choose the **Android** one (e.g. “sdk gphone64 arm64” or “emulator-5554” or “Pixel 6 API 34”).  
   - If only one device is listed (the emulator), Flutter may start on it automatically.

4. The app will install and open on the emulator.  
5. **No QR code?** (debug/profile) Tap **“Load sample map”** on the scanner screen to load the sample ATL map without using the camera.  
6. Then tap **“Preview navigation UI”** to open the navigation screen with a sample route (no speaking or scanning needed).  
7. **With a QR code:** Open **`tools/scan_atl_qr.html`** (from the repo root) in your browser and point the emulator’s camera at it (or set the emulator’s camera to your Mac’s webcam in Extended controls → Camera). When the app says **“Say your destination”**, say **“Seminar Hall”** or **“Idea Labs”**.

---

## Quick recap

| Step | Action |
|------|--------|
| 1 | Open **Android Studio** → complete Setup Wizard (first time only). |
| 2 | **More Actions** → **Virtual Device Manager** → **Create Device** → pick **Pixel 6** → choose system image (download if needed) → **Finish**. |
| 3 | Click **Play** on the virtual device to start the emulator. |
| 4 | Run `cd flutter_app && flutter run` and select the Android emulator. |
| 5 | Use the app: scan the QR from `tools/scan_atl_qr.html`, then say the destination. |

---

## Troubleshooting

- **“Unable to locate Android SDK”**  
  Run: `flutter config --android-sdk "$HOME/Library/Android/sdk"`  
  Then run `flutter doctor` again.

- **No emulator in Device Manager**  
  In Android Studio: **Tools** → **SDK Manager** → **SDK Tools** tab → ensure **Android Emulator** and **Android SDK Platform-Tools** are checked → **Apply**.

- **Emulator is slow or unresponsive**  
  In Device Manager, edit the AVD and increase **RAM** if your Mac has enough memory. Prefer an **arm64** system image on Apple Silicon (e.g. “ARM 64 v8a”).  
  **For a quick, responsive preview without the emulator**, run the app on **macOS** instead: `cd flutter_app && flutter run -d macos`. In debug/profile, use **“Load sample map”** and **“Preview navigation UI”** (no QR or camera needed).

- **Camera in emulator**  
  The emulator can use your Mac’s webcam. In the emulator app: **⋯** (Extended controls) → **Camera** → set front/back camera to **Webcam** or **Virtual scene**.

- **"Gradle task assembleDebug failed" / NDK errors**
  - If the error says the NDK is missing `source.properties` or is malformed: delete the broken NDK so Gradle can re-download it, e.g. `rm -rf /opt/homebrew/share/android-commandlinetools/ndk/28.2.13676358` (use the path from your error; Android Studio SDK uses `$HOME/Library/Android/sdk/ndk/`).
  - If the error is **"No space left on device"** when installing the NDK: free at least 2–3 GB on your Mac (the NDK is large), then run the build again.
