# Vachanam — Core Logic & Technical Architecture

Comprehensive technical specifications, coordinate models, algorithmic engines, parser architectures, memory lifecycles, and audit history for **Vachanam (వచనం)**.

---

## 1. 3-Layer Document & Performance Architecture

Vachanam processes documents across three synchronized abstraction layers:

```
┌───────────────────────────────────────────────────────────────┐
│              LAYER 1: COORDINATE & VIEW MAPPING               │
│  - PDFKit Quartz 2D (origin: bottom-left, pts)                │
│  - SwiftUI & UIKit Overlay Layers (origin: top-left, pts)     │
│  - Line-Pitch Clamping (prevents symbol height bleed)         │
│  - CALayer Sub-pixel Rendering & KVO Scroll Follow            │
├───────────────────────────────────────────────────────────────┤
│              LAYER 2: SEMANTIC TEXT & STRUCTURE               │
│  - WordReconstructor: joins hyphenated breaks across lines    │
│  - ParagraphDetector: headings, lists, quotes, sidenotes      │
│  - PageFurnitureDetector: headers, footers, academic notices  │
│  - TextNormalizer & MathSpeechEngine: symbols, units, math    │
│  - Monotonic Global Word ID Allocation (0 ... N)              │
├───────────────────────────────────────────────────────────────┤
│              LAYER 3: AUDIO & TIMELINE SYNCHRONIZATION        │
│  - PlaybackCoordinator: single authoritative global cursor    │
│  - PlaybackScope: .document, .page(p), .selection([wordIDs])  │
│  - TTSChunker: 10–25 word / 128-token duration bounds         │
│  - Trailing Silence Injection: natural boundary breathing     │
│  - PreGeneratedPlaybackAdapter: instant offline streaming     │
│  - PronunciationManager: layered phoneme & grapheme overrides │
└───────────────────────────────────────────────────────────────┘
```

### Coordinate Space Conversions
- **PDFKit Quartz 2D**: Origin `(0, 0)` is at the bottom-left of the page. Y increases upwards.
- **UIKit / SwiftUI Views**: Origin `(0, 0)` is at the top-left of the view. Y increases downwards.
- **Conversion Contract**:
  $$y_{\text{view}} = \text{pageHeight} - (y_{\text{pdf}} + \text{height}_{\text{pdf}})$$
- **Line-Pitch & Math Symbol Sanitization (`SentenceSegmenter`)**:
  - Automatically identifies inflated PDFKit glyph bounding boxes on lines with mathematical symbols ($\forall, \Phi, \Longrightarrow$).
  - Clamps line height dynamically to `max(pageMedianLineHeight * 1.18, 12.5 pt)`.
  - In Quartz 2D, raises `minY` (`minY = b.maxY - clampedH`) to strictly prevent highlights from bleeding into adjacent lines below.

---

## 2. Core Algorithmic Engines

### 2.1 Sentence Segmentation & Semantic Blocks (`SentenceSegmenter`, `ParagraphDetector`)
- **Monotonic Global Word ID Contract**:
  Every word across the entire document receives an immutable `globalWordID` ($0, 1, 2, \dots, N$). Sentence boundaries, audio chunks, and highlight rects all point directly to this contiguous index space.
- **Semantic Block Classification (`BlockType`)**:
  - `.heading`: Evaluated via font height ratio ($\ge 1.25\times$ body font), bold traits, short character count, and title casing. Isolated as standalone TTS chunks.
  - `.listItem`: Prefixed with bullets (`•`, `-`, `*`) or numbers (`1.`, `(a)`). Preserved as standalone chunks.
  - `.quote`: Indented blocks or blockquotes.
  - `.paragraph`: Standard running narrative text.
  - `.sidenote`: Narrow margin columns separated via horizontal boundary analysis.
  - `.symbolTable`: Frontmatter notation tables and glossaries.

### 2.2 Page Furniture Detection (`PageFurnitureDetector`)
- **Spatial Zones**:
  - Running Headers: top 12% of page height.
  - Running Footers: bottom 10% of page height.
  - Footnotes: bottom 22% of page height.
- **Sentence Continuation Protection**:
  Lines terminating near the bottom margin with continuation heuristics (`verticalGap <= 1.8x line height` or starting with a lowercase character) are protected from accidental footer classification.
- **Publisher & Academic Disclaimer Detection**:
  Multi-line preprint and copyright statements (Cambridge University Press, arXiv, Oxford, IEEE) are classified as `.pageFooter` regardless of unpunctuated preceding lines.
- **Two-Pass Cross-Page Repetition Analysis**:
  Pre-analyzes candidate text in header and footer bands across the entire document; recurring strings (book/chapter titles, author names, Roman numeral frontmatter like `ii Contents`) across multiple pages are classified as `.pageHeader` and `.pageFooter`. In multi-page documents, non-recurring lines in the footer band are preserved as body text unless matching an explicit publication disclaimer or page number.

### 2.3 Mathematical Speech Normalization (`MathSpeechEngine` & `TextNormalizer`)
- **Exponents & Scientific Notation**:
  - Integer powers ($10^{23}$, $x^{-34}$, $10^{-12}$) expand into natural phrases ("ten to the power of twenty three", "ten to the minus thirty four").
  - Scientific $e$-notation (`6.022e23`) normalizes to standard spoken English ("six point zero two two times ten to the twenty three").
- **SI Units & Metric Prefixes**:
  Preceded by numeric values, abbreviations (`5 nm`, `2.4 GHz`, `100 ms`, `12 V`) expand into plural or singular words without false-positive matching on standard English words (`a ms`, `in a m`).
- **LaTeX Macro Translations**:
  Direct translation of `\frac{a}{b}`, `\sqrt{x}`, `\sum`, `\int`, `\prod`, and matrices (`bmatrix`, `pmatrix`, `vmatrix`) into configurable **Conversational** or **MathSpeak Rigorous** audio representations.
- **Hyphen & Compound Word Normalization**:
  Converts intra-word hyphens in compound words (`on-device` $\to$ `on device`, `word-by-word` $\to$ `word by word`) into unified single-space tokens, eliminating unnatural neural pauses.
- **Latin & Scholarly Abbreviations**:
  Expands `e.g.` $\to$ `for example,`, `i.e.` $\to$ `that is,`, `et al.` $\to$ `and colleagues`, `etc.` $\to$ `etcetera`, `vs.` $\to$ `versus`, `Fig.` $\to$ `Figure`, `p.`/`pp.` $\to$ `page`/`pages`.
- **Clean URLs & DOIs**:
  Spoken cleanly as `link to domain.com` or `publication link`, avoiding letter-by-letter spelling of protocol tokens.

### 2.4 Audio Chunking & Acoustic Naturalness (`TTSChunker`)
- **Token & Word Duration Tuning**:
  Chunks are sized to 10–25 words (1–2 sentences) to match Kokoro's fixed 128-token input limit, guaranteeing sub-2s time-to-first-audio.
- **Minimum Word Constraint**:
  Enforces `minWordsPerChunk` across narrative body text to eliminate 1–3 word fragmented chunks and prevent acoustic stuttering.
- **Trailing Silence Injection**:
  Injects trailing silence buffers into raw PCM audio (0.6s for headings, 0.4s for list items, 0.5s for paragraphs) to provide natural narrator cadence.

---

## 3. Playback Coordinator & Scope Enforcement Architecture

Structured around the principle:
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

### Core Components & Contracts
1. **`PlaybackCursor`**:
   Single authoritative position tracker: `documentID`, `pageIndex`, `paragraphIndex`, `sentenceIndex`, `wordIndex`, and `globalWordID`.
2. **`PlaybackScope`**:
   - `.document`: Sequential playback across pages until the final chunk of the last page, then strictly **STOP**. Eliminates infinite wrapping to page 0.
   - `.page(p)`: Strict hard boundary on page `p`. Automatically stops when the last word of page `p` finishes without advancing to page `p + 1` or looping.
   - `.selection([wordIDs])`: Target playback for specific selections.
3. **Decoupled Visible Page from Playback Page**:
   `visiblePageIndex` tracks viewport focus. When the user taps Play while reading page 8, `PlaybackCoordinator` begins at page 8 rather than resetting to page 1.
4. **Cancellation Tokens (`currentRequestID: UUID`)**:
   Tapping any word generates a new `requestID = UUID()`, cancels prior in-flight synthesis tasks, sets the cursor immediately, seeks audio, and discards stale async results.
5. **Sub-150ms Highlighting Drift Telemetry**:
   Calculates drift between audio sample playback position and visual word timestamp bounds. Drift is continuously measured and clamped under 150ms.

---

## 4. Universal Document Ingestion & Parsers

```
                Universal Input Source
      (PDF, EPUB, Markdown, Plain Text, Web URL)
                         │
              DocumentFormat.detect(from:)
                         │
      ┌──────────────────┴──────────────────┐
      ▼                                     ▼
[PDF Native Path]               [DocumentParserResolver]
(PDFKit / Quartz)                           │
                               ┌────────────┼────────────┐
                               ▼            ▼            ▼
                          EPUBParser  MarkdownParser  PlainTextParser
                         (ZipArchive)       │            │
                               │            │            │
                               └─────┬──────┘            │
                                     ▼                   │
                              WebArticleParser           │
                                     │                   │
                                     ▼                   │
                          ParsedDocument Model ──────────┘
                                     │
                          SemanticDocumentBuilder
                                     │
                                     ▼
                           SemanticDocument (3-Layer)
```

### 4.1 EPUB & ZIP Decompression (`EPUBParser`, `ZipArchive`)
- **ARM64 Unaligned Reading**: Employs manual little-endian byte readers (`readUInt16`, `readUInt32`) in `ZipArchive` to eliminate `misaligned raw pointer` fatal errors on Apple Silicon.
- **Chunked Dynamic Deflate**: Streams decompressions in 32 KB dynamic buffers, supporting streaming archives with general-purpose bit 3 Data Descriptors (`uncompressedSize = 0`).
- **Path Normalization & Archive Lookup**: Resolves Windows backslashes (`\`), strips leading `./` and `/`, resolves relative components (`..`), and decodes URI percent encodings (`%20`).
- **Flexible OPF Manifest & Spine Extraction**: Decouples `<item>` and `<itemref>` parsing to tolerate arbitrary attribute orderings, line breaks, and whitespace around `=`, with automatic fallback to manifest XHTML documents if the spine is missing.
- **Word-Gluing Prevention & HTML Entity Decoding**: Pre-converts `<br>`, `<p>`, `<div>`, `</li>`, and heading tags into newlines before stripping markup. Decodes decimal (`&#8212;`), hexadecimal (`&#x2600;`), and extended named HTML entities.

### 4.2 Plain Text & Markdown Parsers (`PlainTextParser`, `MarkdownParser`)
- **Multi-Encoding Fallback Cascade**: Replaced strict UTF-8 loading with a robust decoding cascade:
  $$\text{Data} \longrightarrow \text{UTF-8} \longrightarrow \text{ISO Latin 1} \longrightarrow \text{Windows-1252} \longrightarrow \text{UTF-16} \longrightarrow \text{ASCII}$$
- **CRLF Normalization**: Standardizes Windows `\r\n` and legacy `\r` line breaks into `\n`.
- **Setext Heading Recognition**: Supports underline headers (`===` for Level 1, `---` for Level 2) alongside standard ATX (`#`) headings in Markdown.

### 4.3 Semantic Document Bridge (`SemanticDocumentBuilder`)
- **Sentence-Aligned Virtual Page Boundaries**: Partitions non-PDF documents into virtual pages strictly at sentence boundaries, avoiding split sentence spans.

---

## 5. Audio Engine & Neural Model Integration

### 5.1 On-Device TTS Models & Memory Constraints
| Model | Size | Arch / Framework | Min RAM | Key Traits |
| :--- | :--- | :--- | :--- | :--- |
| **Apple Natural** | System | `AVSpeechSynthesizer` | 2 GB | Offline, zero-overhead, system voice catalog |
| **Kokoro 82M** | ~82 MB | CoreML (FP16) | 4 GB | Ultra-fast neural inference, fixed 128-token input |
| **Qwen3-TTS 0.6B** | ~600 MB | CoreML / MLX | 8 GB | Native prosody, expressive inflection |
| **Chatterbox Turbo** | ~350 MB | CoreML | 8 GB | Emotion markup (`[laugh]`, `[sigh]`) |
| **CosyVoice 3 0.5B** | ~500 MB | 4-bit Quantized MLX | 8 GB | Real-time streaming voice synthesis |

### 5.2 Neural Model Memory Lifecycle & Loaded State Architecture
```
[Cloud / Remote] ──Download──> [On-Disk Cache] ──Load──> [Unified RAM (Active Model)] ──Unload──> [On-Disk Cache]
```
- **Unified Memory Management (`loadModel` / `unloadModel`)**: Calling `loadModel(weightsDirectory:)` verifies directory integrity, warms up the Misaki G2P phonetic lookup cache, and transitions `isLoaded = true`. Calling `unloadModel()` purges cached execution buffers, freeing RAM for multitasking.
- **Automatic Lifecycle Synchronization**: Switching active models unloads the outgoing model and loads the incoming model asynchronously.
- **VoiceProfileResolver**: In simulator environments or when neural weights are not yet downloaded, dynamically maps voice presets (`af_heart`, `am_michael`, `bf_emma`) to matching high-definition system voices with fine-tuned pitch and cadence.

### 5.3 Mac Audiobook Studio & iCloud Pre-Generated Pipeline
- Pre-generates complete books in batch on macOS into AAC `.m4a` chapter audio and microsecond word-level timing indexes (`manifest.json`).
- Replicates bundles across iCloud Drive (`iCloudSyncManager`) for instantaneous zero-inference playback on iPad and mobile devices via `PreGeneratedPlaybackAdapter`.

### 5.4 Ambient Focus Soundscapes Architecture
- Integrated background acoustic player with 5 tailored ambient loops: **Brown Noise**, **Pink Noise**, **40Hz Binaural Beats**, **Soft Rain**, and **Library Ambience**.
- Dedicated `AVAudioPlayer` instances with `.mixWithOthers` audio session category.
- Automatically couples with speech narration (starts on Play, pauses on Pause, stops on Stop) with an independent **Study Mode** toggle for reading without speech narration.

---

## 6. Technical Audit & Resolution History

1. **[AUD-01] AppState Lifecycle & Reading Progress Restoration**:
   - Fixed regression where reopening a document reset reading progress to page 0.
   - Synchronously initializes `ReaderContainerView` with the saved page, eliminating race conditions with PDFKit view initialization.
   - Enhanced `ReadingRecord` and `ReadingProgressTracker` to track fine-grained positions (`lastWordID` and `lastSentenceID`).

2. **[AUD-02] Hit-Testing & Viewport Stability**:
   - Resolved UIKit assertion failures on pointer interactions using `PDFDocumentViewHitTestSanitizer`.
   - Prevented SwiftUI `AttributeGraph` cycles by isolating programmatic scroll dispatches.

3. **[AUD-03] Word Reconstruction & Compound Words**:
   - Joined hyphenated line breaks (`probabil-` + `ity` $\to$ `probability`) while preserving compound terms (`well-known`).

4. **[AUD-04] Symbol-to-Speech Normalization**:
   - Expanded mathematical operator symbols, currencies, percentages, and fractions into natural speech representations.

5. **[AUD-05] Exponent Speech Engine (`MathSpeechEngine`)**:
   - Added integer exponent grammars for multi-digit powers ($10^{23}$, $10^{-34}$).

6. **[AUD-06] Academic Page Furniture & Disclaimer Isolation**:
   - Added two-pass cross-page repetition analysis and preprint notice detection.

7. **[AUD-07] Continuous & Spread Highlighting**:
   - Replaced fragile timer polling with direct KVO content offset observation on PDFView's scroll hierarchy.

8. **[AUD-08] Auto-Scroll Follow Mode**:
   - Added pause-on-scroll lifecycle and interactive auto-scroll capsule prompt.

9. **[AUD-09] Keyboard Navigation Suite**:
   - Implemented complete physical keyboard shortcut handling on iPad and Mac Catalyst.

10. **[AUD-10] Multi-Discipline Benchmark Document**:
    - Bundled a 4-page academic benchmark covering machine learning, quantum mechanics, and organic chemistry.

11. **[AUD-11] Ambient Focus Soundscapes**:
    - Integrated background acoustic player with 5 audio loops, volume persistence, and study mode.

12. **[AUD-12] Developer Diagnostics & macOS Menu Bar**:
    - Added single-page JSON diagnostic exporter, voice sandbox, and merged Mac menu bar items into standard View menu.

13. **[AUD-13] Sentence Flow & Cadence Restoration**:
    - Restored authentic terminal falling pitch contours by reverting comma substitutions before equation tags.

14. **[AUD-14] Line-Pitch Clamping & Math Symbol Bleed Prevention**:
    - Clamped PDFKit font bounding box heights dynamically to median line pitch, preventing highlights from bleeding into adjacent lines.

15. **[AUD-15] EPUB & Multi-Format Ingestion Robustness**:
    - Replaced unaligned memory pointer reads in `ZipArchive` with unaligned bitwise byte readers, resolving ARM64 SIGBUS/misalignment crashes.
    - Added 32 KB chunk streaming deflate to handle streaming archives and Data Descriptors (`uncompressedSize = 0`).
    - Standardized archive entry lookups with path component resolution, Windows backslashes (`\`), and percent decoding (`%20`).
    - Made OPF manifest parsing tolerant of multi-line attributes, arbitrary attribute orders, and whitespace around `=`.
    - Added newline insertion before HTML tag stripping to eliminate word gluing, and supported named/numeric HTML entity decoding.
    - Added multi-encoding fallback (`.utf8` $\to$ `.isoLatin1` $\to$ `.windowsCP1252` $\to$ `.utf16` $\to$ ASCII) for Plain Text and Markdown.
    - Made sandbox file copying overwrite-safe with destination removal in `DocumentLibraryView` and `AudiobookGeneratorView`.
    - Aligned virtual page breaks to sentence boundaries in `SemanticDocumentBuilder`.
    - Added comprehensive unit test suite `EPUBParserTests.swift`.

16. **[AUD-16] EPUB Parser Acceleration & Reader View Virtual Paging**:
    - Optimized `ZipArchive` with $O(1)$ case-insensitive hash lookup mapping and zero-copy preallocated buffer decompression (`Z_FINISH`), avoiding repeated byte-by-byte copies and multi-cycle array reallocations.
    - Precompiled all regular expressions statically in `EPUBParser` (`itemTagRegex`, `blockPatternRegex`, `scriptRegex`, `styleRegex`, `htmlTagRegex`, decimal/hex entity regexes), avoiding repetitive regex compilation overhead across thousands of paragraphs.
    - Implemented fast-path checks (`contains("<")` and `contains("&")`) in `cleanHTMLText` to eliminate redundant tag and entity scan loops.
    - Reused `NLTokenizer` instances for sentence and word segmentation in `SemanticDocumentBuilder`, removing thousands of framework initialization and teardown cycles per book.
    - Rewrote `ReaderTextView` to use virtual page windowing (`sentencesForCurrentPage`) with `LazyVStack`, eliminating eager instantiation of 10,000+ views in memory.
    - Bound `ReaderTextView` to `currentPageIndex` with page navigation footer controls and automatic page flipping during live TTS playback across chapter boundaries.
    - Isolated word highlighting so non-speaking sentences bypass `AttributedString` generation for instantaneous 120 FPS typography rendering and scrolling.

17. **[AUD-17] Android Platform Port (Kotlin + Jetpack Compose)**:
    - Designed and implemented full feature-parity native Android application in `VachanamAndroid/` targeting API 31+ (Android 12) with Material 3.
    - Ported 3-layer semantic document architecture (`SemanticDocument`, `SemanticSentence`, `SemanticWord`, `TTSChunk`, `BoundingBox`).
    - Implemented universal document parsers in Kotlin: `EPUBParser` (ZIP streaming, OPF manifest/spine parsing, clean entity decoding), `MarkdownParser` (ATX/Setext, lists, quotes, code blocks), `PlainTextParser` (multi-encoding fallback cascade), and `WebArticleParser` (URL fetching and article body extraction).
    - Integrated PDFBox-Android for spatial word/sentence boundary extraction and `android.graphics.pdf.PdfRenderer` for high-resolution 2x bitmap page rendering.
    - Built pluggable `TTSModelProtocol` with `AndroidSystemAdapter` utilizing `UtteranceProgressListener.onRangeStart` for real-time word-level karaoke highlighting, and `KokoroOnnxAdapter` for on-device neural synthesis.
    - Ported acoustic focus player `AmbientSoundscapePlayer` reusing 5 bundled `.m4a` soundscape loops (`res/raw/`) with volume persistence, infinite looping, smooth crossfade, and study mode.
    - Added distraction-free `ReaderTextView` with virtual pagination, OpenDyslexic font support (`res/font/`), bionic reading mode, draggable `ReadingRulerOverlay`, and 5 reader background themes.
    - Reused 4-page academic benchmark PDF and full LaTeX/SI Unit/Greek math speech dictionaries in Android assets.
    - Added unit test suite `VachanamCoreLogicTest.kt` verifying word reconstruction, math speech vocalization, and chunk duration bounds.

18. **[AUD-18] iOS / macOS Platform Specialization & Shared Architecture Reorganization**:
    - Segmented `Vachanam/` into clean, dedicated architectural domains:
      - `Vachanam/Shared/`: Multi-platform application core (`App/`, `Document/`, `TTS/`, `Audio/`, `Accessibility/`, `Adapters/`, `PDF/`, and shared `Views/`).
      - `Vachanam/iOS/`: iPadOS & iOS specialized features (`Annotations/AnnotationManager.swift` and `Views/Annotations/` containing `CanvasOverlay.swift`, `AnnotationToolbar.swift`, `ShapeToolView.swift`, `StickyNoteView.swift`, `TextBoxView.swift`, `AnnotationExportView.swift`).
      - `Vachanam/macOS/`: Mac Catalyst specialized features (`Studio/` containing batch audiobook generator & manifest export, `Navigation/` containing catalyst menu commands & keyboard shortcuts, `Developer/` diagnostics).
      - `Vachanam/Tests/` & `Vachanam/UITests/`: Moved test suites from root workspace into `Vachanam/`, establishing a clean 2-app workspace structure (`Vachanam/` + `VachanamAndroid/`).
    - Upgraded `generate_project.py` with explicit PBXGroup definitions for `Shared`, `iOS (iPadOS & PencilKit)`, `macOS (Mac Catalyst & Studio)`, `Tests`, `UITests`, and `Resources`.
    - Preserved single unified multi-platform Xcode project scheme `Vachanam` targeting both iOS (iPadOS) and macOS (Mac Catalyst) without duplicated compilation settings or split targets.
18. **[AUD-19] Apple Books Reading Experience, Shelf Organization & Book Intelligence (Apple & Android)**:
    - **Dual-Mode Reading Layout**: Built synchronized Apple Books-inspired paginated reading mode (`.paginated` using SwiftUI `TabView` on Apple and Jetpack Compose `HorizontalPager` on Android) with running chapter header, footer page count, edge-tap navigation, center-tap animated chrome hide/show, and bidirectional TTS page turns. Kept `.continuous` vertical scroll mode selectable via Appearance settings.
    - **Apple Books Theme Palettes**: Synchronized 5-theme color palettes (`Original`, `Quiet`, `Paper`, `Charcoal`, `Night`) across SwiftUI and Jetpack Compose.
    - **Library Organization & Shelves (`BookCollectionManager`)**: Built-in collections (`All`, `Reading`, `Favorites`, `Finished`) and user-created custom shelves with persistent storage and horizontal category filter pills.
    - **Document Deletion & Sandbox Sanitation**: Complete purge of local files, reading progress records, favorite/finished states, and shelf associations.
    - **Book Intelligence Preloading (`BookPreparationService`)**: Async background task analyzes book chapters, computes exact word counts, and predicts human reading time (~225 wpm) and neural audio narration time (~150 wpm).
    - **Precision Resume Toast Banner**: Floating toast on opening a document displaying current chapter position and an inline `Play` button to start TTS immediately.
19. **[AUD-20] Unified Reading Layouts (Single Page, Two Pages, Continuous Scroll) & Universal Dynamic Theme Synchronization**:
    - **App-Dependent Architecture**: Decoupled reading layouts and color themes from file formats. `ReadingLayout` and `ReaderBackgroundTheme` are maintained globally in `ThemeManager` across both Apple (Swift) and Android (Kotlin), ensuring consistent user preferences regardless of whether reading EPUB, PDF, Markdown, Plain Text, or Web Articles.
    - **Two-Page Book Spread Mode**: Implemented `.twoPage` / `TWO_PAGE` ("Two Pages") across all document readers. Renders dual columns side-by-side with a subtle center book spine divider (`textColor` alpha 0.12), running chapter header, and dual-page indicators ("Pages X–Y of N"). Synchronized edge taps (`-2 / +2` step) and automated TTS page flips when narration advances across two-page boundaries.
    - **Dynamic PDF Theme Background Binding**: Bound native PDF viewports (`pdfView.backgroundColor` in Quartz 2D / PDFKit on Apple, and container canvas on Android) directly to `currentReaderTheme.backgroundColor`. Eliminates jarring bright white borders around PDF pages when reading under Quiet, Paper, Charcoal, or Night themes. Native PDFs also map `ReadingLayout` directly to PDF display modes (`.singlePage`, `.twoUp`, and `.singlePageContinuous`).
    - **Universal Paginated Reader View**: Replaced format-specific reader views (`EPUBPaginatedReaderView` / `EPUBPaginatedReader`) with universal `PaginatedReaderView` supporting any `SemanticDocument`. Added clean text extraction toggle to PDF reader views, enabling any academic PDF to be read either in original fixed-layout or in reflowed clean typography with font resizing, OpenDyslexic, bionic reading, and full 3-layout pagination.
    - **Scrubber & Controls Parity**: Updated `ReaderScrubberBar` and top navigation bars across iOS, macOS, and Android to support 3-layout cycling, dual-page progress labeling, and seamless PDF mode switching.
20. **[AUD-21] In-Flow Multi-Format Image Ingestion, Apple Books Page Bounds & Keyboard Navigation Suite (Apple & Android)**:
    - **In-Flow Image Extraction & Semantic Pipeline**:
      - `EPUBParser`: Implemented full archive binary extraction for `<img>` and SVG `<image xlink:href>` tags. Resolved paths relative to chapter directories and manifest tables, extracting image data and preserving in-flow reading order.
      - `MarkdownParser`: Extracted `![alt](url_or_path)` into discrete `ParsedBlock` items with alt captions and resolved URLs.
      - **Semantic Document Bridging**: Added `BlockType.image` / `IMAGE`, `imageData`, and `imageURL` / `imageUrl` across `ParsedBlock`, `SemanticSentence`, and `SentenceItem`.
      - **UI Rendering**: Integrated responsive image rendering in `ReaderTextView` (SwiftUI) and `ReaderTextView` (Compose) with aspect-ratio preservation, rounded corners, subtle shadows, and italic captions.
    - **Apple Books Page Bounds & Two-Page Spine Depth**:
      - Added symmetrical page margins (outer reading edge vs. inner spine edge) and center spine depth gradient in `PaginatedReaderView`.
      - Added `pageBreakMargins` (16pt) in `PDFReaderView` for clear visual separation of adjacent pages.
      - Formatted dual-page range strings ("Pages X–Y of Z") and chapter progress indicators in `ReaderScrubberBar`.
    - **Universal Keyboard Controls & Accessibility Suite**:
      - Wired comprehensive `.onKeyPress` listeners and NotificationCenter publishers for all reading layouts: Left/Right arrows, Up/Down arrows, Page Up/Down, Space/Shift-Space, Home/End, Command-J.
      - Added single-key shortcuts: `c` (cycle reading layout), `t` (cycle theme), `p` (play/pause TTS), `[` and `]` (previous/next chapter), `?` (shortcuts cheatsheet), `Esc` (return to library).
      - Enforced spread-aligned stepping (`pageStep = 2`) in two-page mode to prevent asymmetric spread splits.
21. **[AUD-22] Two-Page Spread Geometry & Virtual Page Budget Calibration (Apple & Android)**:
    - **Two-Page Spread Column Width Math**: Fixed two-page column width computation to `pageWidth = (size.width - spineWidth) / 2` with `spineWidth = 14`, ensuring exact viewport fit without horizontal clipping or bleed.
    - **Floating Chrome Insets**: Added dynamic bottom safe insets in `PaginatedReaderView` so text and footers remain unobscured when the scrubber and playback bars are visible.
    - **Reflowable Virtual Page Calibration**: Calibrated `targetWordsPerVirtualPage` from 350 to **100 words** across `SemanticDocumentBuilder.swift` and `SemanticDocumentBuilder.kt`, preventing excessive 50–60 line overflows in two-page mode and eliminating awkward vertical scrolling.
    - **Responsive Two-Page Typography**: Applied `0.80x` body font scaling and tightened line spacing (3pt) in `PaginatedReaderView` to ensure all lines fit comfortably within screen bounds.
22. **[AUD-23] Automated Push-to-Deploy CI/CD Pipelines & Security Hardening (Apple & Android)**:
    - **Automated Continuous Delivery Workflows**:
      - Added `.github/workflows/ci.yml`: Runs Mac Catalyst XCTest suite and Android unit tests on all PRs and pushes.
      - Added `.github/workflows/release-android.yml`: Automatically builds signed APK on push to `main` and publishes a GitHub Release tagged with build numbers for instant over-the-air auto-updates via Obtainium or direct APK download.
      - Added `.github/workflows/release-apple.yml`: Archives Mac Catalyst release binaries as `.zip` artifacts on GitHub Releases and configures automated TestFlight delivery for background iPad updates.
    - **Apple Security Hardening**:
      - Enabled `ENABLE_HARDENED_RUNTIME = YES;` in `conf_release_app` in `generate_project.py`, ensuring macOS Gatekeeper notarization compliance and runtime code injection protections.
    - **Android Security Hardening**:
      - Configured `data_extraction_rules.xml` and `backup_rules.xml` under `res/xml/` to prevent unauthorized ADB data extraction of user credentials and reading documents while allowing encrypted cloud migration.
      - Enforced `android:usesCleartextTraffic="false"` and `android:enableOnBackInvokedCallback="true"` in `AndroidManifest.xml`.
      - Added ProGuard / R8 keep rules for `androidx.media3` and `kotlinx.coroutines`.

24. **[AUD-24] Supply-Chain, SSRF, Adversarial Decompression & Privacy Hardening**:
    - **CI/CD Supply-Chain Pinning & Checksum Integrity (`ci.yml`, `release-android.yml`, `release-apple.yml`)**:
      - Pinned all GitHub Actions dependencies to immutable full commit SHAs (`actions/checkout@11bd7190...`, `actions/setup-java@3a504288...`, `gradle/actions/setup-gradle@017a9eff...`, `actions/upload-artifact@65462800...`, `softprops/action-gh-release@c9541483...`).
      - Restricted workflow permissions to `permissions: {}` top-level, scoping `contents: read` for test CI and `contents: write` strictly to release jobs.
      - Automated SHA-256 checksum generation (`sha256sum`) for both `Vachanam-Android.apk` and `Vachanam-MacCatalyst.zip`, embedding verified cryptographic hashes directly into release notes and uploading `.sha256` verification files.
      - Added `.github/dependabot.yml` for automated weekly vulnerability scanning and dependency updates across GitHub Actions and Gradle.
    - **WebArticleParser SSRF & Network Hardening (`WebArticleParser.swift`, `WebArticleParser.kt`)**:
      - **HTTPS Scheme Validation**: Strictly enforces `https` URL protocol, rejecting insecure `http`, `file`, `ftp`, `data`, and `javascript` schemes.
      - **SSRF & Cloud Metadata Mitigation**: Resolves destination hostnames and rejects loopback (`127.0.0.0/8`, `::1`), private networks (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, `fc00::/7`), link-local (`169.254.0.0/16`, `fe80::/10`), CGNAT (`100.64.0.0/10`), and cloud metadata (`169.254.169.254`).
      - **Redirect Governance**: Caps HTTP redirects to max 3, preventing infinite redirect attacks and rejecting any redirection that downgrades HTTPS to HTTP or routes to private endpoints.
      - **Streaming Response Size Cap**: Caps live web article downloads to 5 MB maximum, terminating oversized streams before memory allocation.
    - **ZipArchive Adversarial Input Hardening (`ZipArchive.swift`)**:
      - **Path Traversal & Null Byte Sanitization**: Enhanced `normalizeEntryPath` to strip null bytes (`\0`) and resolve relative path sequences (`..`) and Windows backslashes (`\`).
      - **Decompression Caps**: Enforced single-entry decompressed limit (100 MB max) and cumulative archive expansion limit (500 MB max).
      - **Zip Bomb Defense**: Rejects compressed entries where the decompression expansion ratio exceeds 1000:1.
    - **Sensitive Data & Console Logging Gating**:
      - Gated all 19 diagnostic `print()` statements across Apple production code (`AppState`, `ReadingProgressTracker`, `PlaybackCoordinator`, `TTSController`, `DocumentLibraryView`, etc.) behind `#if DEBUG`, preventing document paths, reading progress, and word text from emitting to system logs.
      - Verified zero logging leaks in Android production source.
    - **Android R8 Release Minification (`build.gradle.kts`)**:
      - Enabled `isMinifyEnabled = true` and `isShrinkResources = true` in the release build type with debug key fallback signing for immediate sideloading and OTA updates.

  - **`[AUD-25]` Reader UI/UX Layout Boundary & Adversarial Regression Suite**:
    - **Layout Boundary Edge-Case Suite (`LayoutBoundaryEdgeCaseTests.swift`)**:
      - **Empty Documents (0 Blocks)**: Handled gracefully by `SemanticDocumentBuilder`, emitting 1 blank virtual page with 0 sentences and 0 words rather than throwing index out of bounds.
      - **Single Sentence Documents**: Verified across layouts with correct 1-page bounds.
      - **Odd Page Count in Two-Page Mode**: Verified spread alignment with `lastSpreadIndex % 2 == 0` ensuring the final spread renders the trailing page cleanly as a left leaf.
      - **Empty Chapters**: Verified that empty chapters interspersed between non-empty chapters are handled without halting pagination.
      - **10,000+ Word Monolithic Chapters**: Verified virtual page chunking generates ~100 virtual pages smoothly with stable memory consumption.
      - **Image-Only Documents & Phantom Chunk Defense**: Verified captionless images generate zero spoken words and `TTSChunker` cleanly skips them without creating phantom zero-duration audio chunks. Alt-text/captions remain spoken when provided for accessibility.
      - **TTS Cursor Boundary Invariants**: Word 0 and document-tail word IDs verified for exact indexing.
    - **Adversarial EPUB & Large-Token Suite (`AdversarialParserTests.swift`)**:
      - Verified graceful handling and structured error reporting for missing `container.xml` and missing OPF packages.
      - Verified manifest fallback rescue when spines contain invalid or circular itemrefs.
      - Verified parsing safety against 1000-level nested HTML tags and SVG malicious scheme injection (`file://`, `javascript://`, `data://`).
      - Verified robust sentence and TTS chunking on 100,000-character single paragraphs and 50,000-character unbroken tokens.
    - **Sandbox Temp File Lifecycle & iCloud Backup Exclusion**:
      - `ReaderDocument`: Added `isTemporaryFile` lifecycle flag and automated filesystem removal on `deinit`.
      - `VoiceTestingSandboxView`: Added automatic purging of old temporary report JSON and synthesized WAV files upon re-execution and `.onDisappear`.
      - `TTSAudioCache`: Set `URLResourceValues.isExcludedFromBackup = true` on the disk cache directory to prevent transient neural audio artifacts from consuming user iCloud backup storage quotas.

  - **`[AUD-26]` Android Release Pipeline Hardening & Obtainium Substantial Release Resolution**:
    - **Obtainium Discovery & Substantial Release**: Resolved Obtainium's *"could not find substantial release"* error by completing end-to-end automated builds of signed release APKs (`Vachanam-Android.apk`) attached with SHA-256 checksums to GitHub Releases (`v1.0.x`).
    - **Production Source Verification**: Fixed Kotlin compiler errors that escaped unit testing:
      - Corrected `sentencesByPage` grouping logic in `SemanticDocument.kt`.
      - Guarded nullable chapter titles in `BookPreparationService.kt`.
      - Provided default parameters (`val id: Int = ...`) across all semantic data models and passed both `chunkID` and `id` in `TTSChunker.kt`.
      - Corrected `DocumentFormat.PLAIN_TEXT` enum reference in `DocumentLibraryScreen.kt`.
      - Defined `CoralRed` theme token in `Color.kt` and wired `AppState.play()` / `AppState.pause()` delegation to `TTSController`.
      - Replaced non-existent `Waveform` icon with `Icons.Default.Waves` for pink noise in `SoundscapePickerSheet.kt`.
    - **CI Diagnostic Annotations**: Configured line-by-line compiler error annotations in `release-android.yml` for real-time failure triage.

---

## 7. Multi-Platform Build, Test & Technical Docs

Detailed platform-specific technical specifications and audit histories are maintained in their respective platform directories:
- **Apple (iPadOS & macOS)**: See [VachanamApple/TECHNICAL.md](VachanamApple/TECHNICAL.md) for Quartz 2D math, CoreML/MLX pipelines, and Apple audit entries (`[AUD-01]`..`[AUD-16]`, `[AUD-18]`).
- **Android (12+)**: See [VachanamAndroid/TECHNICAL.md](VachanamAndroid/TECHNICAL.md) for PDFBox coordinate mapping, Android TTS integration, and Android audit entry (`[AUD-17]`).

### Build & Test Commands

#### Apple (iPadOS & Mac Catalyst)
```bash
cd VachanamApple

# Synchronize Xcode Project & Schemes
python3 generate_project.py

# Run Unit Tests on macOS (Mac Catalyst)
xcodebuild -project Vachanam.xcodeproj -scheme Vachanam -destination 'platform=macOS,variant=Mac Catalyst' -only-testing:VachanamTests -quiet test

# Run Unit Tests on iOS Simulator (iPad Air M4)
xcodebuild -project Vachanam.xcodeproj -scheme Vachanam -destination 'platform=iOS Simulator,name=iPad Air 11-inch (M4)' -only-testing:VachanamTests -quiet test
```

#### Android (Kotlin + Jetpack Compose)
```bash
cd VachanamAndroid

# Run JVM Unit Tests
./gradlew testDebugUnitTest

# Assemble Debug APK
./gradlew assembleDebug
```
