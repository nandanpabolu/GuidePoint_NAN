# Run GuidePoint on macOS (Desktop App)

Run the app as a native macOS desktop app. No emulator or phone needed.

---

## Prerequisites

1. **Full Xcode** (not just Command Line Tools)
   - Install from [App Store](https://apps.apple.com/app/xcode/id497799835) (~12 GB)
   - Or download from [developer.apple.com/xcode](https://developer.apple.com/xcode/)

2. **Configure Xcode** (first time only):
   ```bash
   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
   sudo xcodebuild -runFirstLaunch
   ```

3. **CocoaPods** (for Flutter macOS plugins):
   ```bash
   sudo gem install cocoapods
   ```

4. **Verify**:
   ```bash
   flutter doctor
   ```
   You should see ✓ for Xcode.

---

## Run the App

```bash
./scripts/run_macos.sh
```

Or manually:

```bash
cd flutter_app
flutter pub get
flutter run -d macos
```

---

## Demo Without QR or Camera

1. Tap **“Load sample map”** on the scanner screen (debug/profile; loads sample ATL map)
2. Tap **“Preview navigation UI”** to open the navigation screen with sample route

---

## Troubleshooting

- **"xcodebuild: unable to find utility"** → Full Xcode is not installed. Install from App Store.
- **"CocoaPods not installed"** → Run `sudo gem install cocoapods`
- **"Xcode installation is incomplete"** → Run `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer`
