# Vachanam (ವಚನಮ್)

**An accessibility-focused PDF reader with on-device TTS, word/sentence highlighting, and full annotation tools for iPad & Mac (Apple Silicon).**

---

## Overview

**Vachanam** is engineered specifically for readers with dyslexia, visual impairments, reading fatigue, or cognitive processing differences. It bridges the gap between structured academic documents and fluid digital reading by pairing native PDF viewing with an extracted distraction-free **Reader View**, powered by a pluggable on-device **Neural Text-to-Speech (TTS)** engine.

As documents are narrated, Vachanam synchronizes **word-by-word karaoke highlighting** alongside **sentence-level background bands**, smooth auto-scrolling, a dyslexia reading ruler guide, and a full Apple Pencil annotation suite.

---

## Key Highlights

- **4 On-Device TTS Models**:
  1. **Kokoro 82M** (Default, lightweight, ultra-fast English narration, runs on 4GB+ RAM devices)
  2. **Qwen3-TTS 0.6B** (High fidelity, expressive prosody, native word timestamps, requires 8GB+ RAM)
  3. **Chatterbox Turbo** (Emotion markup like `[laugh]`, `[sigh]`, requires 8GB+ RAM)
  4. **CosyVoice 3 0.5B** (4-bit quantized MLX streaming synthesis, requires 8GB+ RAM)
- **Pluggable Architecture**: Model downloading, caching, storage cleanup, and RAM capability checks.
- **Dual Reading Modes**:
  - **Original PDF Layout**: Native PDFKit rendering with interactive overlays.
  - **Reader View Mode**: Re-rendered typography with custom fonts, line heights, and margins.
- **Accessibility Suite**:
  - **OpenDyslexic Typography**: Integrated font support with weighted baselines.
  - **Reading Ruler**: Adjustable tinted guide bar with customizable height and opacity.
  - **Theme Presets**: Cream (`#FBF0D9`), Sepia (`#F4ECD8`), Dark Slate (`#151D2A`), OLED Black (`#000000`), and Pure White.
  - **High Contrast**: WCAG AAA-compliant high-contrast mode.
- **Full Annotations Engine**:
  - **PencilKit**: Smooth Apple Pencil & finger drawing, highlighter, and vector eraser.
  - **Shapes**: Rectangles, circles, arrows, and callouts.
  - **Sticky Notes**: Draggable, expandable note pins anchored to page positions.
  - **Text Boxes**: Typed comments with customizable font size.
  - **Undo / Redo**: Multi-step transactional stack.
  - **Markdown Export**: One-tap export of all bookmarks, sticky notes, and text annotations.
- **Audio Controls & Dual Engine**:
  - Native instant speech synthesis fallback (`AVSpeechSynthesizer`) for natural out-of-the-box narration with exact word tracking.
  - Neural audio playback (`AVAudioPlayer`) for CoreML/MLX models without simulator HALC proxy issues.
  - Background audio playback (`UIBackgroundModes = ["audio"]`).
  - Lock screen and Control Center media integration via `MPRemoteCommandCenter`.
  - Sleep timer (15m, 30m, 45m, 60m, end of page).
  - Variable speed control (0.5x to 2.0x).
- **Navigation & Library**:
  - Interactive Table of Contents (TOC) and Bookmarks sidebar.
  - Visual page thumbnail scrubber grid.
  - Reading history with percentage tracking and estimated completion time.
  - Keyboard shortcuts (Spacebar for Play/Pause).

---

## Project Structure

```
vachanam-tts/
├── Vachanam.xcodeproj                  # Xcode project for iPad and Mac Catalyst
├── generate_project.py                 # Reproducible project generator
├── Vachanam/
│   ├── App/
│   │   ├── VachanamApp.swift           # Application @main entry point & background audio setup
│   │   ├── ContentView.swift           # Root navigation coordinator & keyboard shortcuts
│   │   └── AppState.swift              # Global document and navigation state
│   │
│   ├── Views/
│   │   ├── Library/
│   │   │   ├── DocumentLibraryView.swift   # Main document library with file picker & sample generator
│   │   │   ├── DocumentCard.swift          # Card preview with thumbnail and progress bar
│   │   │   └── ReadingHistoryView.swift    # Reading history list
│   │   ├── Reader/
│   │   │   ├── ReaderContainerView.swift   # Core container hosting PDF/Reader modes & overlays
│   │   │   ├── PDFReaderView.swift         # PDFKit UIViewRepresentable wrapper
│   │   │   ├── ReaderTextView.swift        # Typography view with live inline highlights
│   │   │   ├── ReadingModeToggle.swift     # Capsule switch (PDF vs Reader View)
│   │   │   ├── PageThumbnailGrid.swift     # Visual thumbnail grid for quick scrubbing
│   │   │   └── TOCView.swift               # Table of Contents and Bookmarks drawer
│   │   ├── TTS/
│   │   │   ├── TTSControlBar.swift         # Play/pause, speed, voice picker, sleep timer bar
│   │   │   ├── VoicePickerView.swift       # Voice selection and model picker sheet
│   │   │   └── SleepTimerView.swift        # Sleep timer countdown sheet
│   │   ├── Highlight/
│   │   │   ├── WordHighlightOverlay.swift  # Word-by-word karaoke highlight box
│   │   │   ├── SentenceHighlightOverlay.swift # Sentence-level colored band
│   │   │   ├── ReadingRuler.swift          # Tinted reading ruler guide
│   │   │   └── HighlightSettingsView.swift # Highlight mode and ruler config sheet
│   │   ├── Annotations/
│   │   │   ├── AnnotationToolbar.swift     # Floating toolbar with Pen, Highlighter, Eraser, Shapes
│   │   │   ├── CanvasOverlay.swift         # PencilKit PKCanvasView wrapper
│   │   │   ├── ShapeToolView.swift         # Geometric shapes canvas
│   │   │   ├── StickyNoteView.swift        # Draggable sticky note pins
│   │   │   ├── TextBoxView.swift           # Draggable typed text boxes
│   │   │   └── AnnotationExportView.swift  # Markdown notes export sheet
│   │   ├── Models/
│   │   │   ├── ModelManagerView.swift      # Neural model manager sheet
│   │   │   ├── ModelCard.swift             # Model specifications and download card
│   │   │   └── ModelDownloadProgress.swift # Download progress bar
│   │   ├── Settings/
│   │   │   ├── SettingsView.swift          # Main settings screen
│   │   │   ├── AccessibilitySettingsView.swift # OpenDyslexic, sizing, contrast
│   │   │   ├── ReadingSettingsView.swift   # Highlighting style, auto-scroll
│   │   │   └── AppearanceSettingsView.swift # Reader themes and dark mode
│   │   └── Components/
│   │       ├── ProgressBar.swift           # Reading progress bar
│   │       └── BookmarkButton.swift        # Animated bookmark toggle
│   │
│   ├── TTS/
│   │   ├── TTSModelProtocol.swift          # Pluggable model interface & TTSError
│   │   ├── TTSModelInfo.swift              # Model metadata, formats, tiers
│   │   ├── TTSController.swift             # Speech orchestrator & word synchronization
│   │   ├── VoiceProfileResolver.swift      # Model voice presets & pitch/rate mapping
│   │   ├── ModelManager.swift              # Model downloader, disk cache, delete
│   │   ├── ModelRegistry.swift             # Model catalog loader
│   │   └── DeviceCapability.swift          # Hardware RAM checker & tier filters
│   │
│   ├── Adapters/
│   │   ├── KokoroAdapter.swift             # Kokoro 82M CoreML adapter
│   │   ├── Qwen3TTSAdapter.swift           # Qwen3-TTS 0.6B CoreML adapter
│   │   ├── ChatterboxAdapter.swift         # Chatterbox Turbo CoreML adapter
│   │   ├── CosyVoice3Adapter.swift         # CosyVoice 3 0.5B MLX adapter
│   │   └── G2P/
│   │       ├── G2PProtocol.swift           # Phonemizer protocol
│   │       └── MisakiG2P.swift             # Misaki English phonemizer
│   │
│   ├── Audio/
│   │   ├── AudioPlayer.swift               # AVAudioEngine streaming player
│   │   ├── AudioSession.swift              # Background audio & MPRemoteCommandCenter
│   │   └── SleepTimer.swift                # Sleep timer logic
│   │
│   ├── PDF/
│   │   ├── TextExtractor.swift             # Sentence & word bounding box extractor
│   │   ├── ReaderDocument.swift            # PDFKit document wrapper & TOC
│   │   ├── BookmarkManager.swift           # Bookmark persistence
│   │   └── ReadingProgressTracker.swift    # Reading history & estimated time
│   │
│   ├── Annotations/
│   │   ├── AnnotationManager.swift         # Annotations persistence
│   │   ├── UndoRedoManager.swift           # Undo/redo stack
│   │   └── AnnotationExporter.swift        # Markdown digest generator
│   │
│   ├── Accessibility/
│   │   ├── ThemeManager.swift              # Warm dark theme & background presets
│   │   ├── FontManager.swift               # OpenDyslexic & font scaling
│   │   └── AccessibilityManager.swift      # Highlighting & ruler settings
│   │
│   ├── Resources/
│   │   ├── model_registry.json             # 4 TTS models catalog
│   │   └── Assets.xcassets                 # AccentColor & AppIcon
│   │
│   └── Info.plist                          # Background audio, document types, file sharing
│
├── VachanamTests/
│   ├── TTSTests/
│   │   ├── TTSModelProtocolTests.swift     # Model synthesis & timestamp tests
│   │   ├── ModelManagerTests.swift         # Registry & active model tests
│   │   └── DeviceCapabilityTests.swift     # RAM tier compatibility tests
│   ├── PDFTests/
│   │   ├── TextExtractorTests.swift        # Sentence tokenization & word rect tests
│   │   └── BookmarkManagerTests.swift      # Bookmark lifecycle tests
│   ├── AnnotationTests/
│   │   ├── AnnotationManagerTests.swift    # Annotations persistence tests
│   │   ├── UndoRedoTests.swift             # Undo/redo stack tests
│   │   └── AnnotationExporterTests.swift   # Markdown export formatting tests
│   └── AccessibilityTests/
│       └── FontManagerTests.swift          # Font resolution tests
│
└── VachanamUITests/
    ├── ReaderFlowTests.swift               # Launch & document flow test
    ├── ModelManagementTests.swift          # Models sheet UI test
    └── AccessibilityUITests.swift          # Settings UI test
```

---

## Hardware Requirements & Model Tiers

| Model | Size | Min RAM | Architecture | Best For |
|---|---|---|---|---|
| **Kokoro** | ~88 MB | 4 GB | CoreML (Misaki G2P) | All iPads (Air M-series & older) & Mac, long-form reading |
| **Qwen3-TTS** | ~2.5 GB | 8 GB | CoreML | High quality narration, native word alignment |
| **Chatterbox** | ~1.5 GB | 8 GB | CoreML | Emotion markup (`[laugh]`, `[sigh]`), character voices |
| **CosyVoice 3**| ~1.2 GB | 8 GB | MLX (4-bit quantized) | Streaming narration, voice cloning |

*Note: Devices with less than 8GB RAM will automatically indicate that heavier models require 8GB+ unified memory.*

---

## How to Build & Run

### 1. Requirements
- macOS Sonoma 14.0+
- Xcode 15.3+ (installed with iOS 17.0+ SDK)
- iPad Air (M-series recommended) or Apple Silicon Mac

### 2. Sideloading to iPad via Xcode
1. Open `Vachanam.xcodeproj` in Xcode:
   ```bash
   open Vachanam.xcodeproj
   ```
2. Connect your iPad via USB or Wi-Fi.
3. In Xcode, select the **Vachanam** scheme and choose your iPad as the run destination.
4. Under **Signing & Capabilities**, select your Apple ID Development Team.
5. Press **Cmd + R** to build, install, and launch Vachanam on your iPad.

### 3. Running on Mac (Mac Catalyst)
1. Select the **Vachanam** scheme.
2. Select destination: **My Mac (Mac Catalyst)**.
3. Press **Cmd + R**.

---

## Keyboard Shortcuts (Mac & iPad Keyboard)

| Key | Action |
|---|---|
| **Spacebar** | Play / Pause narration |
| **Left Arrow / Right Arrow** | Previous / Next sentence |
| **Cmd + F** | Search in document |

---

## Troubleshooting & Simulator Tips

- **Simulator Error: "Busy (Application failed preflight checks)"**:
  - Occurs when Xcode attempts to launch while the iOS Simulator's SpringBoard daemon is transitioning states.
  - Fix: Simply re-run (`Cmd + R`) or reboot the simulator via `Simulator > Device > Restart`.
- **Console Log: "AddInstanceForFactory: No factory registered for id <CFUUID ...> F8BB1C28-BAE8-11D6-9C31-00039315CD46"**:
  - This is an internal CoreAudio Hardware Abstraction Layer (HAL) diagnostic emitted by macOS when initializing virtual audio devices in the iOS Simulator.
  - It is completely harmless, expected in simulator environments, and has no effect on audio playback, synthesis, or stability. On physical iPad hardware, this log does not appear.
- **Console Log: "Unable to get ISSymbol for UTI: com.apple.ios-simulator Error..."**:
  - Emitted by macOS's `IconServices` daemon when Xcode launches a process in the simulator and attempts to resolve a macOS system icon for the virtual simulator UTI.
  - This is a known macOS/Xcode cosmetic log. It has zero impact on app execution, UI rendering, or functionality, and does not occur on physical devices.
- **Simulator Container UUID Changes & Sample Guide**:
  - iOS Simulator reinstallation generates new sandbox container UUIDs. Vachanam dynamically resolves document filenames in the persistent `Documents` directory and auto-regenerates the multi-page `Vachanam_Getting_Started.pdf` guide if a previous container's temporary path was stored.
- **Console Log: "LoudnessManager.mm: ... cannot get acoustic ID" & "AVAudioBuffer.mm: mBuffers[0].mDataByteSize (0)"**:
  - Emitted internally by Apple's CoreAudio / AVSpeechSynthesis subsystem in simulator environments because the virtual simulator device does not possess physical hardware speaker acoustic calibration profiles (`LoudnessManager plist`). It is completely benign and does not occur on physical iPad/Mac hardware.
- **Console Log: "Error fetching voices: DecodingError.dataCorrupted" & "Error fetching locales"**:
  - Emitted by Apple's internal system voice catalog parser on macOS Sequoia / iOS 18 Simulator when querying `AVSpeechSynthesisVoice.speechVoices()`. `VoiceProfileResolver` caches voices at startup to prevent redundant disk queries on every spoken sentence.
- **SwiftUI View Update Cycle Prevention**:
  - Highlighting rect updates and sentence geometry in `PDFReaderView` are dispatched asynchronously to the main run loop and guarded against duplicate assignments, preventing "Publishing changes from within view updates" warnings during SwiftUI render passes.

---

## Speech Synthesis Architecture & Voice Profile Resolver

Vachanam incorporates a hybrid on-device speech pipeline:
1. **Neural Model Inference**: When compiled CoreML weights (`.mlmodelc`) are present on device, models synthesize raw PCM audio buffers.
2. **Voice Profile Resolver**: In simulator environments or when neural weights are not yet downloaded, `VoiceProfileResolver` dynamically maps the active model and voice preset (`af_heart`, `am_michael`, `bf_emma`, etc.) to matching high-definition system voices with fine-tuned pitch multipliers, cadence adjustments, and emotion tag stripping. This guarantees:
   - **Zero Static / "Air" Sound**: Never outputs empty buffers or placeholder sine wave audio.
   - **Voice Variety**: Female, male, and British English voice personalities tailored to each model preset.
   - **Instant Latency**: Zero initialization delay on all devices.

---

## PDF Coordinate Conversion & Highlighting Pipeline

Highlighting in PDFKit requires translating from **PDF page coordinate space** (origin `(0, 0)` at bottom-left, Y going up) into **view coordinate space** (origin `(0, 0)` at top-left, Y going down):
- **`PDFReaderView` Coordinator**: Uses `pdfView.convert(rect, from: page)` to calculate the exact on-screen geometry for both sentence lines and words.
- **Multi-Line Wrapping**: Sentences spanning multiple lines are split into distinct rectangles using `PDFSelection.selectionsByLine()`, eliminating oversized bounding boxes.
- **CALayer Sub-pixel Rendering**: Renders highlights using hardware-accelerated `CALayer`s inside a dedicated overlay view attached directly to `PDFView`. Automatically re-aligns upon zooming, panning, or page flipping.
- **Exact Word Alignment**: Uses 0-based `sentenceRange` tokenization matching `AVSpeechSynthesizerDelegate.willSpeakRangeOfSpeechString`, ensuring every articulated word lights up with 100% precision.

---

## Neural Model Memory Lifecycle & Loaded State Architecture

Vachanam provides memory-managed lifecycle controls tailored for Apple Silicon Unified Memory:

```
[Cloud / Remote] ──Download──> [On-Disk Cache] ──Load──> [Unified RAM (Active Model)] ──Unload──> [On-Disk Cache]
```

1. **Package Assets & Directory Structure**:
   - Model downloads generate complete runtime manifests: `manifest.json`, `config.json`, `misaki_dict.json`, `Kokoro.mlmodelc/`, and `weights.bin` in `Application Support/Vachanam/Models/<modelId>/`.
2. **Unified Memory Management (`loadModel` / `unloadModel`)**:
   - Calling `loadModel(weightsDirectory:)` verifies directory integrity, warms up the Misaki G2P phonetic lookup cache, and transitions `isLoaded = true`.
   - Calling `unloadModel()` purges cached execution buffers, freeing up RAM for multitasking on devices with lower memory constraints.
3. **Automatic Lifecycle Synchronization**:
   - When an active model finishes downloading, `ModelManager` and `TTSController` automatically load it into RAM.
   - When switching active models, the outgoing model is unloaded and the incoming model is loaded asynchronously.
   - When playback starts, `TTSController` automatically ensures the model is loaded in memory before synthesis begins.
4. **Live UI Status Indicators**:
   - **`ModelCard`**: Displays glowing status badges: `● LOADED IN RAM (300 MB)` with an **"Unload"** button, `○ UNLOADED (On Disk)` with a **"Load into RAM"** button, and an active progress spinner while loading.
   - **`VoicePickerView`**: Displays green `Loaded` dots for in-memory models, `Downloaded` disk icons, and `Cloud` download indicators.
   - **`TTSControlBar`**: Features an active model status capsule (`Kokoro • af_heart` with a green pulse dot when loaded and ready).

---

## License

Personal accessibility open-source project. Free for all users.
