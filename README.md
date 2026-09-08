# Vachanam (ವಚನಮ್)

**An accessibility-focused PDF reader with on-device TTS, word/sentence highlighting, and full annotation tools for iPad & Mac (Apple Silicon).**

---

## Overview

**Vachanam** is engineered specifically for readers with dyslexia, visual impairments, reading fatigue, or cognitive processing differences. It bridges the gap between structured academic documents and fluid digital reading by pairing native PDF viewing with an extracted distraction-free **Reader View**, powered by a pluggable on-device **Neural Text-to-Speech (TTS)** engine.

As documents are narrated, Vachanam synchronizes **word-by-word karaoke highlighting** alongside **sentence-level background bands**, smooth auto-scrolling, a dyslexia reading ruler guide, and a full Apple Pencil annotation suite.

---

## Key Highlights

- **5 On-Device TTS Models**:
  1. **Apple Natural** (Built-in offline iOS speech synthesis, zero download)
  2. **Kokoro 82M** (Default, lightweight, ultra-fast English narration, runs on 4GB+ RAM devices)
  3. **Qwen3-TTS 0.6B** (High fidelity, expressive prosody, native word timestamps, requires 8GB+ RAM)
  4. **Chatterbox Turbo** (Emotion markup like `[laugh]`, `[sigh]`, requires 8GB+ RAM)
  5. **CosyVoice 3 0.5B** (4-bit quantized MLX streaming synthesis, requires 8GB+ RAM)
- **3-Layer Document & Performance Architecture**:
  - **Layer 1 (PDF Layout)**: PDFKit coordinate rendering with precise word bounding boxes and multi-line highlights.
  - **Layer 2 (Semantic Text)**: `WordReconstructor` automatically joins hyphenated line breaks (`probabil-` + `ity` $\to$ `probability`) while preserving compound words (`well-known`). `ParagraphDetector` and `SentenceSegmenter` reconstruct natural linguistic flow with semantic block recognition (`BlockType.heading`, `listItem`, `paragraph`, `quote`).
  - **Layer 3 (Audio Timeline)**: Speech is synthesized in ~10–25 word (1–2 sentence) semantic chunks tuned to Kokoro's fixed 128-token duration limit, preventing multi-pass recursive splitting and guaranteeing sub-2s initial inference latency.
- **Semantic Block Segmentation & Boundary Isolation**:
  - Distinguishes structural block types (`BlockType.heading`, `listItem`, `paragraph`, `quote`) based on font height, short word count, regex prefixes, and typography.
  - Headings and list items are strictly preserved as standalone TTS chunks to prevent awkward concatenation into adjacent paragraphs.
- **Natural Boundary Pauses**:
  - Injects tailored trailing silence PCM buffers directly into chunk audio (0.6s after headings, 0.4s after list items, 0.5s after paragraphs).
  - Gives the narrator natural acoustic breathing room and keeps visual focus on the final spoken word during pauses without UI jitter.
- **Advanced Symbol-to-Speech & Math Normalization**:
  - `TextNormalizer.normalizeForSpeech` converts mathematical operators (`×` $\to$ `times`, `÷` $\to$ `divided by`, `≠` $\to$ `is not equal to`, `≤`, `≥`, `≈`, `∞`), vulgar fractions (`½` $\to$ `one half`, `¼` $\to$ `one quarter`), currencies (`$100` $\to$ `100 dollars`, `€`, `£`, `¥`), percentages (`25%` $\to$ `25 percent`), plus-minus (`±5` $\to$ `plus or minus 5`), temperatures and angles (`100°C` $\to$ `100 degrees Celsius`, `72°F` $\to$ `72 degrees Fahrenheit`, `90°` $\to$ `90 degrees`), and ampersands (`&` $\to$ `and`) into fluent speech while preserving sentence punctuation.
  - Automatically strips visual bullet ornaments (`•`, `◦`, `▪`, `▫`, `●`, `■`, `◆`, `❖`, `★`, `☆`, `►`, `▻`, `➢`, `✓`, `✔`) and leading list hyphens/asterisks (`- `, `* `) so that visual layout glyphs are never spoken awkwardly or indexed as phantom audio words.
- **Layered Pronunciation Dictionary System (`PronunciationManager`)**:
  - Three-tier hierarchy: **Global** (common acronyms & phonetics), **Book-specific** (character names, domain terminology), and **User overrides** (custom fixes).
  - Employs case-insensitive word-boundary regex substitution (`\b(word)\b`) and revision hashing for automatic audio cache invalidation.
- **Interactive Pronunciation Correction (`FixPronunciationSheet`)**:
  - Accessible directly from the TTS Control Bar (`Fix Pronunciation` button) or context menu.
  - Allows users to enter phonetic respellings with instant speech preview and automatic cache purging.
- **Monotonic Highlighting Clock & Compound Word Alignment**:
  - **Strict 1:1 `targetWords` Contract**: Passes segmented document `SemanticWord` tokens (split via `NLTokenizer`) directly to the TTS adapter (`KokoroAdapter.synthesize(..., targetWords:)`). Compound words like `Word-by-word`, `on-device`, and `distraction-free` receive distinct, individual word timestamps that match their precise PDF bounding boxes, completely eliminating index shifts.
  - **Inter-Word Gap Holding**: In-flight binary search smoothly holds the preceding word's highlight during acoustic gaps rather than jumping back to the beginning of the chunk.
  - **Calibrated Drift Telemetry**: Accurately measures audio drift outside actual word time intervals `[startTime, endTime]`, logging warnings only when true timing desynchronization (>150ms) occurs.
- **Stable Global Word Indexing (`globalWordID`)**: Every word receives a persistent, monotonic global identity across the entire document. Navigating between pages or selecting words on different pages never gets stuck or invalidates position.
- **Tap-to-Speak**: Tap any word directly on the PDF page or in Reader View to immediately begin narration from that word. Obsolete in-flight synthesis tasks are cancelled instantly with zero delay.
- **Rolling TTS Pre-Generation & Content-Hashed Cache**: While Chunk $N$ plays, Chunk $N+1$ is pre-generated in the background without CPU/Core ML contention and stored in a non-blocking two-tier in-memory/disk cache (`TTSAudioCache`). Instant, gapless playback on chunk transitions and repeated visits without Swift Concurrency thread blocking.
- **Stage-by-Stage Profiling & Telemetry**: `TTSMetricsLogger` exposes timing metrics for text processing, Misaki phonemization, Core ML model inference, and audio post-processing alongside the Real-Time Factor (RTF).
- **Model Lifecycle & Pre-Warming**: Kokoro Core ML models remain alive in memory and are pre-warmed upon initialization to avoid cold-start compilation stutter when the user presses Play.
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
│   │   │   ├── TTSControlBar.swift         # Play/pause, speed, voice picker, sleep timer, fix pronunciation
│   │   │   ├── VoicePickerView.swift       # Voice selection and model picker sheet
│   │   │   ├── FixPronunciationSheet.swift # Phonetic dictionary override modal with audio preview
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
│   │   ├── PlaybackCoordinator.swift       # Authoritative cursor, scope boundary & task token manager
│   │   ├── PronunciationManager.swift      # 3-tier dictionary (Global/Book/User), regex replacement & revision hashes
│   │   ├── TTSModelProtocol.swift          # Pluggable model interface, audio results & TTSError
│   │   ├── TTSModelInfo.swift              # Model metadata, formats, tiers
│   │   ├── TTSController.swift             # Speech orchestrator, lifecycle & rolling pre-generator
│   │   ├── TTSMetricsLogger.swift          # Stage-by-stage profiling & telemetry
│   │   ├── VoiceProfileResolver.swift      # Model voice presets & pitch/rate mapping
│   │   ├── ModelManager.swift              # Model downloader, disk cache, delete
│   │   ├── ModelRegistry.swift             # Model catalog loader
│   │   └── DeviceCapability.swift          # Hardware RAM checker & tier filters
│   │
│   ├── Adapters/
│   │   ├── KokoroAdapter.swift             # Kokoro 82M CoreML adapter with stage telemetry
│   │   ├── Qwen3TTSAdapter.swift           # Qwen3-TTS 0.6B CoreML adapter
│   │   ├── ChatterboxAdapter.swift         # Chatterbox Turbo CoreML adapter
│   │   ├── CosyVoice3Adapter.swift         # CosyVoice 3 0.5B MLX adapter
│   │   └── G2P/
│   │       ├── G2PProtocol.swift           # Phonemizer protocol
│   │       └── MisakiG2P.swift             # Misaki English phonemizer
│   │
│   ├── Document/
│   │   ├── SemanticDocument.swift          # Complete 3-layer document model & fast lookups
│   │   ├── WordReconstructor.swift         # Line-break hyphen joining & compound word preservation
│   │   ├── TextNormalizer.swift            # Whitespace, ligature, and symbol-to-speech cleaner
│   │   ├── ParagraphDetector.swift         # Visual line clustering & semantic block detector
│   │   ├── SentenceSegmenter.swift         # NLTokenizer sentence & word bounding box parser
│   │   └── TTSChunker.swift                # 10-25 word semantic chunk generator with boundary pauses
│   │
│   ├── Audio/
│   │   ├── AudioPlayer.swift               # AVAudioEngine streaming player
│   │   ├── AudioSession.swift              # Background audio & MPRemoteCommandCenter
│   │   ├── TTSAudioCache.swift             # Content-hashed two-tier audio cache
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
│   │   ├── DeviceCapabilityTests.swift     # RAM tier compatibility tests
│   │   ├── TTSAudioCacheTests.swift        # Content-hashed cache tests
│   │   ├── PlaybackCoordinatorTests.swift  # Task cancellation & word jump tests
│   │   ├── PronunciationManagerTests.swift # 3-tier dictionary & regex word-boundary tests
│   │   └── TTSChunkerQualityTests.swift    # Block isolation & trailing pause assignment tests
│   ├── PDFTests/
│   │   ├── TextExtractorTests.swift        # Sentence tokenization & word rect tests
│   │   ├── WordReconstructorTests.swift    # Hyphen reconstruction & compounds tests
│   │   ├── TextNormalizerTests.swift       # Whitespace & ligature tests
│   │   ├── TextNormalizerExtendedTests.swift # Math, currency, temperature, fraction speech conversion tests
│   │   ├── SemanticBlockTests.swift        # Heading, list item, quote, and paragraph classification tests
│   │   ├── SemanticDocumentTests.swift     # GlobalWordID & chunking tests
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
| **Apple Natural** | 0 MB | 0 GB | Built-in AVSpeech | Zero-download, fast, default system fallback |
| **Kokoro** | ~164 MB (Bundled) | 4 GB | CoreML (KokoroTTS + Misaki) | All iPads (Air M-series & older) & Mac, long-form reading |
| **Qwen3-TTS** | ~2.5 GB | 8 GB | CoreML | High quality narration, native word alignment |
| **Chatterbox** | ~1.5 GB | 8 GB | CoreML | Emotion markup (`[laugh]`, `[sigh]`), character voices |
| **CosyVoice 3**| ~1.2 GB | 8 GB | MLX (4-bit quantized) | Streaming narration, voice cloning |

*Note: Devices with less than 8GB RAM will automatically indicate that heavier models require 8GB+ unified memory.*

---

## Kokoro CoreML Integration & Model Bundle

### Model Provenance & Upstream
- **Upstream Repository**: Built from [mattmireles/kokoro-coreml](https://huggingface.co/mattmireles/kokoro-coreml).
- **Embedded Swift Package**: Located in `Vachanam/Packages/kokoro-coreml` (~7.8 MB), providing the `KokoroTTS` runtime and pipeline.
- **Bundled Starter Runtime (`Vachanam/Resources/KokoroModels/`)**:
  To provide immediate offline neural speech without requiring initial network downloads, Vachanam bundles a complete starter Kokoro CoreML runtime (~185 MB):
  - `coreml/kokoro_duration_pre_15s.mlpackage`
  - `coreml/kokoro_style_encoder.mlpackage`
  - `coreml/kokoro_decoder_pre_15s.mlpackage`
  - `voices/` (`af_bella.bin`, `af_sarah.bin`, `am_adam.bin`, `am_michael.bin`)
  - `runtime/` (`kokoro-vocab.json` & `hnsf_weights.json`)
  - Pronunciation dictionaries: `us_gold.json`, `us_silver.json`, `gb_gold.json`, `gb_silver.json`

### Simulator & Device Compatibility
- **CoreML Model Execution**: CoreML models run natively on Apple Silicon GPU/ANE on physical devices and on the host Mac CPU/GPU under the iOS Simulator.
- **Simulator-Safe Phonemizer**: When executing inside Apple's iOS Simulator (`#if targetEnvironment(simulator)`), `KokoroMisakiPhonemizer` utilizes an in-memory dictionary-backed phonemizer to bypass MLX shared Metal heap assertions (`MTLStorageModePrivate is required for heaps`), ensuring tests and synthesis execute without simulator crashes. On physical iOS devices, full neural G2P is enabled.

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
- **Build Notice: "warning: not stripping binary because it is signed: .../MisakiSwift.framework"**:
  - Emitted by Xcode's `strip-tool` during copy phase when building signed Swift packages or dynamic frameworks in Debug. Stripping would alter binary bytes and break the cryptographic code signature, so Xcode safely preserves the symbols. `COPY_PHASE_STRIP = NO` is enforced across all debug configurations in `generate_project.py`.
- **Console Log: "AddInstanceForFactory: No factory registered for id <CFUUID ...> F8BB1C28-BAE8-11D6-9C31-00039315CD46"**:
  - This is an internal CoreAudio Hardware Abstraction Layer (HAL) diagnostic emitted by macOS when initializing virtual audio devices in the iOS Simulator.
  - It is completely harmless, expected in simulator environments, and has no effect on audio playback, synthesis, or stability. On physical iPad hardware, this log does not appear.
- **Console Log: "Failed to send CA Event for app launch measurements for ca_event_type: ..."**:
  - Emitted by Apple's internal `CoreAnalytics` daemon (`com.apple.app_launch_measurement`) because virtual iOS Simulators do not run the hardware telemetry subsystem used to send performance analytics to Apple servers. It is purely cosmetic and expected on all simulator targets.
- **Console Log: "Unable to get ISSymbol for UTI: com.apple.ios-simulator Error..."**:
  - Emitted by macOS's `IconServices` daemon when Xcode launches a process in the simulator and attempts to resolve a macOS system icon for the virtual simulator UTI.
  - This is a known macOS/Xcode cosmetic log. It has zero impact on app execution, UI rendering, or functionality, and does not occur on physical devices.
- **Simulator Container UUID Changes & Sample Guide**:
  - iOS Simulator reinstallation generates new sandbox container UUIDs. Vachanam dynamically resolves document filenames in the persistent `Documents` directory and auto-regenerates the multi-page `Vachanam_Getting_Started.pdf` guide if a previous container's temporary path was stored.
- **Console Log: "LoudnessManager.mm: ... cannot get acoustic ID" & "AVAudioBuffer.mm: mBuffers[0].mDataByteSize (0)"**:
  - Emitted internally by Apple's CoreAudio / AVSpeechSynthesis subsystem in simulator environments because the virtual simulator device does not possess physical hardware speaker acoustic calibration profiles (`LoudnessManager plist`). It is completely benign and does not occur on physical iPad/Mac hardware.
- **Console Log: "Potential Structural Swift Concurrency Issue: unsafeForcedSync called from Swift Concurrent context"**:
  - Emitted internally by Apple's AVFoundation speech synthesis C++ subsystem when bridging synchronous CoreAudio callbacks into Swift concurrency tasks. It is an internal Apple OS implementation detail and requires no action from user applications.
- **Console Log: "Error fetching voices: DecodingError.dataCorrupted" & "Error fetching locales"**:
  - Emitted by Apple's internal system voice catalog parser on macOS Sequoia / iOS 18 Simulator when querying `AVSpeechSynthesisVoice.speechVoices()`. `VoiceProfileResolver` caches voices at startup to prevent redundant disk queries on every spoken sentence.
- **Console Log: "EspressoModelWrapper::initialize Cannot create MPS context, fallback to CPU"**:
  - Emitted by Apple's `Espresso` CoreML neural inference engine when running inside the iOS Simulator. The simulator does not expose Apple Neural Engine (ANE) or Metal Performance Shaders (MPS) to guest virtual machines, so CoreML automatically falls back to CPU execution. On physical iPad/Mac hardware with Apple Silicon, models run with full GPU and Neural Engine acceleration.
- **Console Log: "HALC_ProxyIOContext::IOWorkLoop: skipping cycle due to overload"**:
  - An internal CoreAudio warning emitted when the macOS host audio daemon detects high virtual CPU contention while synthesizing neural speech buffers. It does not occur on real hardware due to dedicated audio DSP hardware.
- **Console Log: "retrieving stroke identifier gave nil or invalid result... Unable to find stroke from stroke group"**:
  - Emitted internally by Apple's `PencilKit` framework when drawing or erasing on the iOS Simulator using mouse/trackpad pointer events instead of a physical Apple Pencil digitizer. It has zero impact on annotation persistence or drawing fidelity.
- **Console Log: "CoreGraphics PDF has logged an error..."**:
  - Emitted by Apple's CoreGraphics PDFKit rendering subsystem when parsing non-standard font dictionaries or PDF operator streams. Highlighting and page display remain unaffected.
- **Console Log: "connection to service named com.apple.linkd.autoShortcut"**:
  - Emitted by macOS's `AppIntents` system framework on Mac Catalyst when running outside an App Store sandbox or Shortcuts daemon registration. It is purely cosmetic and has zero effect on app execution, playback, or performance.
- **Console Log: "open(/private/var/db/DetachedSignatures) - No such file or directory"**:
  - Emitted by macOS `libsqlite3` and security subsystems querying detached code signatures for local debug builds. Harmless diagnostic with zero impact on functionality.
- **Console Log: "cannot add handler to 4 from 1 - dropping"**:
  - Emitted internally by macOS `QuartzCore` (CoreAnimation) in Mac Catalyst during window display refresh cycle registrations. Benign OS compositor notification.
- **Linker Warning: "search path '/var/run/.../MetalToolchain.../maccatalyst' not found"**:
  - Xcode 16 passes its system Metal compiler toolchain directory by default, which contains a `macosx` architecture folder but no separate `maccatalyst` directory on the system volume. The linker safely falls back to standard framework search paths and builds cleanly.
- **SwiftUI View Update Cycle Prevention**:
  - **`CanvasOverlay`**: Guarded `PKCanvasViewDelegate.canvasViewDrawingDidChange` with `isProgrammaticUpdate` and deduplication against `lastSavedData`. Dispatches drawing data persistence to `AnnotationManager` asynchronously via `DispatchQueue.main.async`, preventing UIKit delegate drawing events from publishing `@Published` changes synchronously during SwiftUI's `makeUIView` or `updateUIView` layout passes.
  - **`DocumentLibraryView`**: `resolveDocumentURL(for:)` is implemented as a pure, side-effect-free query function without mutating `ReadingProgressTracker.history` during `ForEach` body evaluations. Persistent document path reconciliation runs asynchronously on `.onAppear` and on card tap selection, eliminating `AttributeInvalidatingSubscriber` warnings in `ForEachState`.
  - **`PDFReaderView`**: Removed redundant highlight calls from `updateUIView`, relying solely on the coordinator's reactive observers (`$isPlaying`, `$currentSentence`, page change notifications) so the SwiftUI layout pass never mutates observable state.
  - **`ReaderContainerView` & `ReadingRuler`**: Decoupled `TTSController` observation from `ReaderContainerView` directly into `ReadingRuler`, preventing whole-container re-renders on word-level speech ticks. Unused `currentWordViewRect` tracking has also been purged.
- **Xcode "Validate Project Settings" / Recommended Settings**:
  - `generate_project.py` embeds Xcode's complete suite of modern recommended build settings across both Project and Target levels (`LastUpgradeCheck = 1600;`, `ENABLE_USER_SCRIPT_SANDBOXING = YES`, `STRING_CATALOG_GENERATE_SYMBOLS = YES`, `LOCALIZATION_PREFERS_STRING_CATALOGS = YES`, `SWIFT_COMPILATION_MODE = wholemodule` for Release, `ONLY_ACTIVE_ARCH = YES` for Debug, full recommended Clang/GCC compiler warnings, and automatic asset/string catalog symbol generation). This completely prevents Xcode from displaying the "Validate Project Settings" / "Update to recommended settings" prompt upon opening the project.

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

## Playback Coordinator, Scope Enforcement & Synchronization Architecture

Vachanam implements a unified synchronization and playback architecture structured around the principle:
> **PDF lines are for rendering. Sentences are for TTS. Words are for synchronization. Playback uses one authoritative global cursor.**

```
                     ┌──────────────────┐
                     │    PDF / EPUB    │
                     └────────┬─────────┘
                              │
                    ┌─────────┴─────────┐
                    │                   │
                    ↓                   ↓
              PDF Layout          Semantic Parser
                    │                   │
              pages/lines/boxes    paragraphs
                    │                   │
                    │                sentences
                    │                   │
                    │                words
                    │                   │
                    │              globalWordID
                    │                   │
                    │               TTS chunks
                    │                   │
                    │                   ↓
                    │              Kokoro CoreML
                    │                   │
                    │              word timings
                    │                   │
                    └──────────┬────────┘
                               ↓
                      PlaybackCoordinator
                               │
                     ┌─────────┴─────────┐
                     ↓                   ↓
                Audio Player        Word Sync
                                         │
                                   globalWordID
                                         │
                                         ↓
                                   PDF Highlighter
                                         │
                                         ↓
                                    RED WORD
```

### Core Architecture Components

1. **`PlaybackCursor`**:
   - Single authoritative position tracker: `documentID`, `pageIndex`, `paragraphIndex`, `sentenceIndex`, `wordIndex`, and `globalWordID`.
2. **`PlaybackScope`**:
   - Explicit playback boundaries:
     - `.document`: Sequential playback across pages until the final chunk of the last page, then strictly **STOP**. Eliminates infinite wrapping to page 0.
     - `.page(p)`: Strict hard boundary on page `p`. Automatically stops when the last word of page `p` finishes without advancing to page `p + 1` or looping.
     - `.selection([wordIDs])`: Target playback for specific selections.
3. **Decoupled Visible Page from Playback Page**:
   - `visiblePageIndex` tracks where the user is looking.
   - When the user presses Play while viewing page 8, `PlaybackCoordinator` resolves the first playable word on page 8 rather than resetting to page 1.
4. **Cancellation Tokens (`currentRequestID: UUID`)**:
   - Tapping any word generates a new `requestID = UUID()`, cancels prior in-flight synthesis and prefetch tasks, sets the cursor immediately, seeks the audio to the selected word, and discards any stale asynchronous synthesis results.
5. **Accurate Word Highlighting**:
   - Audio playback position translates directly from `TTSAudioResult.wordTimestamps` into `globalWordID` -> `SemanticWord.bounds` -> `CALayer` red rectangle in `PDFHighlightOverlayView`, eliminating line-wrapping offset drifts and ligature misalignments.

---

## Kokoro Reader Quality & Pronunciation Architecture

To transform raw on-device neural TTS into a studio-grade listening experience, Vachanam implements a six-pillar reader quality system:

### 1. Semantic Block Segmentation (`BlockType`)
Standard sentence extraction often treats headings and bullet lists as ordinary continuous prose, causing the narrator to run section titles into following paragraphs without a pause.
- `ParagraphDetector` classifies lines into distinct structural blocks (`BlockType.heading`, `listItem`, `paragraph`, `quote`):
  - **Headings**: Detected via regex (`Chapter \d+`, `Section \d+`, numbered headers `1.2`), typography (line height $\ge 1.25\times$ body median height), word counts ($\le 12$ words), and absent terminal punctuation (`.`, `!`, `?`).
  - **List Items**: Detected via bullet characters (`•`, `-`, `*`, `–`, `—`, `\u{2022}`) or numbered patterns (`1.`, `(a)`, `i.`). Subsequent wrapped lines indented beyond the list bullet are consolidated into the same list item block.
  - **Quotes & Paragraphs**: Detected via indentation, quotation marks, and line clustering.
- Every `SemanticSentence` carries `blockID` and `blockType`, linked to `SemanticDocument.blocks`.

### 2. Boundary & Natural Pause Architecture
- **Boundary Isolation**: `TTSChunker` enforces that `heading` and `listItem` blocks are generated as isolated, dedicated speech chunks. A heading is never merged into the first sentence of the following paragraph.
- **Natural PCM Silence Insertion**: In everyday human speech, a speaker naturally pauses between paragraphs and headings. Rather than introducing artificial timer delays in the audio playback engine (which cause stutter and audio engine restarts), Vachanam appends silent Float32 PCM samples directly to synthesized `TTSAudioResult` buffers via `withAppendedSilence(duration:)`:
  - **Headings**: 0.6 seconds trailing silence.
  - **List Items**: 0.4 seconds trailing silence.
  - **Paragraph Endings**: 0.5 seconds trailing silence.
- **Stable Highlighting**: During trailing pauses, the playback cursor remains anchored on the final spoken word until the subsequent chunk begins, eliminating visual flicker or premature highlight disappearance.

### 3. Text & Symbol Normalization Pipeline (`normalizeForSpeech`)
Kokoro's acoustic model was trained on phonetic text; raw math and financial symbols either get skipped or spelled out inconsistently. `TextNormalizer.normalizeForSpeech` performs preprocessing before synthesis:
- **Currencies**: Converts `$100` $\to$ `100 dollars`, `€50.25` $\to$ `50.25 euros`, `£20` $\to$ `20 pounds`, `¥1000` $\to$ `1000 yen`.
- **Percentages & Variations**: Converts `25%` $\to$ `25 percent`, `±5` $\to$ `plus or minus 5`.
- **Temperatures & Angles**: Converts `100°C` $\to$ `100 degrees Celsius`, `72°F` $\to$ `72 degrees Fahrenheit`, `90°` $\to$ `90 degrees`.
- **Vulgar Fractions**: Converts Unicode fractions (`½` $\to$ `one half`, `¼` $\to$ `one quarter`, `¾` $\to$ `three quarters`, `⅓` $\to$ `one third`, `⅔` $\to$ `two thirds`, `⅛` $\to$ `one eighth`).
- **Mathematical Operators**: Converts `×` $\to$ `times`, `÷` $\to$ `divided by`, `≠` $\to$ `is not equal to`, `≤` $\to$ `less than or equal to`, `≥` $\to$ `greater than or equal to`, `≈` $\to$ `approximately`, `∞` $\to$ `infinity`.
- **Ampersands**: Converts `&` $\to$ `and`.
- **Punctuation Integrity**: Standard sentence punctuation (`.`, `,`, `!`, `?`, `;`, `:`) is preserved to maintain Kokoro's expressive prosody and pitch contours.

### 4. Layered Pronunciation Dictionary (`PronunciationManager`)
Names, domain-specific medical/legal jargon, and acronyms often require custom phonetic respelling.
- **Three-Tier Architecture**:
  1. **Global Dictionary**: Built-in rules for common acronyms and technical terms.
  2. **Book Dictionary**: Scoped per document ID for fiction characters, foreign names, and localized terminology.
  3. **User Overrides**: User-configured overrides that take highest precedence across documents.
- **Case-Insensitive Word-Boundary Substitution**: Words are replaced using regex `\b(pattern)\b` so substrings (e.g. `cat` inside `caterpillar`) are protected from accidental mutation.
- **Revision Hashing & Cache Invalidation**: Every dictionary mutation increments an internal revision hash. `TTSAudioCache.makeKey` incorporates this revision, automatically invalidating stale audio chunks so corrected pronunciations take effect immediately.

### 5. Interactive Pronunciation Correction UI (`FixPronunciationSheet`)
- Direct access via the **"Fix Pronunciation"** button in `TTSControlBar` (and accessible per-word from Reader View).
- Pre-populates with the currently active or highlighted word.
- Users can test adjustments instantly with an in-sheet **"Preview Audio"** button using Kokoro or the active voice profile.
- Saving automatically purges stale audio cache keys and re-synthesizes the active chunk.

### 6. Sub-150ms Drift Telemetry & Highlighting Synchronization
- High-frequency monotonic audio clock tracking (`AVAudioPlayer.currentTime`) maps against Kokoro's millisecond-accurate `wordTimestamps` using binary search.
- During trailing silence pauses, the cursor rests smoothly on the final spoken token.
- `PlaybackCoordinator` monitors time delta between audio clock and token boundary; if synchronization drift exceeds **150ms**, diagnostic telemetry emits a structured warning to ensure rock-solid accessibility highlighting.

---

## Runtime Diagnostics & Telemetry Reference (macOS & iPad Simulator)

When executing in the iPad simulator or natively on macOS (Mac Catalyst):

1. **Neural Performance Telemetry (`TTS Profiler`)**:
   - On Apple Silicon MacBooks (M-series), Kokoro neural inference achieves an outstanding **Real-Time Factor (RTF) of 0.22x – 0.45x** (synthesizing speech **2.2x to 4.5x faster than real-time playback**).
   - Core ML model inference takes ~1.5s–4.3s per multi-sentence chunk, with Misaki phonemization settling under 4ms after warm-up and audio post-processing under 25ms.
2. **Bundled Neural Voice Manifest (`KokoroRuntimeManifest.json`)**:
   - The starter neural bundle includes 7 voice embedding binaries in `voices/`: `af_heart`, `af_bella`, `af_nicole`, `am_fenrir`, `am_michael`, `am_puck`, and `bf_emma`.
   - `KokoroRuntimeManifest.json` contains exact SHA256 checksums and file lengths for all 7 voices, enabling neural synthesis across American and British English voice personalities without falling back to Apple TTS.
   - `KokoroAdapter` incorporates automatic in-engine fallback to `.afHeart` if an unbundled voice embedding is ever requested, eliminating runtime `unsupportedVoice` exceptions.
3. **`QuartzCore` / `cannot add handler to 4 from 1 - dropping` (Mac Catalyst)**:
   - Emitted by macOS WindowServer / CoreAnimation when Mac Catalyst UI panels (such as `NSOpenPanel` or modal sheets) transition focus. The AppKit-to-UIKit animation bridge drops redundant display link notification handlers; this is a benign internal system diagnostic.
4. **`AppIntents` / `connection to service named com.apple.linkd.autoShortcut`**:
   - Emitted on app launch when macOS queries the system Shortcuts daemon (`linkd`). Catalyst apps log this when Siri Shortcuts auto-registration completes for apps without predefined AppIntents.
5. **`MLX Metal Compiler Warnings` (`defines.h: unused variable`)**:
   - Emitted during JIT compilation of MLX Metal shaders for reduction and normalization kernels when optional constexpr dimensions are unused by a particular kernel specialization. All shaders compile successfully.
6. **`EspressoModelWrapper` / `MPS` Fallback (iPad Simulator)**:
   - `EspressoModelWrapper::initialize Cannot create MPS context, fallback to CPU` is an internal Apple `TextRecognition` framework diagnostic when running in the simulator without native Metal Performance Shader context. It automatically falls back to CPU without impacting text extraction.
7. **`LoudnessManager` / `HALC_ProxyIOContext` Overload (Simulator Audio)**:
   - Simulator CoreAudio proxy messages occur when host audio proxies desynchronize during system speech fallback. Keeping synthesis on the neural CoreML path with bundled voices resolves these proxy drops.
8. **`MetalToolchain` / `cryptexd` Linker Warning (Mac Catalyst)**:
   - `ld: warning: search path '/var/run/com.apple.security.cryptexd/mnt/.../Metal.xctoolchain/usr/lib/swift/maccatalyst' not found` is a known upstream Apple Clang / Xcode issue on macOS Sequoia when building Mac Catalyst. Xcode automatically injects the mounted Metal toolchain cryptex path into linker arguments. The linker safely bypasses the non-existent subdirectory and links against the macOS SDK libraries without issue.
9. **`AddInstanceForFactory` / `CoreAudio HAL Factory` (CoreFoundation / CFBundle)**:
   - `AddInstanceForFactory: No factory registered for id <CFUUID ...> F8BB1C28-BAE8-11D6-9C31-00039315CD46` is emitted by Apple's CoreAudio Hardware Abstraction Layer when discovering system audio hardware and AudioUnit driver plug-ins. It is standard Apple diagnostic logging and has zero impact on audio playback.
10. **`libsqlite3` / `open(/private/var/db/DetachedSignatures)`**:
    - Emitted by SQLite when initializing system caches. macOS queries the optional detached code signatures database, which does not exist on consumer macOS installations. SQLite safely continues.
11. **`AudioAnalytics` / `carc` / `Reporter disconnected`**:
    - Emitted by Apple's internal `AudioAnalytics` framework when local audio sessions initialize without transmitting usage analytics to Apple.
12. **`BaseBoard` / `Unable to obtain a task name port right`**:
    - Emitted by Apple's `BaseBoard` framework when verifying Mach port task rights across windowing processes within the sandboxed Mac Catalyst environment.

---

## Build & Run Guide (MacBook & iPad)

Vachanam supports native execution on Apple Silicon MacBooks (via Mac Catalyst) and iPad devices / simulators.

### 1. Project Generation
Whenever Swift source files or resources are added or modified:
```bash
python3 generate_project.py
```
This script generates modern Xcode project settings (`LastUpgradeCheck = 1600`) and automatic ad-hoc signing (`"CODE_SIGN_IDENTITY[sdk=macosx*]" = "-"`) so local builds run without developer team certificate friction.

### 2. Building & Testing for MacBook (Mac Catalyst)
To build and execute unit tests natively on your Apple Silicon Mac:
```bash
# Build Mac Catalyst target
xcodebuild -project Vachanam.xcodeproj -scheme Vachanam -destination 'platform=macOS,variant=Mac Catalyst' -quiet build

# Run unit test suite on macOS
xcodebuild -project Vachanam.xcodeproj -scheme Vachanam -destination 'platform=macOS,variant=Mac Catalyst' -quiet test
```
The compiled macOS app bundle will be placed in:
`~/Library/Developer/Xcode/DerivedData/Vachanam-*/Build/Products/Debug-maccatalyst/Vachanam.app`

### 3. Building & Testing for iPad Simulator
To build and run tests targeting the iPad simulator:
```bash
# Build for iPad simulator
xcodebuild -project Vachanam.xcodeproj -scheme Vachanam -destination 'platform=iOS Simulator,name=iPad Air 11-inch (M4)' -quiet build

# Run unit test suite on iPad simulator
xcodebuild -project Vachanam.xcodeproj -scheme Vachanam -destination 'platform=iOS Simulator,name=iPad Air 11-inch (M4)' -quiet test
```

---

## License

Personal accessibility open-source project. Free for all users.

