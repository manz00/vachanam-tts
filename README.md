# Vachanam (వచనం)

**Universal Accessible Document Reader & Neural TTS Studio for Apple Silicon (iPadOS, iOS & Mac Catalyst).**

[![Platform](https://img.shields.io/badge/Platform-iPadOS%2018%2B%20%7C%20macOS%2015%2B%20%7C%20iOS%2018%2B-blue.svg)](https://developer.apple.com/)
[![Architecture](https://img.shields.io/badge/Architecture-Apple%20Silicon%20(Neural%20Engine)-orange.svg)](https://developer.apple.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## Overview

**Vachanam (వచనం)** is an accessibility-first reading ecosystem designed for students, researchers, and individuals with dyslexia, ADHD, visual impairments, or reading fatigue. It bridges the gap between dense multi-column academic literature and distraction-free comprehension by coupling an Apple Books-inspired reading UI (edge-tap pagination, two-page book spreads, continuous scroll, dynamic theme palettes, tap-to-hide chrome), library shelf organization, background book preloading/intelligence, and high-fidelity document rendering with on-device neural narration (Kokoro TTS via CoreML and MLX), synchronized word-by-word karaoke highlighting, ambient focus soundscapes, and multi-format ingestion.

> [!NOTE]
> **Shelved / Archived Platform: Android**
> The native Kotlin + Jetpack Compose Android platform implementation has been preserved and archived on the [`archive/android`](https://github.com/manz00/vachanam-tts/tree/archive/android) branch. Active engineering is focused exclusively on Apple Silicon (iPadOS, macOS, iOS), where Apple Neural Engine (ANE) and unified memory achieve superior real-time neural TTS generation without latency.

---

## 📥 Precompiled Packages

Official, ready-to-install precompiled packages are automatically built on every update and published via [GitHub Releases](https://github.com/manz00/vachanam-tts/releases):

| OS / Device | Package Format | Download | Install Notes |
| :--- | :--- | :--- | :--- |
| 🍏 **macOS (Apple Silicon)** | `Vachanam-macOS.dmg` | [**Download macOS DMG**](https://github.com/manz00/vachanam-tts/releases/latest) | Apple Disk Image: open `.dmg` and drag `Vachanam.app` into `/Applications`. |
| 🍏 **macOS (Portable)** | `Vachanam-MacCatalyst.zip` | [**Download macOS Zip**](https://github.com/manz00/vachanam-tts/releases/latest) | Standalone uncompressed app bundle archive. |

> [!TIP]
> All build artifacts, previous version archives, and SHA-256 integrity checksums are available on the [Releases Page](https://github.com/manz00/vachanam-tts/releases).

---

## Repository Structure

```text
vachanam-tts/
├── VachanamApple/              # Native Apple (iPadOS & Mac Catalyst) Swift application
│   ├── README.md               # Apple user guide, features, keyboard shortcuts, hardware tiers
│   ├── TECHNICAL.md            # Apple architecture, Quartz 2D math, CoreML/MLX, AUD-01..34
│   ├── Vachanam.xcodeproj/     # Xcode project package
│   ├── generate_project.py     # Self-contained project generator & synchronizer
│   ├── Shared/                 # Universal reader engine, document parsers, Kokoro TTS
│   ├── iOS/                    # Apple Pencil & PencilKit continuous annotation canvas
│   ├── macOS/                  # Audiobook Studio batch synthesis & Catalyst menu commands
│   ├── Tests/                  # Swift unit test suites
│   ├── UITests/                # Swift automated UI test suites
│   ├── Packages/               # Kokoro CoreML & Misaki Swift local packages
│   └── Resources/              # Weights, soundscapes, fonts, benchmark PDFs
├── .github/workflows/          # Automated GitHub Actions CI/CD pipelines
│   ├── ci.yml                  # Mac Catalyst and iOS Simulator test validation
│   └── release.yml             # Automated Apple DMG, zip, and release publishing
├── README.md                   # Repository overview & project guide (this document)
├── TECHNICAL.md                # System architecture, mathematical speech grammar, audit log
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

## 🚀 Device Deployment & Over-the-Air (OTA) Updates

Vachanam provides an automated continuous delivery pipeline via **GitHub Actions** (`.github/workflows/`). Pushing code updates to the `main` branch automatically triggers cloud builds and prepares releases.

### 🍏 Apple Devices (iPad, iPhone & Mac)

#### Option 1: Mac (Mac Catalyst) Direct Install
- GitHub Actions packages `Vachanam-macOS.dmg` and `Vachanam-MacCatalyst.zip` and attaches them directly to each GitHub Release. Download, open `.dmg` or unzip, and drag `Vachanam.app` into `/Applications`.

#### Option 2: Direct USB / Wi-Fi Install via Xcode (iPad & iPhone)
- Connect iPad or iPhone via USB-C or Wi-Fi pairing.
- Open `VachanamApple/Vachanam.xcodeproj` in Xcode, select your device as destination, and hit **Run** (`⌘R`).

#### Option 3: TestFlight Over-the-Air (iPad & iPhone)
1. In **App Store Connect**, generate an **App Store Connect API Key** (`Key ID`, `Issuer ID`, `.p8` file).
2. Add these credentials to GitHub Repository Secrets (`APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_KEY_BASE64`).
3. Deployments archive and deploy to TestFlight where automatic updates deliver releases directly to devices.

---

## 🛡️ Security, Cryptographic Verification & Supply-Chain Hardening

- **Immutable Actions Pinning**: All GitHub Actions workflows are pinned to full commit SHAs with scoped minimal permissions (`permissions: {}` top-level).
- **Cryptographic Asset Checksums**: Every release publishes verified SHA-256 hashes (`.sha256`) embedded in the release notes so users can verify binary integrity prior to installing or running.
- **SSRF & Network Ingestion Hardening**: Live web article importing validates HTTPS schemes only, checks DNS resolution, and rejects private/loopback/cloud metadata IP ranges with a hard 5 MB streaming cap.
- **Archive & ZIP Bomb Defense**: `ZipArchive` strips path traversals (`..`) and null bytes (`\0`), caps single entry decompression to 100 MB and cumulative archive expansion to 500 MB, and rejects zip bombs with expansion ratios > 1000:1.
- **Production Privacy**: All diagnostic console logs containing file paths, reading progress, or document content are gated behind `#if DEBUG`.

---

## Core Technical Foundation

For universal mathematical grammar, Unicode normalization tables, SI unit expansion engines, and cross-platform architecture specifications, refer to [TECHNICAL.md](TECHNICAL.md).

## License

Vachanam is released under the **MIT License**. See [LICENSE](LICENSE) for details.
