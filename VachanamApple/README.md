# Vachanam for Apple (iPadOS & Mac Catalyst)

[![Platform: iPadOS 18.0+](https://img.shields.io/badge/Platform-iPadOS%2018.0+-blue.svg?style=flat-square)](https://apple.com)
[![Platform: macOS 15.0+ (Catalyst)](https://img.shields.io/badge/Platform-macOS%2015.0+%20Catalyst-lightgrey.svg?style=flat-square)](https://apple.com)
[![Swift 5.0](https://img.shields.io/badge/Swift-5.0-orange.svg?style=flat-square)](https://swift.org)
[![Xcode 16.0+](https://img.shields.io/badge/Xcode-16.0+-darkblue.svg?style=flat-square)](https://developer.apple.com/xcode)

**Vachanam** is an accessibility-first, high-performance universal document reader and text-to-speech (TTS) studio designed specifically for **iPadOS** and **macOS (via Mac Catalyst)**. It pairs a **3-Layer Reader Engine** (Layout, Semantics, and Audio Synchronization) with an on-device Kokoro CoreML neural voice model, spatial Apple Pencil annotations, and ambient focus soundscapes.

---

## Key Features

### 📖 Multi-Format Universal Reader
- **PDF**: Spatial word-level bounding box tracking with Quartz 2D coordinate transformation math.
- **EPUB**: Streaming ZIP parsing with OPF manifest/spine resolution and $O(1)$ case-insensitive hash lookups.
- **Markdown & Plain Text**: ATX/Setext heading parsing, lists, blockquotes, and multi-encoding fallback cascade (`UTF-8` $\to$ `ISO-8859-1` $\to$ `Windows-1252` $\to$ `UTF-16` $\to$ `ASCII`).
- **Web Articles**: In-app web article import with boilerplate extraction and entity decoding.
- **Virtual Pagination**: 120 FPS `LazyVStack` windowing ensuring instant scrolling across 10,000+ paragraph documents.

### ✏️ iPadOS Apple Pencil & PencilKit Integration (`iOS/`)
- Continuous spatial canvas overlay for seamless Apple Pencil note-taking.
- Floating annotation toolbar with Pen, Highlighter, Eraser, and Shape tools.
- Sticky notes, text boxes, and full undo/redo stack.
- Annotation export engine for sharing annotated study documents.

### 🎙️ macOS Audiobook Studio (`macOS/`)
- Multi-chapter batch synthesis with per-character/speaker voice assignment.
- Manifest generation and export to structured audiobook audio files.
- Full Catalyst menu bar commands (`File`, `Edit`, `Speech`, `View`, `Window`).
- Developer diagnostics HUD and speech telemetry sandbox.

### 🧠 On-Device Neural TTS & Mathematical Grammar
- On-device CoreML & MLX Kokoro 82M neural speech synthesis.
- Fallback to Apple's native `AVSpeechSynthesizer`.
- Automatic translation of complex LaTeX, exponents ($10^{23}$, $x^2$), scientific notation (`6.022e23`), and SI units (`5 nm`, `2.4 GHz`).
- Real-time karaoke-style word highlighting synced to the audio waveform.

### 🎧 Ambient Focus Soundscapes
- 5 bundled acoustic focus loops: **Brown Noise**, **Pink Noise**, **40Hz Binaural Beats**, **Soft Rain**, and **Library & Café**.
- Independent background volume slider with smooth crossfade and sleep timer.

### ♿ Accessibility First
- **OpenDyslexic Typography**: Bundled OpenDyslexic Regular and Bold fonts.
- **Bionic Reading Mode**: Fixation character bolding.
- **Dyslexia Reading Ruler**: Draggable reading guide with adjustable window height.
- **5 Theme Palettes**: Cream, Sepia, Dark Slate, OLED Black, and Paper White.

---

## Directory Structure

```
VachanamApple/
├── Shared/                     # Universal multi-platform engine (iOS & macOS)
│   ├── App/                    # VachanamApp, AppState, scene delegates
│   ├── Document/               # Semantic models, parsers (PDF, EPUB, MD, TXT, Web), text engines
│   ├── TTS/                    # Kokoro CoreML engine, speech chunker, pronunciations
│   ├── Audio/                  # Ambient focus soundscapes player, background acoustics
│   ├── Accessibility/          # Dynamic Type scaling, OpenDyslexic typography, tracking
│   ├── Adapters/               # Pluggable TTS protocols & system fallbacks
│   ├── PDF/                    # PDFKit coordinate math, Quartz 2D geometry engines
│   └── Views/                  # Shared SwiftUI & UIKit reader/library/scrubber views
├── iOS/                        # iOS & iPadOS specialized capabilities
│   ├── Annotations/            # PencilKit AnnotationManager & undo/redo stack
│   └── Views/Annotations/      # Apple Pencil canvas overlay, floating toolbar, shape tools
├── macOS/                      # macOS / Mac Catalyst specialized capabilities
│   ├── Studio/                 # Multi-speaker audiobook generator & manifest export
│   ├── Navigation/             # Catalyst menu bar commands & keyboard shortcuts sheet
│   └── Developer/              # Diagnostics overlay & telemetry HUD
├── Tests/                      # Swift unit test suites (TTSTests, PDFTests, AnnotationTests)
├── UITests/                    # Automated UI integration tests
├── Packages/                   # Kokoro CoreML local Swift package
├── Resources/                  # Assets, AppIcon, Kokoro CoreML weights, test PDFs
├── Info.plist                  # Target property list
├── Vachanam.entitlements       # App sandbox and file access entitlements
├── Vachanam.xcodeproj/         # Xcode project package
└── generate_project.py         # Xcode project generator & synchronizer
```

---

## How to Build & Run

### Prerequisites
- macOS Sonoma 14.0+ (macOS Sequoia 15.0+ recommended)
- Xcode 16.0+ (with iOS 18.0+ SDK)
- Apple Silicon Mac (M1/M2/M3/M4) or iPad Air/Pro

### 1. Project Generation & Synchronization
`Vachanam.xcodeproj` is programmatically generated and kept synchronized:
```bash
python3 generate_project.py
```

### 2. Running on Mac (Mac Catalyst)
```bash
# Build
xcodebuild -project Vachanam.xcodeproj -scheme Vachanam -destination 'platform=macOS,variant=Mac Catalyst' -quiet build

# Run Unit Tests
xcodebuild -project Vachanam.xcodeproj -scheme Vachanam -destination 'platform=macOS,variant=Mac Catalyst' -only-testing:VachanamTests -quiet test
```

### 3. Running on iPad Simulator
```bash
# Build
xcodebuild -project Vachanam.xcodeproj -scheme Vachanam -destination 'platform=iOS Simulator,name=iPad Air 11-inch (M4)' -quiet build

# Run Unit Tests
xcodebuild -project Vachanam.xcodeproj -scheme Vachanam -destination 'platform=iOS Simulator,name=iPad Air 11-inch (M4)' -only-testing:VachanamTests -quiet test
```

---

## Keyboard Shortcuts (macOS & iPad Smart Keyboard)

| Key | Action |
| :--- | :--- |
| **Space** | Play / Pause speech |
| **Cmd + Right Arrow** | Skip forward 1 sentence |
| **Cmd + Left Arrow** | Skip backward 1 sentence |
| **Right Arrow** | Next page |
| **Left Arrow** | Previous page |
| **Cmd + B** | Toggle bookmark on current page |
| **Cmd + T** | Toggle Table of Contents sidebar |
| **Cmd + D** | Cycle reading theme (Sepia, Dark, Cream, OLED, White) |
| **Cmd + =** / **Cmd + -** | Increase / Decrease font size |
| **Cmd + 0** | Reset font size to default |
| **Cmd + Shift + R** | Toggle Dyslexia Reading Ruler |
| **Cmd + Shift + B** | Toggle Bionic Reading mode |
| **Cmd + ?** | Open Keyboard Shortcuts cheat sheet |
