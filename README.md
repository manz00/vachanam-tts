# Vachanam (వచనం)

**Universal Accessible Document Reader & Neural TTS Studio for Apple (iPadOS & Mac Catalyst) and Android (Kotlin + Jetpack Compose).**

[![Platform](https://img.shields.io/badge/Platform-iPadOS%2018%2B%20%7C%20macOS%2015%2B%20%7C%20Android%2012%2B%20(API%2031%2B)-blue.svg)](https://developer.android.com/)
[![Architecture](https://img.shields.io/badge/Architecture-Apple%20Silicon%20%26%20ARM64%20Android-orange.svg)](https://developer.apple.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## Overview

**Vachanam (వచనం)** is an accessibility-first reading ecosystem designed for students, researchers, and individuals with dyslexia, ADHD, visual impairments, or reading fatigue. It bridges the gap between dense multi-column academic literature and distraction-free comprehension by coupling an Apple Books-inspired reading UI (edge-tap pagination, two-page book spreads, continuous scroll, dynamic theme palettes, tap-to-hide chrome), library shelf organization, background book preloading/intelligence, and high-fidelity document rendering with on-device neural narration, synchronized word-by-word karaoke highlighting, ambient focus soundscapes, and multi-format ingestion.

The project is architected as two native, self-contained platform implementations sharing a unified 3-layer semantic document model:

| Platform | Location | Language & UI | Documentation |
| :--- | :--- | :--- | :--- |
| **Apple (iPadOS & macOS)** | [`VachanamApple/`](VachanamApple/) | Swift 5.0, SwiftUI, PencilKit, Catalyst | [Apple README](VachanamApple/README.md) • [Apple TECHNICAL](VachanamApple/TECHNICAL.md) |
| **Android (12+)** | [`VachanamAndroid/`](VachanamAndroid/) | Kotlin 2.0, Jetpack Compose, Material 3 | [Android README](VachanamAndroid/README.md) • [Android TECHNICAL](VachanamAndroid/TECHNICAL.md) |

---

## Repository Structure

```
vachanam-tts/
├── VachanamApple/              # Native Apple (iPadOS & Mac Catalyst) Swift application
│   ├── README.md               # Apple user guide, features, keyboard shortcuts, hardware tiers
│   ├── TECHNICAL.md            # Apple architecture, Quartz 2D math, CoreML/MLX, AUD-01..18
│   ├── Vachanam.xcodeproj/     # Xcode project package
│   ├── generate_project.py     # Self-contained project generator & synchronizer
│   ├── Shared/                 # Universal reader engine, document parsers, Kokoro TTS
│   ├── iOS/                    # Apple Pencil & PencilKit continuous annotation canvas
│   ├── macOS/                  # Audiobook Studio batch synthesis & Catalyst menu commands
│   ├── Tests/                  # Swift unit test suites
│   ├── UITests/                # Swift automated UI test suites
│   ├── Packages/               # Kokoro CoreML local Swift package
│   └── Resources/              # Weights, soundscapes, fonts, benchmark PDFs
├── VachanamAndroid/            # Native Android (Kotlin + Jetpack Compose) application
│   ├── README.md               # Android user guide, Material 3 suite, build instructions
│   ├── TECHNICAL.md            # Android architecture, PDFBox, Android TTS/ONNX, AUD-17
│   ├── app/                    # Main Android application module
│   │   ├── src/main/java/      # Kotlin source (app, data, pdf, tts, audio, accessibility, ui)
│   │   ├── src/main/res/       # Material 3 themes, OpenDyslexic fonts, raw focus loops
│   │   └── src/test/java/      # JVM unit tests (VachanamCoreLogicTest)
│   ├── build.gradle.kts        # Root Gradle build script
│   └── settings.gradle.kts     # Gradle settings
├── README.md                   # Monorepo overview & platform directory hub (this document)
├── TECHNICAL.md                # Cross-platform shared architecture & mathematical speech grammar
├── AGENTS.md                   # Repository memory, project integrity rules & test commands
└── LICENSE                     # MIT License
```

---

## Quickstart: Build & Run

### 🍏 Apple (iPadOS & Mac Catalyst)
```bash
cd VachanamApple

# 1. Synchronize Xcode Project
python3 generate_project.py

# 2. Build for Mac Catalyst
xcodebuild -project Vachanam.xcodeproj -scheme Vachanam -destination 'platform=macOS,variant=Mac Catalyst' -quiet build

# 3. Run Unit Tests (Mac Catalyst)
xcodebuild -project Vachanam.xcodeproj -scheme Vachanam -destination 'platform=macOS,variant=Mac Catalyst' -only-testing:VachanamTests -quiet test

# 4. Run Unit Tests (iPad Simulator)
xcodebuild -project Vachanam.xcodeproj -scheme Vachanam -destination 'platform=iOS Simulator,name=iPad Air 11-inch (M4)' -only-testing:VachanamTests -quiet test
```
*For in-depth Apple documentation, see [VachanamApple/README.md](VachanamApple/README.md).*

---

### 🤖 Android (Kotlin + Jetpack Compose)
```bash
cd VachanamAndroid

# 1. Run Unit Tests
./gradlew testDebugUnitTest

# 2. Assemble Debug APK
./gradlew assembleDebug

# 3. Install on connected device/emulator
./gradlew installDebug
```
*For in-depth Android documentation, see [VachanamAndroid/README.md](VachanamAndroid/README.md).*

---

## 🚀 Device Deployment & Over-the-Air (OTA) Auto-Updates

Vachanam provides an automated continuous delivery pipeline via **GitHub Actions** (`.github/workflows/`). Pushing code updates to the `main` branch automatically triggers cloud builds and prepares over-the-air updates across your devices.

### 🤖 Android Devices (Phones, Tablets & E-Ink)

#### Option 1: Automatic Over-the-Air Updates via Obtainium (Recommended)
1. Install [Obtainium](https://github.com/ImranR98/Obtainium) on your Android device (an open-source app manager that tracks GitHub releases).
2. Tap **Add App** and enter the repository URL: `https://github.com/manz00/vachanam-tts`.
3. In app settings within Obtainium, enable **Background Updates** / **Auto-Install**.
4. **Whenever you push an update to `main`**, GitHub Actions builds `Vachanam-Android.apk` and releases it. Obtainium automatically detects the new release, downloads it, and prompts to update your device.

#### Option 2: Direct Local Install via ADB
```bash
# Connect Android device via USB with USB Debugging enabled (or wireless adb)
cd VachanamAndroid
./gradlew installDebug
```

---

### 🍏 Apple Devices (iPad, iPhone & Mac)

#### Option 1: Over-the-Air Background Updates via TestFlight (iPad & iPhone)
1. iOS and iPadOS enforce Apple code signing requirements for over-the-air installation.
2. In **App Store Connect**, generate an **App Store Connect API Key** (`Key ID`, `Issuer ID`, `.p8` file).
3. Add these credentials to GitHub Repository Secrets (`APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_KEY_BASE64`).
4. Every push to `main` triggers `.github/workflows/release-apple.yml` to archive and deploy to TestFlight.
5. In the **TestFlight app** on your iPad, open Vachanam and toggle **Automatic Updates: ON**. Your iPad will automatically update silently in the background whenever you push updates.

#### Option 2: Mac (Mac Catalyst) Direct Install
- GitHub Actions packages `Vachanam-MacCatalyst.zip` and attaches it directly to each GitHub Release. Download, unzip, and drag `Vachanam.app` into `/Applications`.

#### Option 3: Direct USB / Wi-Fi Install via Xcode
- Connect iPad via USB-C or Wi-Fi pairing.
- Open `VachanamApple/Vachanam.xcodeproj` in Xcode, select your iPad as destination, and hit **Run** (`⌘R`).

---

### 🛡️ Security, Cryptographic Verification & Supply-Chain Hardening

- **Immutable Actions Pinning**: All GitHub Actions workflows are pinned to full commit SHAs with scoped minimal permissions (`permissions: {}` top-level).
- **Cryptographic Asset Checksums**: Every release publishes verified SHA-256 hashes (`.sha256`) embedded in the release notes so users can verify binary integrity prior to sideloading or running.
- **SSRF & Network Ingestion Hardening**: Live web article importing validates HTTPS schemes only, checks DNS resolution, and rejects private/loopback/cloud metadata IP ranges with a hard 5 MB streaming cap.
- **Archive & ZIP Bomb Defense**: `ZipArchive` strips path traversals (`..`) and null bytes (`\0`), caps single entry decompression to 100 MB and cumulative archive expansion to 500 MB, and rejects zip bombs with expansion ratios > 1000:1.
- **Production Privacy**: All diagnostic console logs containing file paths, reading progress, or document content are gated behind `#if DEBUG`.
- **R8 / ProGuard Minification**: Android release builds enable full R8 code stripping and resource shrinking.

---

## Core Technical Foundation

For universal mathematical grammar, Unicode normalization tables, SI unit expansion engines, and cross-platform architecture specifications, refer to [TECHNICAL.md](TECHNICAL.md).

## License

Vachanam is released under the **MIT License**. See [LICENSE](LICENSE) for details.
