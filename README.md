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

## Core Technical Foundation

For universal mathematical grammar, Unicode normalization tables, SI unit expansion engines, and cross-platform architecture specifications, refer to [TECHNICAL.md](TECHNICAL.md).

## License

Vachanam is released under the **MIT License**. See [LICENSE](LICENSE) for details.
