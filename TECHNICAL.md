# Vachanam — Core Logic & Technical Architecture

Comprehensive technical specifications, coordinate models, algorithmic engines, parser architectures, memory lifecycles, and audit history for **Vachanam (వాచనం)**.

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

---

## 7. Build, Test & Project Synchronization

```bash
# Synchronize Xcode Project & Schemes (Required when adding/modifying files)
python3 generate_project.py

# Run Unit Tests on macOS (Mac Catalyst)
xcodebuild -project Vachanam.xcodeproj -scheme Vachanam -destination 'platform=macOS,variant=Mac Catalyst' -quiet test

# Run Unit Tests on iOS Simulator (iPad Air M4)
xcodebuild -project Vachanam.xcodeproj -scheme Vachanam -destination 'platform=iOS Simulator,name=iPad Air 11-inch (M4)' -quiet test
```
