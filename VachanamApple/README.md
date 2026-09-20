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
- **EPUB**: Streaming ZIP parsing with OPF manifest/spine resolution, in-flow binary image extraction (`<img>` and `<image xlink:href>`), and $O(1)$ case-insensitive hash lookups.
- **Markdown & Plain Text**: ATX/Setext heading parsing, lists, blockquotes, inline/block image rendering (`![alt](url)`), and multi-encoding fallback cascade (`UTF-8` $\to$ `ISO-8859-1` $\to$ `Windows-1252` $\to$ `UTF-16` $\to$ `ASCII`).
- **Web Articles & Illustrated Books**: In-app web article import and responsive image flow preserving aspect ratios, rounded corners, subtle shadows, and italic captions.
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

### 📚 Apple Books Reading Experience & Library Intelligence

- **3-Mode Universal Reading Engine**: Seamlessly switch between **Single Page** (`.paginated`), **Two Pages** (`.twoPage` side-by-side book spread with center spine divider), and **Continuous** (`.continuous` vertical smooth scrolling) across all document formats (EPUB, PDF, Markdown, Plain Text, Web Articles).
- **Two-Page Book Spread Mode**: Immersive dual-column spread for iPad in landscape and macOS Mac Catalyst. Features running chapter header, dual-page indicator footer ("Pages X–Y of N"), edge-tap paging (`-2 / +2`), and automatic voice-following spread turns.
- **Dynamic PDF Theme Background**: Native PDF viewer (`pdfView.backgroundColor`) automatically binds to `themeManager.currentReaderTheme.backgroundColor`, ensuring Quiet, Paper, Charcoal, and Night themes maintain harmonious borders instead of glaring white margins.
- **Original PDF vs Clean Text Mode**: Toggle between original PDF fixed-layout rendering and reflowed clean text typography with dynamic font size, OpenDyslexic, bionic reading, and full 3-layout pagination.
- **Immersive Tap-to-Toggle Chrome**: Center tap smoothly fades top navigation bars and bottom TTS scrubbers for pure distraction-free reading; edge taps flip pages.
- **5 Apple Books Theme Palettes**: `Original` (adaptive system white/black), `Quiet` (warm eggshell), `Paper` (textured sepia), `Charcoal` (deep slate), and `Night` (true OLED black).
- **Library Shelves & Collections**: Organize books into built-in collections (`All`, `Reading`, `Favorites`, `Finished`) or custom user-defined shelves with horizontal category pills.
- **Complete Document Deletion**: Permanently delete documents with one tap, including local sandbox files, reading progress, and shelf associations.
- **Book Intelligence Preloading**: Async background preparation structures chapters, computes exact word counts, and estimates both silent reading duration (~225 wpm) and Kokoro TTS narration duration (~150 wpm).
- **Precision Resume Banner**: Instant toast upon reopening a book with one-tap inline `Play` to resume neural narration exactly where you stopped.

### ♿ Accessibility First

- **OpenDyslexic Typography**: Bundled OpenDyslexic Regular and Bold fonts.
- **Bionic Reading Mode**: Fixation character bolding.
- **Dyslexia Reading Ruler**: Draggable reading guide with adjustable window height.
- **Reading Layout Selector**: Switch between Single Page, Two Pages, and Continuous scroll directly inside the "Aa" Appearance menu, the reader top navigation bar, or Mac Catalyst keyboard shortcuts.

---

## Directory Structure

```text
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
| **Right Arrow** / **Down Arrow** | Next page |
| **Left Arrow** / **Up Arrow** | Previous page |
| **Space** | Next page (or scroll down in continuous view) |
| **Shift + Space** | Previous page (or scroll up in continuous view) |
| **Page Down** / **Page Up** | Screen down / Screen up |
| **Home** / **Cmd + Left Arrow** | First page |
| **End** / **Cmd + Right Arrow** | Last page |
| **[** / **Cmd + [** | Previous chapter / section |
| **]** / **Cmd + ]** | Next chapter / section |
| **c** | Cycle reading layout (Single Page $\to$ Two Pages $\to$ Continuous Scroll) |
| **t** | Cycle theme (Original $\to$ Quiet $\to$ Paper $\to$ Charcoal $\to$ Night) |
| **p** / **Opt + Space** | Play / Pause neural TTS narration |
| **Opt + Right Arrow** | Next spoken sentence |
| **Opt + Left Arrow** | Previous spoken sentence |
| **Cmd + J** | Jump to page number modal |
| **Cmd + B** | Toggle bookmark on current page |
| **Cmd + T** | Toggle Table of Contents sidebar |
| **Cmd + G** | Toggle thumbnail grid overview |
| **Cmd + D** | Toggle Dyslexia Reading Ruler |
| **Cmd + E** | Export notes and annotations |
| **Cmd + +** / **Cmd + -** | Zoom in / Zoom out |
| **Cmd + 0** | Fit page to screen |
| **?** | Open Keyboard Shortcuts cheat sheet |
| **Esc** | Return to Document Library |

---

## Security & Over-the-Air (OTA) Delivery

- **Hardened Runtime**: Mac Catalyst release builds compile with `ENABLE_HARDENED_RUNTIME = YES` for macOS Gatekeeper and notarization compliance.
- **SSRF & Network Defense**: In-app web article fetching validates HTTPS-only URLs, strictly blocks private/reserved IP ranges and cloud metadata (`169.254.169.254`), limits redirects to 3, and caps responses to 5 MB.
- **ZipArchive Decompression Safety**: Path traversal (`..`) and null bytes (`\0`) are stripped; single entries are capped at 100 MB, total extraction at 500 MB, and zip bombs are rejected (max ratio 1000:1).
- **Privacy & Redacted Logging**: All diagnostic `print()` statements are gated behind `#if DEBUG` to prevent document text, file paths, or reading progress from appearing in production device logs.
- **Temporary File Lifecycle & Backup Exclusion**: In-memory PDF data files automatically purge on document close (`deinit`), sandbox voice test artifacts are cleaned up on disappear, and audio caches are explicitly marked `isExcludedFromBackup = true` to preserve user iCloud backup storage quotas.
- **OTA Updates**: Pushing to `main` creates GitHub Releases with SHA-256 verified Mac Catalyst archives (`Vachanam-MacCatalyst.zip.sha256`) and supports direct TestFlight deployment for background iPad updates.
