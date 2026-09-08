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
│   │   ├── TTSModelProtocol.swift          # Pluggable model interface
│   │   ├── TTSModelInfo.swift              # Model metadata, formats, tiers
│   │   ├── TTSController.swift             # Speech orchestrator & word synchronization
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
- **Background Audio in Simulator**:
  - The iOS Simulator routes audio through macOS CoreAudio. Using the native speech synthesis fallback avoids HALC proxy buffer issues.

---

## License

Personal accessibility open-source project. Free for all users.
