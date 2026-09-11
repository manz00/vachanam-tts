# Vachanam (వచనం)

**An accessibility-focused universal reader with on-device Neural TTS, synchronized karaoke highlighting, focus soundscapes, and Apple Pencil annotations for iPad and Mac.**

[![Platform](https://img.shields.io/badge/Platform-iPadOS%2018%2B%20%7C%20macOS%2015%2B%20(Catalyst)-blue.svg)](https://developer.apple.com/apple-silicon/)
[![Architecture](https://img.shields.io/badge/Architecture-Apple%20Silicon%20(M--Series)-orange.svg)](https://developer.apple.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Technical Docs](https://img.shields.io/badge/Docs-Technical%20%26%20Core%20Logic-purple.svg)](TECHNICAL.md)

---

## Overview

**Vachanam (వచనం)** is engineered specifically for readers with dyslexia, visual impairments, ADHD, reading fatigue, or cognitive processing differences. It bridges the gap between complex academic documents and fluid digital reading by pairing native PDF viewing with an extracted, distraction-free **Reader View**, powered by a pluggable on-device **Neural Text-to-Speech (TTS)** engine.

As documents are narrated, Vachanam synchronizes **word-by-word karaoke highlighting** alongside **sentence-level background bands**, smooth auto-scrolling, a dyslexia reading ruler guide, ambient focus soundscapes, and an Apple Pencil annotation suite.

For low-level mathematical speech models, coordinate systems, parser specifications, and the complete audit history, see [TECHNICAL.md](TECHNICAL.md).

---

## Key Features

### 🎙️ 5 Pluggable On-Device Neural TTS Models
1. **Apple Natural** (Built-in offline iOS speech synthesis, zero download)
2. **Kokoro 82M** (Default, lightweight, ultra-fast English narration, runs on 4GB+ RAM devices)
3. **Qwen3-TTS 0.6B** (High fidelity, expressive prosody, native word timestamps, requires 8GB+ RAM)
4. **Chatterbox Turbo** (Emotion markup like `[laugh]`, `[sigh]`, requires 8GB+ RAM)
5. **CosyVoice 3 0.5B** (4-bit quantized MLX streaming synthesis, requires 8GB+ RAM)

### 🎧 Ambient Focus Soundscapes
- Integrated acoustic background player with 5 tailored ambient loops: **Brown Noise**, **Pink Noise**, **40Hz Binaural Beats**, **Soft Rain**, and **Library Ambience**.
- Independent volume slider (`0.0`–`1.0`) with persistence, smooth fade-in/fade-out transitions, and audio session mixing (`.mixWithOthers`).
- Coupled with speech narration (starts on Play, pauses on Pause, stops on Stop) with an independent **Study Mode** toggle for reading without speech narration.

### 📖 Universal Multi-Format Document Ingestion
- **PDF**: Native Quartz 2D rendering with vector sub-pixel highlights and Apple Pencil ink annotations.
- **EPUB**: Custom streaming decompressor (`ZipArchive`) and spine parser (`EPUBParser`) tolerant of diverse formatting.
- **Markdown & Plain Text**: Automatic character encoding detection cascade (UTF-8, Latin-1, CP1252, UTF-16) and Setext/ATX heading recognition.
- **Web Articles**: URL extraction with HTML entity decoding and clean semantic block classification.

### ☁️ Mac Audiobook Studio & iCloud Pre-Generated Playback
- Turn your Mac into a local audiobook production studio (`AudiobookGeneratorView`).
- Pre-generates complete books with Kokoro neural speech into AAC `.m4a` chaptered audio and microsecond word timestamps (`manifest.json`).
- Automatic iCloud Drive synchronization (`iCloudSyncManager`) makes generated audiobooks instantly available across iPad, Mac, and mobile devices.
- Zero-latency iPad playback adapter (`PreGeneratedPlaybackAdapter`) streams or plays local cached chunks with instant word-by-word highlighting and zero on-device inference overhead.

### 📜 Multi-Layout PDF Display & Free Auto-Scroll
- **4 View Modes**: Single Page, Continuous Scroll, Two-Page Spread, and Continuous Spread.
- **Pause-on-Scroll Lifecycle & Zero Snap-Back**: When listening to speech, initiating a manual scroll immediately pauses auto-scrolling so you can freely browse.
- **Interactive "Auto-Scroll" Capsule**: A floating capsule (`[ ⬆ / ⬇ Spoken text • P. X • Auto-Scroll ▶ ]`) provides a real-time sentence snippet and one-tap return to the spoken location.
- **Line-Pitch Clamping**: Dynamically clamps sentence highlight boxes to document median line pitch, preventing highlight bleed on lines with tall LaTeX math symbols ($\forall, \Phi, \Longrightarrow$).

### ✏️ Dyslexia & Accessibility Tools
- **Distraction-Free Reader View**: Extracts clean running text with customizable typography (OpenDyslexic, San Francisco, Georgia), themes (Light, Sepia, Dark, OLED Black), and font sizing.
- **Bionic Reading Mode**: Highlights the first few letters of each word to guide the eye and improve fixation speed.
- **Dyslexia Reading Ruler**: Adjustable horizontal reading guide that tracks the active sentence line.
- **Full Apple Pencil Annotation Suite**: Inking, highlighting, erasing, and shape drawing directly on PDF pages via PencilKit.

---

## Keyboard Shortcuts Suite (Mac Catalyst & iPad)

| Key Combination | Action |
| :--- | :--- |
| **Spacebar** / **⌥ + Space** | Play / Pause narration |
| **←** / **→** or **⌥ + ←** / **⌥ + →** | Previous / Next spoken sentence |
| **Page Down** / **Page Up** | Advance / Reverse page |
| **⌘ + ←** / **⌘ + →** | First page / Last page |
| **⌘ + J** | Jump to specific page dialog |
| **⌘ + 1** / **⌘ + 2** / **⌘ + 3** / **⌘ + 4** | Single / Continuous / Two-Page / Continuous Spread |
| **⌘ + +** / **⌘ + -** / **⌘ + 0** | Zoom in / Zoom out / Fit page to screen |
| **⌘ + B** | Toggle bookmark on current page |
| **⌘ + T** | Show Table of Contents |
| **⌘ + G** | Show Thumbnail Grid overview |
| **⌘ + F** | Search in document |

---

## Hardware Requirements & Model Tiers

| Model | Size | Min RAM | Architecture | Best For |
| :--- | :--- | :--- | :--- | :--- |
| **Apple Natural** | 0 MB | 2 GB | Built-in AVSpeech | Zero-download, fast, default system fallback |
| **Kokoro 82M** | ~164 MB (Bundled) | 4 GB | CoreML (KokoroTTS + Misaki) | All iPads (Air M-series & older) & Mac, long-form reading |
| **Qwen3-TTS** | ~2.5 GB | 8 GB | CoreML | High quality narration, native word alignment |
| **Chatterbox** | ~1.5 GB | 8 GB | CoreML | Emotion markup (`[laugh]`, `[sigh]`), character voices |
| **CosyVoice 3** | ~1.2 GB | 8 GB | MLX (4-bit quantized) | Streaming narration, voice cloning |

---

## How to Build & Run

### 1. Requirements
- macOS Sonoma 14.0+ (macOS Sequoia 15.0+ recommended)
- Xcode 16.0+ (with iOS 18.0+ SDK)
- iPad Air (M-series recommended) or Apple Silicon Mac

### 2. Project Generation & Synchronization
The Xcode project file `Vachanam.xcodeproj` is generated and synchronized via `generate_project.py`:
```bash
python3 generate_project.py
```

### 3. Running on Mac (Mac Catalyst)
1. Open `Vachanam.xcodeproj` in Xcode:
   ```bash
   open Vachanam.xcodeproj
   ```
2. Select the **Vachanam** scheme and choose destination: **My Mac (Mac Catalyst)**.
3. Press **Cmd + R** (or run `xcodebuild -project Vachanam.xcodeproj -scheme Vachanam -destination 'platform=macOS,variant=Mac Catalyst' -quiet build`).

### 4. Sideloading to iPad via Xcode
1. Connect your iPad via USB or Wi-Fi.
2. In Xcode, select destination: your physical iPad (or **iPad Air 11-inch (M4)** simulator).
3. Under **Signing & Capabilities**, select your Apple ID Development Team.
4. Press **Cmd + R** to build and install.

---

## Project Structure

```
Vachanam/
├── App/                     # Application entry point, AppState & scene delegates
├── Document/                # Document parsing, extraction, and semantic modeling
│   ├── Models/              # SemanticDocument, SemanticPage, BlockType, DocumentFormat
│   ├── Parsers/             # EPUBParser, MarkdownParser, PlainTextParser, WebArticleParser, ZipArchive
│   └── SemanticDocumentBuilder.swift
├── TTS/                     # Speech synthesis, CoreML Kokoro engine, normalization & chunking
│   ├── Normalization/       # TextNormalizer, MathSpeechEngine, PronunciationManager
│   ├── Models/              # KokoroTTS integration, VoiceProfileResolver, TTSModels
│   └── Coordination/        # PlaybackCoordinator, PlaybackScope, AudioCache
├── Audio/                   # Focus soundscapes, background acoustics & audio session management
├── Views/                   # SwiftUI & UIKit view hierarchy
│   ├── Reader/              # PDFReaderView, ReaderContainerView, ReaderView, ScrubberBar
│   ├── Library/             # DocumentLibraryView, RecentDocuments, Import sheets
│   ├── Studio/              # AudiobookGeneratorView, Studio export controls
│   └── Settings/            # ReadingSettingsView, VoicePickerView, ModelCard
├── Resources/               # Asset catalogs, AppIcon, Kokoro CoreML weights & test PDFs
└── Packages/                # Embedded packages (kokoro-coreml)
```

---

## Technical Architecture & Core Logic

For deep architectural details, see [TECHNICAL.md](TECHNICAL.md), which includes:
- **3-Layer Architecture**: Coordinate transforms between PDFKit Quartz 2D and SwiftUI/UIKit.
- **Algorithmic Engines**: Mathematical speech grammar, regex rules, SI unit expansions, and page furniture detection.
- **Universal Parsers**: ARM64 unaligned ZIP memory reading, chunked streaming deflate, and encoding cascades.
- **Audio & Synchronization**: Single authoritative `PlaybackCursor`, drift telemetry, and silence injection.
- **Memory Management**: Apple Silicon Unified Memory load/unload lifecycles.
- **Technical Audit History**: Detailed resolution log for `[AUD-01]` through `[AUD-15]`.

---

## License

Vachanam is released under the **MIT License**. See [LICENSE](LICENSE) for details.
