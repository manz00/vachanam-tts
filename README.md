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
- **🎧 Ambient Focus Soundscapes**:
  - Integrated acoustic background player with 5 tailored ambient loops: **Brown Noise**, **Pink Noise**, **40Hz Binaural Beats**, **Soft Rain**, and **Library Ambience**.
  - Independent volume slider (`0.0`–`1.0`) with persistence, smooth fade-in/fade-out transitions, and audio session mixing (`.mixWithOthers`).
  - Automatically couples with speech narration (starts on Play, pauses on Pause, stops on Stop) with an independent **Study Mode** toggle for reading without speech narration.
- **📖 Multi-Format Document Ingestion (EPUB, Markdown, Plain Text, Web Articles)**:
  - Expands Vachanam beyond PDFs into a universal reader for `.epub` books, `.md` markdown files, `.txt` documents, and live web article URLs.
  - Built-in `EPUBParser` with custom ZIP decompression (`ZipArchive`) and XHTML chapter spine parsing.
  - `MarkdownParser` and `WebArticleParser` with readability-heuristic text extraction.
  - `SemanticDocumentBuilder` maps all formats seamlessly into Vachanam's monotonic `SemanticDocument` pipeline with word tokenization and virtual paging, opening directly in **Reader View** with custom fonts, themes, and karaoke highlighting.
- **☁️ Mac Audiobook Studio & iCloud Drive Pre-Generated Playback**:
  - Turn your Mac into a local audiobook production studio (`AudiobookGeneratorView`).
  - Pre-generates complete books with Kokoro neural speech into AAC `.m4a` chaptered audio and microsecond word timestamps (`manifest.json`).
  - Automatic iCloud Drive synchronization (`iCloudSyncManager`) makes generated audiobooks instantly available across iPad, Mac, and mobile devices.
  - Zero-latency iPad playback adapter (`PreGeneratedPlaybackAdapter`) streams or plays local cached chunks with instant word-by-word highlighting and zero on-device inference overhead.
- **3-Layer Document & Performance Architecture**:
  - **Layer 1 (PDF Layout)**: PDFKit coordinate rendering with precise word bounding boxes and multi-line highlights.
  - **Layer 2 (Semantic Text)**: `WordReconstructor` automatically joins hyphenated line breaks (`probabil-` + `ity` $\to$ `probability`) while preserving compound words (`well-known`). `ParagraphDetector` and `SentenceSegmenter` reconstruct natural linguistic flow with semantic block recognition (`BlockType.heading`, `listItem`, `paragraph`, `quote`).
  - **Layer 3 (Audio Timeline)**: Speech is synthesized in ~10–25 word (1–2 sentence) semantic chunks tuned to Kokoro's fixed 128-token duration limit, preventing multi-pass recursive splitting and guaranteeing sub-2s initial inference latency. `TTSChunker` enforces `minWordsPerChunk` across non-standalone body blocks, eliminating 1–3 word fragmented chunks and preventing acoustic stuttering.
- **Semantic Block Segmentation & Boundary Isolation**:
  - Distinguishes structural block types (`BlockType.heading`, `listItem`, `paragraph`, `quote`) based on font height, short word count, regex prefixes, and typography.
  - Headings and list items are strictly preserved as standalone TTS chunks to prevent awkward concatenation into adjacent paragraphs.
- **Natural Boundary Pauses**:
  - Injects tailored trailing silence PCM buffers directly into chunk audio (0.6s after headings, 0.4s after list items, 0.5s after paragraphs).
  - Gives the narrator natural acoustic breathing room and keeps visual focus on the final spoken word during pauses without UI jitter.
- **Advanced Symbol-to-Speech & Math Normalization**:
  - `TextNormalizer.normalizeForSpeech` converts mathematical operators (`×` $\to$ `times`, `÷` $\to$ `divided by`, `≠` $\to$ `is not equal to`, `≤`, `≥`, `≈`, `∞`), vulgar fractions (`½` $\to$ `one half`, `¼` $\to$ `one quarter`), currencies (`$100` $\to$ `100 dollars`, `€`, `£`, `¥`), percentages (`25%` $\to$ `25 percent`), plus-minus (`±5` $\to$ `plus or minus 5`), temperatures and angles (`100°C` $\to$ `100 degrees Celsius`, `72°F` $\to$ `72 degrees Fahrenheit`, `90°` $\to$ `90 degrees`), and ampersands (`&` $\to$ `and`) into fluent speech while preserving sentence punctuation.
  - **Hyphen & Compound Word Normalization**: Converts intra-word hyphens in compound words (`on-device` $\to$ `on device`, `accessibility-focused` $\to$ `accessibility focused`, `word-by-word` $\to$ `word by word`, `text-to-speech` $\to$ `text to speech`, `karaoke-style` $\to$ `karaoke style`) into unified single-space tokens. This eliminates unnatural neural pauses at hyphens and prevents words before the hyphen from awkwardly trailing backward or words after the hyphen from abruptly rushing forward.
  - **Numeric Range Normalization**: Converts hyphenated number intervals (`10-20` $\to$ `10 to 20`, `1-2` $\to$ `1 to 2`, `pages 5-8` $\to$ `pages 5 to 8`).
  - **Parenthetical Dash Smoothing**: Converts em-dashes (`—`), en-dashes (`–`), and spaced hyphens into natural comma pauses (`", "`) for smooth conversational breathing rather than dead-air silence.
  - Automatically strips visual bullet ornaments (`•`, `◦`, `▪`, `▫`, `●`, `■`, `◆`, `❖`, `★`, `☆`, `►`, `▻`, `➢`, `✓`, `✔`) and leading list hyphens/asterisks (`- `, `* `) so that visual layout glyphs are never spoken awkwardly or indexed as phantom audio words.
  - **Human-Narrated Speech Normalization (`TextNormalizer`)**:
    - **Latin & Common Abbreviations**: Expands `e.g.` $\to$ `for example,`, `i.e.` $\to$ `that is,`, `et al.` $\to$ `and colleagues`, `etc.` $\to$ `etcetera`, `vs.` $\to$ `versus`, `approx.` $\to$ `approximately`, `ca.` / `c.` $\to$ `circa`, `p.` / `pp.` before page numbers $\to$ `page` / `pages`, `Fig.` / `Figs.` before numbers $\to$ `Figure` / `Figures`, `Vol.` / `No.` before numbers $\to$ `Volume` / `Number`.
    - **Clean URLs & DOIs**: Web URLs (`https://example.com/path`) are spoken cleanly as `link to example.com`, and DOIs (`doi:10.1000/182`) as `publication link`, avoiding confusing letter-by-letter spelling of protocol tokens and URL parameters.
- **🧠 Page Furniture & Reading Intelligence Engine (`PageFurnitureDetector`)**:
  - **Spatial Zone Filtering**: Distinguishes running headers (top 12%), running footers (bottom 18%), and footnotes (bottom 22%) relative to page coordinate dimensions.
  - **Standalone Page Number Recognition**: Regex recognition for isolated digits (`42`), Roman numerals (`iv`, `XII`), "Page X of Y", and hyphenated/bracketed markers (`- 42 -`).
  - **Academic & Publisher Disclaimer Detection**: Intelligently identifies and isolates multi-line copyright, preprint, and distribution notices in the footer band (e.g., Cambridge University Press, arXiv preprints, Oxford, IEEE disclaimers, and draft version footers like `Draft (2024-01-15) of "Mathematics for Machine Learning". Feedback: https://mml-book.com.`) as `.pageFooter`.
  - **Two-Pass Cross-Page Repetition Analysis**: Pre-analyzes candidate text in header and footer bands across the entire document; recurring strings (book/chapter titles, author names, Roman numeral frontmatter like `ii Contents`) across multiple pages are classified as `.pageHeader` and `.pageFooter`.
  - **Caption & Footnote Detection**: Recognizes figures, tables, charts, and photos (`Figure 1:`, `Table 4:`) and footnote superscripts/markers (`*`, `†`, numbered), isolating them into distinct `BlockType` objects.
  - **Sidenote & Marginalia Column Separation (`ParagraphDetector`)**: Analyzes horizontal line distribution to detect narrow margin columns (e.g. video links, tips, and lecture notes in textbooks like *Mathematics for Machine Learning*). Margins are separated into `.sidenote` blocks rather than interleaved mid-sentence into main body text.
  - **Table of Symbols & Notation Detection**: Automatically identifies frontmatter/appendix notation tables and summary pages, tagging entries as `.symbolTable`.
  - **User-Configurable Audio Skipping**: Configurable in **Reading Settings** with individual toggles for skipping running headers & footers, page numbers, footnotes, captions, sidenotes & margin notes, and notation & symbol tables so audio narration flows smoothly and naturally.
- **📜 Multi-Layout PDF Display Modes (`PDFDisplayLayoutMode`)**:
  - **Single Page**: Classic horizontal swipe/turn navigation with `UIPageViewController`.
  - **Continuous Scroll**: Vertical smooth scrolling for long reading sessions and academic papers.
  - **Two-Page Spread**: Side-by-side book spread ideal for landscape iPad and Mac reading.
  - **Continuous Spread**: Side-by-side pages with continuous vertical scrolling.
  - **Quick Switcher Menu**: One-tap layout menu in the Reader header bar with instant switching.
  - **Rock-Solid Continuous Scroll Highlighting**: Synchronized via KVO content offset tracking on PDFView's internal scroll hierarchy, ensuring highlights move smoothly in real-time without disappearing or lagging. Overlay CALayers are kept frontmost above all PDF views.
  - **Multi-Page Sentence Span Highlighting**: Accurately projects sentence bounds across all visible pages in two-page and continuous scrolling modes.
  - **Human-Centered Auto-Scroll & Free Reading Flow (`AutoScrollFollowMode`)**:
    - **Pause-on-Scroll Lifecycle & Zero Snap-Back**: When listening to speech, initiating a manual scroll immediately pauses the built-in auto-scrolling engine. Users are completely free to scroll ahead or back across multiple pages without the viewport being forcefully yanked back to the active highlight. The viewport strictly stays wherever the user scrolls and stops.
    - **Interactive "Auto-Scroll" Prompt Capsule**: When scrolled away from the active sentence, a compact floating capsule appears (`[ ⬆ / ⬇ Spoken text is above/below • P. X • Auto-Scroll ▶ ]`) with a real-time spoken sentence snippet and directional indicator. It uses an intrinsic-width capsule centered above the playback bar to keep document text clearly visible. Tapping **Auto-Scroll** smoothly navigates directly back to the active spoken sentence and unpauses continuous auto-scroll. If the user manually scrolls all the way back to the sentence and stops, auto-follow unpauses automatically.
    - **State Loop Isolation**: `PDFReaderView` isolates internal `PDFView` scroll offset changes from external navigation triggers via `lastHandledPageIndex`, `isProgrammaticScroll`, and touch-state tracking (`isUserScrolling`), preventing SwiftUI view re-renders from triggering unwanted programmatic snaps.
    - **User-Configurable**: Three selectable modes in **Reading Settings**: `Prompt When Scrolled (Free Scroll)`, `Always Follow`, and `Off`.
  - **PDFKit Hit-Test Sanitization (`PDFDocumentViewHitTestSanitizer` & `VachanamPDFView`)**:
    - Intercepts internal PDFKit hit-testing on Mac Catalyst and iPadOS pointer interactions to eliminate UIKit `Invalid returned hit test result for view in hierarchy: <PDFAnnotationPointerTrackingView>` console error assertions while preserving normal annotation interaction.
- **📐 Mathematical & Academic Speech Intelligence (`TextNormalizer`)**:
  - **Vector Arrow Notations**: Recognizes all forms of vector arrows generated by LaTeX and PDF typographers: combining vector arrow above (`x⃗` $\to$ `vector x`), inline vectors (`→x`, `→y` $\to$ `vector x`, `vector y`), multi-arrow stacking artifacts (`→→x` $\to$ `vector x`), and math-minus arrow representations (`−→ x` $\to$ `vector x`).
  - **Superscripts, Exponents & Carets**:
    - Squares & cubes: `x^2`, `x²`, `(x+y)^2` $\to$ `x squared`, `(x+y) squared`; `x^3`, `x³`, `(x+y)^3` $\to$ `x cubed`.
    - Transpose & Inverses: `A⊤`, `Aᵀ`, `A^T`, `A^⊤`, `(AB)⊤` $\to$ `transpose`; `A^-1`, `A⁻¹`, `A^{-1}` $\to$ `inverse`; `A^-T` $\to$ `inverse transpose`.
    - Exponents: `x^{n+1}` $\to$ `x to the power of n+1`, `x^n`, `x^k`, `z^n`, `10^5` $\to$ `x to the n`, `x to the k`, `z to the n`, `10 to the 5`.
    - Carets & Hats: Isolated carets before variables (`^x` $\to$ `x hat`), isolated carets after single variables (`y^` $\to$ `y hat`), and combining hat accents (`x̂` $\to$ `x hat`).
  - **Accents, Subscripts & Matrix Dimensions**:
    - Bars & Tildes: `x̄` $\to$ `x bar`, `x̃` $\to$ `x tilde`.
    - Primes & Stars: `x'` $\to$ `x prime`, `x''` $\to$ `x double prime`, `x*` $\to$ `x star`.
    - Subscripts: `x_1` $\to$ `x sub 1`, `x_i` $\to$ `x sub i`, `W_ij` $\to$ `W sub ij`, and Unicode subscripts `x₀`–`x₉`, `xᵢ`, `xⱼ`, `xₖ`.
    - Norms & Inner Products: `‖x‖` $\to$ `the norm of x`, `⟨x, y⟩` $\to$ `the inner product of x and y`.
    - Matrix Dimensions: `Rn×n` $\to$ `R n by n`, `Rm×n` $\to$ `R m by n`, `(n,n)-matrices` $\to$ `n by n matrices`.
  - **Attached Math Variable Separation**: Corrects PDF font-change extraction artifacts where single math variables fuse to adjacent English words (`ycan` $\to$ `y can`, `xand` $\to$ `x and`, `Aas` $\to$ `A as`, `bor` $\to$ `b or`).
  - **Hyphen vs. Minus Disambiguation**: Intelligently distinguishes mathematical subtraction (`x - y`, `x − y`, `5-3` $\to$ `minus`) from hyphenated identifiers, model codes, and statistical terms (`Kokoro-82M`, `BERT-base`, `t-test`, `k-fold`), preserving hyphenated names without distortion.
  - **Greek Letters**: Speaks all 48 uppercase and lowercase Greek letters (`α` $\to$ `alpha`, `β` $\to$ `beta`, `λ` $\to$ `lambda`, `θ` $\to$ `theta`, `σ` $\to$ `sigma`, `π` $\to$ `pi`, `ω` $\to$ `omega`).
  - **Blackboard Bold & Vector Spaces**: Normalizes coordinate spaces and sets (`ℝⁿ` $\to$ `R n`, `ℝ³` $\to$ `R three`, `ℝ` $\to$ `the real numbers`, `ℕ` $\to$ `the natural numbers`, `ℤ` $\to$ `the integers`, `ℂ` $\to$ `the complex numbers`).
  - **Extended Math Operators**: Fluent conversions for set and logic operators (`∈` $\to$ `in`, `∉` $\to$ `not in`, `⊆` / `⊂` $\to$ `subset of`, `∩` $\to$ `intersection`, `∪` $\to$ `union`, `∅` $\to$ `empty set`, `∀` $\to$ `for all`, `∃` $\to$ `there exists`, `→` $\to$ `to`, `↦` $\to$ `maps to`, `⟹` / `⇒` $\to$ `implies`, `⟺` / `⇔` $\to$ `if and only if`, `∑` $\to$ `sum of`, `∏` $\to$ `product of`, `∂` $\to$ `partial`, `∇` $\to$ `gradient`, `√` $\to$ `square root of`, `∫` $\to$ `integral of`).
  - **Number-Variable Adjacency**: Separates mathematical expressions like `0.5x` $\to$ `0.5 x` and `2.0y` $\to$ `2.0 y` so neural TTS pronounces both the number and variable distinctly without swallowing or skipping tokens.
  - **Decimal Sentence Boundary Protection**: Automatically protects decimal numbers (`2.0`, `0.5`, `1.5`) from being split as false sentence terminations by the NaturalLanguage sentence tokenizer.
  - **Equation Label Detection**: Converts end-of-equation references like `Ax = b (2.1)` into natural `equation 2.1`.
- **🔬 Standardized Speech Rule Engine (SRE), MathSpeak & Scientific Notation (`MathSpeechEngine`)**:
  - **Standardized Speech Rule Engine (SRE) Mappings**: Implements international accessibility standards for mathematics and scientific literature with comprehensive bundled mathmaps in `Vachanam/Resources/MathMaps/`:
    - `scientific_notation.json`: Regular expression engines and ordinal/cardinal speech patterns for standard $e$-notation and explicit power-of-ten scientific notation.
    - `symbols.json`: Complete Speech Rule Engine vocalization dictionary for relation glyphs, calculus operators (`∫`, `∬`, `∭`, `∮`, `∂`, `∇`), logic quantifiers (`∀`, `∃`, `∄`, `∧`, `∨`, `¬`, `⟹`, `⟺`), set theory (`∈`, `∉`, `⊆`, `⊂`, `⊇`, `⊃`, `∪`, `∩`, `∅`), and algebraic symbols.
    - `functions.json`: Trigonometric, hyperbolic, logarithmic, linear algebra, limits (`lim_{x \to 0}` $\to$ `limit as x approaches 0 of`), and optimization functions (`sin`, `cos`, `tan`, `sinh`, `ln`, `det`, `rank`, `argmax`, `argmin`).
    - `greek.json`: Standardized Greek alphabet mappings with uppercase/lowercase distinctions.
    - `si_units.json`: Complete International System of Units (SI) metric prefixes and compound units.
    - `latex_macros.json`: Native academic LaTeX macro speech translations (`\frac`, `\sqrt`, `\sum`, `\int`, `\prod`, `\mathbf`, `\mathbb`, `\mathcal`, `\text`).
  - **Scientific Exponential Notation**: Automatically parses and converts mantissas and exponents into natural spoken phrases (e.g. `6.022e23` $\to$ `six point zero two two times ten to the power of twenty-three`, `1.5E-4` $\to$ `1.5 times ten to the minus four`, `-3e-9` $\to$ `negative 3 times ten to the minus nine`, `3.0 x 10^8` $\to$ `3.0 times ten to the eighth`).
  - **Number-Adjacent SI Units & Metric Prefixes**: Intelligently expands metric units and prefixes when preceded by numbers while evaluating singular vs. plural grammar (e.g. `5 nm` $\to$ `5 nanometers`, `1 nm` $\to$ `1 nanometer`, `2.4 GHz` $\to$ `2.4 gigahertz`, `100 ms` $\to$ `100 milliseconds`, `12 V` $\to$ `12 volts`, `500 mA` $\to$ `500 milliamperes`, `120 km/h` $\to$ `120 kilometers per hour`, `9.8 m/s²` $\to$ `9.8 meters per second squared`). Regular English words without preceding numbers (`a ms`, `to V`, `in a m`) are strictly preserved without false-positive expansion.
  - **Linear Algebra Equations, Subscripts & Ellipses (`MathSpeechEngine`)**:
    - **Linear Combination Vocalization**: Accurately normalizes linear algebra equations without LaTeX markup (e.g., `a11x1 +···+ a1nxn= b1` $\to$ `a 1 1, x 1, plus and so on, plus a 1 n, x n, equals b 1` in Conversational style, or `a sub 1 1, x sub 1, plus ellipsis, plus a sub 1 n, x sub n, equals b sub 1` in MathSpeak Rigorous style).
    - **Midline Operator Ellipses**: Translates midline operator ellipses (`+···+`, `+⋯+`, `+...+`) into natural speech (`plus and so on, plus` / `plus ellipsis, plus`).
    - **Index Sequences**: Converts sequences (`x1,...,xn` $\to$ `x 1 through x n`, `R1,..., R m` $\to$ `R 1 through R m`).
    - **Double-Index Matrix Elements**: Digit-by-digit vocalization for matrix entries (`a11` $\to$ `a 1 1`, `a12` $\to$ `a 1 2`, `a21` $\to$ `a 2 1`, never reading them as cardinal numbers like "a eleven").
    - **Fused Variable Separation**: Distinguishes mathematical coefficients and variables (`a11x1` $\to$ `a 1 1, x 1`, `a1nxn` $\to$ `a 1 n, x n`, `am1x1` $\to$ `a m 1, x 1`, `amn xn` $\to$ `a m n, x n`, `xj` $\to$ `x j`, `bm` $\to$ `b m`) while safeguarding common English words (`text`, `next`, `exit`, `in`, `am`, `an`) and industry acronyms (`AI`, `BI`).
  - **Academic LaTeX Macro Translator**: Translates mathematical markup without requiring a heavy WebView or external JavaScript runtime:
    - Fractions: `\frac{a}{b}` $\to$ `a over b` (Conversational) / `start fraction, a, divided by, b, end fraction` (MathSpeak Rigorous).
    - Roots: `\sqrt{x}` $\to$ `square root of x`, `\sqrt[3]{8}` $\to$ `the 3rd root of 8`.
    - Sums & Integrals: `\sum_{i=1}^{n}` $\to$ `sum from i=1 to n of`, `\int_{a}^{b}` $\to$ `integral from a to b of`.
    - Typographic delimiters: `\left(`, `\right)`, `\left[`, `\right]`, `\left\{`, `\right\}` normalized cleanly.
  - **Matrix, Determinant & Vector Vocalization (`MathSpeechEngine.vocalizeMatrices`)**:
    - **Explicit LaTeX Matrices (`bmatrix`, `pmatrix`, `matrix`)**: Converts multi-dimensional arrays into natural speech describing matrix dimensions and rows:
      - Conversational: `2 by 2 matrix with rows: row 1, 1, 2; row 2, 3, 4`.
      - MathSpeak Rigorous: `start 2 by 2 matrix, row 1, column 1, 1, column 2, 2, row 2, column 1, 3, column 2, 4, end matrix`.
    - **Determinants (`vmatrix`)**: Recognizes absolute vertical bar delimiter matrices as determinants: `determinant of a 2 by 2 matrix with rows: row 1, a, b; row 2, c, d`.
    - **Column & Row Vectors**: Distinct phrasing for single-column arrays: `column vector with elements x sub 1, x sub 2, x sub 3`.
  - **User-Configurable Speech Styles (`MathSpeechStyle`)**:
    - **Conversational** (Default): Optimized for natural audio flow and audiobook listening (e.g., `1 over 2`, `5 nanometers`, `x squared`).
    - **MathSpeak Rigorous**: Adheres strictly to international academic screen-reader standards for visually impaired mathematicians (e.g., `start fraction, 1, divided by, 2, end fraction`, `capital Delta`, `element of`, `universal quantifier, for all`).
    - Configurable in **Reading Settings** with instant persistence.
  - **Full Pronunciation Override Integration**: Respects user-defined rules in `PronunciationManager` / `FixPronunciationSheet`, allowing personalized phonetic overrides to take precedence over default math vocalizations.
- **📚 The Ultimate Multi-Discipline TTS Benchmark Document (`The_Ultimate_Multi_Discipline_TTS_Benchmark.pdf`)**:
  - Bundled directly inside the application bundle (`Vachanam/Resources/Benchmark/The_Ultimate_Multi_Discipline_TTS_Benchmark.pdf`) and automatically ingested into the reader library on launch (`AppState.shared.currentDocument`) for instantaneous testing.
  - Dedicated **"Benchmark PDF"** button in the Document Library toolbar and empty state.
  - An exhaustive, 4-page high-fidelity vector PDF specifically crafted to stress-test neural TTS prosody, math vocalization, scientific metrics, and normalization across four distinct disciplines with publication-quality typography (clean mathematical symbols, matrices, determinants, and units without unrendered LaTeX artifacts):
    - **Section 1: The Novel (Dialogue, Punctuation & Prosody)**: Suspense mystery fiction assessing dialogue cadence, em-dashes (`—`), elliptical pauses (`...`), interjections (`Crash!`), honorific titles (`Dr. Alistair`, `Insp. Clara Vance`), and natural contraction vocalization (`didn't`, `couldn't`).
    - **Section 2: Pure Mathematics & Formal Notation**: Linear algebra and multivariable calculus formatted with publication-quality mathematical notation: explicit matrices (`[ 3 -1 ; 2 4 ]`), determinants (`det(A) = | 3 -1 ; 2 4 | = 14 ≠ 0`), column vectors (`x⃗ = [x₁, x₂, ⋮, xₙ]ᵀ ∈ ℝⁿ`), Singular Value Decomposition (`A = U Σ Vᵀ = ∑ σᵢ u⃗ᵢ v⃗ᵢᵀ`), Frobenius norms (`‖A‖_F`), tensor Kronecker products (`A ⊗ B`), direct sums (`V ⊕ W`), and Stokes' theorem (`∮ F⃗ · dr⃗ = ∬ (∇ × F⃗) · dS⃗`).
    - **Section 3: Empirical Science, SI Units & Measurements**: Physical chemistry and experimental physics assessing fundamental constants ($h, \hbar, k_B, \sigma, \varepsilon_0, N_A, e, c, g$), ultracentrifugation protocols ($14,000\text{ rpm}$, $250\text{ mg}$, $15.5\text{ mL}$, $50\text{ \mu L}$, $0.25\text{ M}$, $15\text{ mM}$), cryogenic temperatures ($-196^\circ\text{C}$), and high-frequency microwave electronics ($2.4\text{ GHz}$, $50\text{ \Omega}$, $100\text{ ms}$).
    - **Section 4: Academic Prose, Citations & Normalization**: Peer-reviewed linguistics and acoustic modeling assessing parenthetical citations (`Vaswani et al., 2017`, `Radford & colleagues, ca. 2022`), Latin scholarly apparatus (`ibid.`, `op. cit.`, `cf.`, `viz.`, `q.v.`), legal section symbols (`§ 2.1`, `¶ 3`), DOIs, arXiv URLs, statistical significance ($p < 0.001$), multi-currency acquisitions (`$4,500`, `€3,200`, `£1,850`, `¥250,000`, `₹75,000`), and fractional portions (`¾`, `⅞`).
  - **Dynamic Sandbox Cache Invalidation**: `DocumentLibraryView.ensureBenchmarkDocumentExists()` automatically detects bundle/resource size differences and refreshes the sandbox documents directory copy, preventing stale builds from lingering in the user's active document cache.
- **📑 Paragraph Integrity & Run-In Heading Segmentation (`ParagraphDetector`)**:
  - **Tight LaTeX Indentation Detection**: Academic textbooks formatted with Computer Modern LaTeX often employ `\parindent \approx 10\text{pt}` and `\parskip = 0`. Uses content column left-margin anchoring (`currentLine.minX >= baseMargin + 5.0pt`) combined with short terminal previous lines (`previousLine.maxX < columnMaxX - 25.0pt`) and terminal punctuation (`.`, `?`, `!`, `:`) to reliably segment consecutive paragraphs without collapsing entire pages.
  - **Displayed Math & Equation Continuation Protection**: Displayed equations, indented formula lines, superscripts (`−1`, `T`, `⊤`), and continuation lines (e.g. starting with `+`, `−`, `=`, `,`, `where`, `with`, `and`) are recognized as integral parts of their enclosing sentences. They are protected from premature paragraph breaks despite LaTeX vertical display gaps, preventing mathematical text from shattering into isolated 1-word fragments.
  - **Short Terminal Line Retention**: Verifies that short lines at the bottom of paragraphs (e.g. `from data.`) are never misclassified as margin notes or sidenotes by inspecting gutter crossing lines and vertical baseline continuity.
  - **Run-In Bold Headings**: Correctly identifies same-baseline bold heading fragments (e.g., `Astute Listener`, `Experienced Artist`, `Fledgling Composer`) that precede paragraph bodies on the same horizontal line, joining them with a period delimiter (`. `) to ensure natural TTS phrasing and pause acoustics.
  - **Indentation Continuation Safeguards**: Prevents math continuation lines ending in operators (`→`, `+`, `=`) or conjunctions (`and`, `where`, `such that`) from being prematurely isolated as section headings.
- **🖼️ Image OCR & Graph Accessibility Foundation (`ImageContentExtractor` & `AudioGraphDescriptor`)**:
  - Built-in Vision framework OCR infrastructure for extracting embedded labels from figures and raster diagrams.
  - Audio chart description engine producing accessible data ranges and summaries for graphs and plots.
- **Layered Pronunciation Dictionary System (`PronunciationManager`)**:
  - Three-tier hierarchy: **Global** (common acronyms & phonetics), **Book-specific** (character names, domain terminology), and **User overrides** (custom fixes).
  - Employs case-insensitive word-boundary regex substitution (`\b(word)\b`) and revision hashing for automatic audio cache invalidation.
- **Interactive Pronunciation Correction (`FixPronunciationSheet`)**:
  - Accessible directly from the TTS Control Bar (`Fix Pronunciation` button) or context menu.
  - Allows users to enter phonetic respellings with instant speech preview and automatic cache purging.
- **Monotonic Highlighting Clock & Compound Word Alignment**:
  - **Strict 1:1 `targetWords` Contract**: Passes segmented document `SemanticWord` tokens (split via `NLTokenizer`) directly to the TTS adapter (`KokoroAdapter.synthesize(..., targetWords:)`). Compound words like `Word-by-word`, `on-device`, and `distraction-free` receive distinct, individual word timestamps that match their precise PDF bounding boxes, completely eliminating index shifts.
  - **Sentence-Level Boundary Isolation & Authoritative PDFKit Line Selections**: Eliminates sentence highlight bleeding across adjacent sentences. Word search in `SentenceSegmenter` is strictly bounded to the character window of each individual sentence, preventing forward search offsets from drifting into adjacent sentences. Computes authoritative typographic line bounds directly from PDFKit's `page.selection(for: sentencePageRange).selectionsByLine()` so sentences sharing a visual line are cleanly isolated without bleeding. Word bounding boxes are validated against sentence Y-bounds, and defensive runtime checks in `PlaybackCoordinator.setCursor` prevent anomalous single-line highlight heights.
  - **Apple TTS Spoken Word Mapping**: Builds precise sequential character-range mappings (`spokenWordRanges`) within the spoken string for Apple TTS (`AVSpeechSynthesizer`), supporting both full-chunk and partial mid-chunk playback without range mismatch or highlighting freeze.
  - **Vsync-Aligned `CADisplayLink` Playback Clock**: Upgraded playback progress updates from a 25fps (40ms) timer to a display-synchronized `CADisplayLink` on iOS and Mac Catalyst (with 60fps fallback for headless tests), delivering fluid 60Hz/120Hz ProMotion word tracking with zero visual jitter even at 2.0x playback speed.
  - **Paragraph-Bounded Coordinate Isolation**: Word bounding boxes are strictly confined within their respective paragraph's character boundaries and visual frame. Common words ("the", "is", "matrix", "vector", "are", "data", "regression") never bleed highlights into other paragraphs on the page.
  - **CALayer Reuse & QuartzCore Optimization**: Highlights in `PDFHighlightOverlayView` reuse allocated CALayers and toggle visibility (`isHidden = true`) instead of repeatedly adding and removing sublayers on every word change, eliminating CoreAnimation handler-drop overhead and rendering lag.
  - **Mac Catalyst Window Compatibility**: Configured `UIDesignRequiresCompatibility` in `Info.plist` and `OS_ACTIVITY_MODE = disable` in Xcode schemes to prevent cross-process window server fence drops (`cannot add handler to X from Y - dropping`) and suppress benign Apple internal daemon noise (`linkd`, `DetachedSignatures`, `AudioAnalytics`).
  - **High-Velocity Scroll Performance**: Optimized highlight overlay coordinate updates (`updateHighlights`) to prune calculations to currently visible pages (`visibleIndices`), avoiding CPU bottlenecks during rapid fling-scrolling. CoreGraphics asynchronous PDF tile cancellations during high-speed scrolling are handled gracefully without visual artifacts or memory bloat.
  - **Inter-Word Gap Holding**: In-flight binary search smoothly holds the preceding word's highlight during acoustic gaps rather than jumping back to the beginning of the chunk.
  - **Calibrated Drift Telemetry**: Accurately measures audio drift outside actual word time intervals `[startTime, endTime]`, logging warnings only when true timing desynchronization (>150ms) occurs.
- **Stable Global Word Indexing (`globalWordID`)**: Every word receives a persistent, monotonic global identity across the entire document. Navigating between pages or selecting words on different pages never gets stuck or invalidates position.
- **Instant Tap-to-Speak & Synchronized Mid-Sentence Seeking**: Tap any word directly on the PDF page or in Reader View to immediately begin narration and visual highlighting from that exact word. Halts previous audio instantly, resolves page coordinates via native PDFKit hit testing, and executes 0ms seeking if tapping within the currently active chunk. `AudioPlayer` guarantees precise start offset alignment by preparing the playback session prior to setting `currentTime` (preventing AVFoundation's `prepareToPlay()` from resetting the playback head to 0.0s), ensuring audio and karaoke highlighting start strictly together from the clicked word. Fast-path seeking within active chunks checks `hasActiveAudioPlayer` to ensure seamless intra-chunk seeks without desynchronization.
- **Rolling TTS Pre-Generation & Content-Hashed Cache**: While Chunk $N$ plays, Chunk $N+1$ is pre-generated in the background without CPU/Core ML contention and stored in a non-blocking two-tier in-memory/disk cache (`TTSAudioCache`). Instant, gapless playback on chunk transitions and repeated visits without Swift Concurrency thread blocking.
- **Stage-by-Stage Profiling & Telemetry**: `TTSMetricsLogger` exposes timing metrics for text processing, Misaki phonemization, Core ML model inference, and audio post-processing alongside the Real-Time Factor (RTF).
- **Model Lifecycle & Pre-Warming**: Kokoro Core ML models remain alive in memory and are pre-warmed upon initialization to avoid cold-start compilation stutter when the user presses Play.
- **CoreGraphics & CoreText PDF Log Sanitization (`PDFLoggingSanitizer`)**:
  - **Elimination of Console Log Flooding**: Eliminates the flood of unbuffered low-level diagnostic messages written to `stderr` and `stdout` by Apple's CoreGraphics, CoreText, and PDFKit engines when rendering, navigating, or extracting text from PDFs (e.g. `.notdef: no mapping.`, `mapsto: no mapping.`, `summationtext: no mapping.`, `parenleftbig: no mapping.`, `radicalbig: no mapping.`, `CGPDFImage(...): subsample_factor MISMATCH`, `CTLD took ...s`, and PDFPageAnalyzer's `New text range needs to be within the original node's text range`).
  - **Asynchronous POSIX Pipe Interceptor**: Employs non-blocking POSIX pipe redirects (`dup2` with `DispatchSourceRead` on a background utility queue) attached to `STDERR_FILENO` and `STDOUT_FILENO` that pattern-match and silently discard benign font-mapping, page layout, and image-caching noise while forwarding all genuine assertions, fatal errors, profiler metrics, and diagnostic messages to the original console outputs.
  - **Scheme & Environment Neutralization**: Strips `CG_PDF_VERBOSE` from Xcode scheme configurations and process environment (`unsetenv("CG_PDF_VERBOSE")`), preventing CoreGraphics' `PDFPageAnalyzerV2` from triggering spurious verbose text range analysis logs.
  - **Scoped Synchronous Silencer**: Automatically wraps batch extraction passes in `TextExtractor.extractSentences(from:pageIndex:)` using `PDFLoggingSanitizer.suppressingStderr { ... }` to prevent TTY / LLDB console bottlenecking from causing frame drops or UI stuttering during background document ingestion.
  - **Unmapped Font Glyph & Artifact Cleaning**: Strips Unicode replacement characters (`\u{FFFD}`), unprintable control characters, and Private Use Area (PUA) codepoints emitted by unmapped TeX math font CMaps in `TextNormalizer.normalize(_:)`, ensuring Kokoro TTS and Apple TTS vocalizers never stutter or pronounce garbled phonemes on mathematical formula boundaries.
- **Dual Reading Modes**:
  - **Original PDF Layout**: Native PDFKit rendering with interactive overlays.
  - **Reader View Mode**: Re-rendered typography with custom fonts, line heights, and margins.
- **Continuous Scroll Architecture & Non-Blocking Interaction (`PDFReaderView` & `ReadingRuler`)**:
  - **Default Continuous Vertical Layout**: Configured `.singlePageContinuous` as the out-of-the-box layout mode (`AccessibilityManager.pdfDisplayLayout`), providing seamless multi-page vertical scrolling across the entire document without page boundaries locking or snapping.
  - **Pass-Through Reading Ruler Dimmers**: Top and bottom dimmer backdrops in `ReadingRuler` use `.allowsHitTesting(false)` so they function purely as visual contrast guides without intercepting or swallowing mouse wheel ticks, trackpad gestures, or touch scrolls on the document beneath.
  - **Mac Catalyst Trackpad & Wheel Scroll Detection**: Tracks high-resolution `lastUserScrollTime` deltas via `UIScrollView.contentOffset` key-value observations, guaranteeing that discrete wheel events on macOS Catalyst accurately register `isUserScrolling = true` (overcoming UIKit Catalyst's limitation where `isDragging` remains false during mouse wheel scrolling), completely preventing unwanted snap-backs.
  - **Modal Annotation Layer Isolation**: `ShapeToolView` and `CanvasOverlay` strictly isolate touch reception via `.allowsHitTesting(activeAnnotationTool == ...)`, ensuring drawing canvases never block underlying document scrolling when inactive.
- **Accessibility Suite**:
  - **OpenDyslexic Typography**: Integrated font support with weighted baselines.
  - **Reading Ruler**: Adjustable tinted guide bar with customizable height, opacity, and drag handle.
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
│   │   │   ├── PDFReaderView.swift         # PDFKit UIViewRepresentable wrapper with multi-layout support
│   │   │   ├── PDFDisplayLayoutMode.swift  # Display mode enum (Single Page, Continuous Scroll, Two-Up)
│   │   │   ├── ReaderTextView.swift        # Typography view with live inline highlights
│   │   │   ├── ReadingModeToggle.swift     # Capsule switch (PDF vs Reader View)
│   │   │   ├── PageThumbnailGrid.swift     # Visual thumbnail grid for quick scrubbing
│   │   │   └── TOCView.swift               # Table of Contents and Bookmarks drawer
│   │   ├── TTS/
│   │   │   ├── TTSControlBar.swift         # Play/pause, speed, voice picker, soundscape, sleep timer, fix pronunciation
│   │   │   ├── VoicePickerView.swift       # Voice selection and model picker sheet
│   │   │   ├── SoundscapePickerSheet.swift # Ambient focus soundscapes picker with live volume & study mode
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
│   │   ├── Generator/
│   │   │   └── AudiobookGeneratorView.swift # Mac Audiobook Studio for pre-generating audiobook bundles
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
│   │   ├── AudiobookGenerator.swift        # Batch audiobook pre-generator with microsecond word timings
│   │   ├── AudiobookManifest.swift         # Manifest & chunk timings data models
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
│   │   ├── PreGeneratedPlaybackAdapter.swift # Zero-latency pre-generated audiobook playback adapter
│   │   ├── Qwen3TTSAdapter.swift           # Qwen3-TTS 0.6B CoreML adapter
│   │   ├── ChatterboxAdapter.swift         # Chatterbox Turbo CoreML adapter
│   │   ├── CosyVoice3Adapter.swift         # CosyVoice 3 0.5B MLX adapter
│   │   └── G2P/
│   │       ├── G2PProtocol.swift           # Phonemizer protocol
│   │       └── MisakiG2P.swift             # Misaki English phonemizer
│   │
│   ├── Document/
│   │   ├── DocumentFormat.swift            # Format detection (PDF, EPUB, Markdown, Plain Text, Web Article)
│   │   ├── SemanticDocument.swift          # Complete 3-layer document model & fast lookups
│   │   ├── SemanticDocumentBuilder.swift   # Universal parsed document to SemanticDocument bridge
│   │   ├── WordReconstructor.swift         # Line-break hyphen joining & compound word preservation
│   │   ├── TextNormalizer.swift            # Whitespace, ligature, and symbol-to-speech cleaner
│   │   ├── PageFurnitureDetector.swift     # Running header/footer, page number, caption & footnote detector
│   │   ├── ParagraphDetector.swift         # Visual line clustering & semantic block detector
│   │   ├── SentenceSegmenter.swift         # NLTokenizer sentence & word bounding box parser
│   │   ├── TTSChunker.swift                # 10-25 word semantic chunk generator with boundary pauses
│   │   └── Parsers/
│   │       ├── DocumentParser.swift        # Parser protocol & ParsedDocument models
│   │       ├── DocumentParserResolver.swift # Format-to-parser resolver
│   │       ├── EPUBParser.swift            # EPUB container, OPF spine & XHTML extractor
│   │       ├── ZipArchive.swift            # Lightweight PKZip reader & deflate decompressor
│   │       ├── MarkdownParser.swift        # Headings, lists, blockquotes & paragraph parser
│   │       ├── PlainTextParser.swift       # Paragraph delimiter & title detector
│   │       └── WebArticleParser.swift      # HTML readability extractor via URLSession
│   │
│   ├── Audio/
│   │   ├── AudioPlayer.swift               # AVAudioEngine streaming player
│   │   ├── AmbientSoundscapePlayer.swift   # Procedural ambient soundscape player (Brown, Pink, 40Hz, Rain, Library)
│   │   ├── AudioEncoder.swift              # Raw PCM to AAC .m4a converter (AVAssetWriter)
│   │   ├── iCloudSyncManager.swift         # Pre-generated audiobook sync & manifest manager
│   │   ├── AudiobookBundleLoader.swift     # Bundle reader for pre-generated audiobooks
│   │   ├── AudioSession.swift              # Background audio & MPRemoteCommandCenter
│   │   ├── TTSAudioCache.swift             # Content-hashed two-tier audio cache
│   │   └── SleepTimer.swift                # Sleep timer logic
│   │
│   ├── PDF/
│   │   ├── TextExtractor.swift             # Sentence & word bounding box extractor
│   │   ├── ReaderDocument.swift            # Multi-format document wrapper & TOC
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
│   │   ├── Soundscapes/                    # 5 bundled ambient audio loops (.m4a)
│   │   └── Assets.xcassets                 # AccentColor & AppIcon
│   │
│   └── Info.plist                          # Background audio, document types, file sharing
│
├── VachanamTests/
│   ├── TTSTests/
│   │   ├── AmbientSoundscapeTests.swift    # Soundscape presets, persistence & study mode tests
│   │   ├── TTSModelProtocolTests.swift     # Model synthesis & timestamp tests
│   │   ├── ModelManagerTests.swift         # Registry & active model tests
│   │   ├── DeviceCapabilityTests.swift     # RAM tier compatibility tests
│   │   ├── TTSAudioCacheTests.swift        # Content-hashed cache tests
│   │   ├── PlaybackCoordinatorTests.swift  # Task cancellation & word jump tests
│   │   ├── PronunciationManagerTests.swift # 3-tier dictionary & regex word-boundary tests
│   │   └── TTSChunkerQualityTests.swift    # Block isolation & trailing pause assignment tests
│   ├── DocumentTests/
│   │   ├── EPUBParserTests.swift           # EPUB container & spine extraction tests
│   │   ├── MarkdownParserTests.swift       # Markdown block parsing tests
│   │   ├── PlainTextParserTests.swift      # Plain text paragraph detection tests
│   │   ├── WebArticleParserTests.swift     # HTML readability extraction tests
│   │   └── SemanticDocumentBuilderTests.swift # ParsedDocument to SemanticDocument bridge tests
│   ├── AudioTests/
│   │   ├── AudiobookManifestTests.swift    # Manifest JSON serialization tests
│   │   ├── iCloudSyncTests.swift           # Bundle discovery & hash tests
│   │   └── AudiobookGeneratorTests.swift   # Pre-generated playback adapter tests
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
- **Mac Catalyst Crash: "-[PDFPage rvItemAtPoint:]: unrecognized selector sent to instance"**:
  - Occurs on macOS Sequoia / Mac Catalyst when tapping a PDF page if invoking PDFKit's legacy `selectionForWord(at:)` API. In Mac Catalyst, Apple's UIKit-to-AppKit PDFKit bridge forwards word hit-testing to an internal AppKit lookup selector (`rvItemAtPoint:`, intended for macOS Dictionary/QuickLook popovers) which is missing on the bridged iOS `PDFPage` instance, raising a fatal `NSInvalidArgumentException`.
  - Fix: Vachanam uses pure-Swift spatial hit testing on `SemanticDocument.findWord(at:onPageIndex:hitPadding:maxSearchRadius:)` with bounding box containment and calibrated distance fallbacks. Calling `selectionForWord(at:)` has been completely eliminated from `PDFReaderView`, guaranteeing zero-crash tap-to-speak across both iPad and Mac Catalyst.
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
8. **`MetalToolchain` / `cryptexd` Linker Warning (Mac Catalyst & Previews)**:
   - `ld: warning: search path '/var/run/com.apple.security.cryptexd/mnt/.../Metal.xctoolchain/usr/lib/swift/maccatalyst' not found`:
     - **Cause**: An upstream Apple Clang/Xcode 16 toolchain behavior on macOS Sequoia when building Mac Catalyst targets and SwiftUI Previews (`__preview.dylib`). The compiler driver automatically injects the mounted Metal toolchain cryptex library search path (`-L.../maccatalyst`). Because Apple's cryptex image only packages `usr/lib/swift/macosx` (with Catalyst runtime libraries located in `/System/iOSSupport/usr/lib/swift`), `ld` reports this directory not found.
     - **Impact**: **Completely harmless**. The linker immediately skips the missing directory and links against the correct system runtime. The build completes with code 0 (`Activity Log Complete`) in ~3 seconds, with zero link errors or missing symbols. No project change is required.
9. **`AddInstanceForFactory` / `CoreAudio HAL Factory` (CoreFoundation / CFBundle)**:
   - `AddInstanceForFactory: No factory registered for id <CFUUID ...> F8BB1C28-BAE8-11D6-9C31-00039315CD46` is emitted by Apple's CoreAudio Hardware Abstraction Layer when discovering system audio hardware and AudioUnit driver plug-ins. It is standard Apple diagnostic logging and has zero impact on audio playback.
10. **`libsqlite3` / `open(/private/var/db/DetachedSignatures)`**:
    - Emitted by SQLite when initializing system caches. macOS queries the optional detached code signatures database, which does not exist on consumer macOS installations. SQLite safely continues.
11. **`AudioAnalytics` / `carc` / `Reporter disconnected`**:
    - Emitted by Apple's internal `AudioAnalytics` framework when local audio sessions initialize without transmitting usage analytics to Apple.
12. **`BaseBoard` / `Unable to obtain a task name port right`**:
    - Emitted by Apple's `BaseBoard` framework when verifying Mach port task rights across windowing processes within the sandboxed Mac Catalyst environment.
13. **`AXCoreUtilities` / `unsafeForcedSync called from Swift Concurrent context`**:
    - `Subsystem: com.apple.Accessibility | Category: AXCommon | Library: AXCoreUtilities`:
      - **Cause**: In macOS 14/15 and iOS 17/18, Apple added runtime diagnostic assertion logging to `AXCoreUtilities` to detect internal legacy synchronous dispatch calls (`unsafeForcedSync`) executed when legacy system frameworks (such as PDFKit line extraction or `AVSpeechSynthesizer` XPC communication with `AXSpeechManager`) are invoked from within a Swift Concurrency `Task` execution context (`swift_task_getCurrent() != NULL`).
      - **Impact**: **Completely benign internal diagnostic**. The OS log is categorized as `Fault` purely for Apple's internal system telemetry. It does not crash the application or affect execution.
      - **Architectural Mitigation in Vachanam**:
        - **Asynchronous PDF Layout Offloading**: `SentenceSegmenter.parseDocumentAsync` offloads PDFKit text extraction and line segmentation to a dedicated background GCD queue via `withCheckedContinuation`, ensuring `swift_task_getCurrent() == nil` and preventing cooperative thread pool starvation.
        - **Main Runloop Speech Dispatching**: `AudioPlayer` dispatches `AVSpeechSynthesizer` control calls (`speak`, `pauseSpeaking`, `continueSpeaking`, `stopSpeaking`) onto `DispatchQueue.main.async`, preventing accessibility IPC synchronization from running inside Swift Concurrency tasks.
        - **Pure-Swift Spatial Hit Testing**: Removed PDFKit imports and private AppKit selection lookups from `SemanticDocument.swift`, resolving taps using pure coordinate bounding-box math.

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

## Competitive Analysis & Strategic Roadmap (vs. ElevenLabs, Speechify & Modern TTS Labs)

### 1. Landscape Overview

| Capability | **Vachanam** | **ElevenLabs (Reader & API)** | **Speechify** | **NaturalReader** | **Cartesia / Play.ht** |
|---|---|---|---|---|---|
| **Privacy & Offline** | **100% On-Device / Offline** (CoreML & MLX) | Cloud API only (Data sent to servers) | Cloud-reliant (Paid tier stream) | Hybrid cloud / Basic offline | Cloud streaming API |
| **Cost Model** | **Free & Open-Source** (Zero subscription/tokens) | $5–$330+/mo credit consumption | $139/yr subscription paywall | $9.99–$19.99/mo subscription | Pay-per-character API |
| **PDF Layout Fidelity** | **Native PDFKit sub-pixel CALayer** | Text-extraction view only (Loss of PDF layout) | Bounding box overlay (Variable alignment) | Basic box overlay | N/A (API only) |
| **Dyslexia & Accessibility** | **Reading Ruler, OpenDyslexic, PencilKit, AAA Contrast** | Minimal (Standard reader UI) | Good dyslexia options & ruler | Good dyslexia fonts & ruler | N/A (API only) |
| **Word Highlighting Sync** | **Strict 1:1 `targetWords` contract & drift telemetry** | Cloud word timestamp streaming | Real-time word highlight | Word-by-word highlight | Sub-100ms alignment |
| **Custom Pronunciation** | **3-Tier Hierarchy (Global/Book/User) + Regex + Cache purge** | Phonetizer / IPA phoneme prompt | Basic phonetic editor | Basic pronunciation replacement | IPA phoneme dictionary |
| **Document Formats** | PDF (Native & Reader views) | PDF, EPUB, TXT, Web URLs, Newsletters | PDF, EPUB, Web, DOCX, Camera OCR | PDF, EPUB, DOCX, TXT, OCR | N/A |
| **Voice Variety & Realism** | Kokoro (82M), Qwen3, Chatterbox, CosyVoice, Apple | Hundreds of hyper-expressive voices (v2/v3) | 200+ voices (Celebrities: Snoop, Gwyneth) | 100+ commercial AI voices | Ultra-low latency voice library |
| **Voice Cloning** | Experimental local CosyVoice 3 | Instant 3-second zero-shot voice clone | User voice cloning (iOS/Studio) | Personal voice clone | Instant voice clone |
| **Dialogue Casting** | Single voice per chunk (Architecture ready via `BlockType.quote`) | Projects multi-voice character casting | Multi-voice dialogue reading | Studio multi-speaker casting | Multi-speaker audio streams |
| **AI Reading Assistant** | Local document stats & estimated completion | GenFM / AI Podcast generation | AI Summaries, Quiz, Ask Document | Basic text-to-speech summaries | Conversational LLM agents |
| **Focus Soundscapes** | Pure silence insertion (0.4s–0.6s) | No background audio | Ambient study sounds & background music | Ambient music tracks | N/A |

---

### 2. Vachanam's Existing Unfair Advantages

1. **Complete On-Device Data Privacy**: Legal documents, medical records, proprietary research papers, and personal notes never leave the user's iPad or Mac.
2. **True Dual-Engine PDF + Reader Typography**: Unlike cloud readers that strip documents down to plain text, Vachanam preserves the exact PDF layout, formulas, and diagrams with high-precision sub-pixel `CALayer` word highlights alongside Apple Pencil annotations.
3. **Zero Ongoing Cost**: Cloud TTS models like ElevenLabs charge heavily per 1,000 characters. Reading an 800-page academic textbook on ElevenLabs or Speechify can cost tens of dollars or hit steep subscription limits; on Vachanam, it is completely free and unlimited.
4. **Architectural Determinism**: Deterministic trailing silence (0.6s for headings, 0.4s for lists, 0.5s for paragraphs) and monotonic binary-searched highlighting clocks prevent network buffering stutters and visual highlight desynchronization.

---

### 3. Feature Upgrade Roadmap (Upgrades That Can Be Added)

#### Phase 1: High-Impact Accessibility & Document Expansion (Near-Term)
- **Ambient Focus Soundscapes**:
  - *Feature*: Layer subtle, looping ambient audio underneath speech narration (e.g., binaural focus beats, brown noise, soft rain, library ambience).
  - *Impact*: Proven to dramatically boost focus and retention for neurodivergent readers (ADHD, dyslexia) without overpowering the vocal track.
- **On-Device Apple Vision OCR (`VisionKit` / `VNRecognizeTextRequest`)**:
  - *Feature*: Extract text and word bounding boxes from scanned/image-only PDFs and physical books snapped with the iPad camera.
  - *Impact*: Eliminates "unreadable scanned document" errors entirely on-device without cloud OCR services.
- **EPUB, Markdown & Web Reader Ingestion**:
  - *Feature*: Add native parsers for `.epub` eBooks, `.md` documents, and Web URLs (via an on-device readability cleaner).
  - *Impact*: Matches ElevenLabs Reader and Speechify's multi-format versatility while keeping reading distraction-free.
- **Audiobook & Podcast Export (`.m4a` with Chapter Markers)**:
  - *Feature*: Offline batch export of narrated documents to standard AAC/M4A audiobooks with embedded chapter metadata for playback in Apple Podcasts or Apple Books.

#### Phase 2: Frontier Neural Vocal Upgrades & Expressive Prosody (Mid-Term)
- **Automated Dialogue Casting (Narrator vs. Character Voices)**:
  - *Feature*: Leverage Vachanam's `BlockType.quote` detection to automatically assign distinct vocal timbres to conversational dialogue (e.g., female protagonist voice vs. male narrator voice).
  - *Impact*: Creates immersive audiobook-grade listening comparable to ElevenLabs Projects.
- **On-Device Instant Voice Cloning (3–5s Audio Prompt)**:
  - *Feature*: Utilize 4-bit quantized CosyVoice 3 / F5-TTS CoreML weights to clone a parent's, educator's, or user's own voice from a short 5-second microphone recording.
  - *Impact*: Enables personalized listening and assistive familiar-voice learning without sending biometric voice data to third-party cloud servers.
- **Multilingual G2P & Accent Expansion**:
  - *Feature*: Expand `MisakiG2P` to support multilingual phonemizers (Spanish, French, German, Japanese, and Indian regional languages like Kannada/Hindi) using Kokoro-v1 and Qwen3 multilingual checkpoints.
- **Expressive Emotion & Prosody Controls**:
  - *Feature*: Expose prosody sliders for vocal warmth, pitch variance, and conversational interjections (`[pause]`, `[sigh]`, `[emphasis]`).

#### Phase 3: On-Device AI Reading Companion ("Ask Document") (Long-Term)
- **Local Neural Summarization & Chapter Briefings**:
  - *Feature*: Integrate a compact on-device LLM (via Apple Silicon CoreML / MLX, such as Llama-3.2 1B or Apple Intelligence APIs) to generate 1-minute executive summaries of chapters before narration begins.
- **Interactive Spoken Vocabulary & Concept Explainer**:
  - *Feature*: Long-press any word or complex paragraph to ask: *"Explain this simply"* or *"Define this in context"*, with the explanation spoken aloud in the narrator's voice.
- **"GenFM" Style Audio Deep Dives**:
  - *Feature*: Convert technical papers into engaging two-host conversational podcast dialogues (similar to NotebookLM and ElevenLabs GenFM) synthesized entirely on-device.

---

---

## Ambient Focus Soundscapes Architecture

Vachanam incorporates an acoustic layering engine designed specifically for ADHD and dyslexia focus:

- **Procedural & Bundled Audio Loops (`Vachanam/Resources/Soundscapes/`)**:
  - **Brown Noise**: Deep spectral power falloff ($1/f^2$), calming low-frequency rumble for masking distractions and high-stress reading.
  - **Pink Noise**: Balanced energy per octave ($1/f$), clinically shown to improve memory consolidation and slow-wave neural focus.
  - **40Hz Binaural Beats**: Gamma-band auditory oscillation (200Hz left ear, 240Hz right ear) supporting working memory and executive concentration.
  - **Soft Rain**: Calming gentle precipitation with warm low-mid frequencies.
  - **Library Ambience**: Distant book turns and quiet room acoustics for authentic study hall presence.
- **Audio Routing & Lifecycle (`AmbientSoundscapePlayer.swift`)**:
  - Configures `AVAudioSession` with `.mixWithOthers` so speech synthesis and background soundscapes blend smoothly without ducking clicks.
  - Seamless looping using `AVAudioPlayer(contentsOf:)` with `numberOfLoops = -1`.
  - Independent volume slider (`0.0`–`1.0`, default `0.35`) persisted across app launches in `UserDefaults`.
  - Smooth ~0.8s fade-in when narration starts and ~0.4s fade-out when paused or stopped.
  - **Study Mode**: Can be toggled on to keep soundscapes playing continuously even when TTS narration is paused or stopped, turning Vachanam into a focused quiet-study workspace.
- **UI Integration**:
  - Headphone button in `TTSControlBar` displaying an active indicator dot when soundscapes are engaged.
  - Opens `SoundscapePickerSheet` with interactive preset cards, live preview, volume slider, and Study Mode switch.

---

## Multi-Format Document Ingestion Architecture (EPUB, Markdown, TXT, Web)

Vachanam unifies all reading material into a single, high-performance semantic pipeline:

```
┌─────────────────────────────────────────────────────────────┐
│                       Input Document                        │
│         (PDF, EPUB, Markdown, Plain Text, Web URL)          │
└──────────────────────────────┬──────────────────────────────┘
                               │
               ┌───────────────┴───────────────┐
               ▼                               ▼
       [PDF Native Parser]           [DocumentParserResolver]
     (TextExtractor/PDFKit)          ├── EPUBParser (ZipArchive)
               │                     ├── MarkdownParser
               │                     ├── PlainTextParser
               │                     └── WebArticleParser (Readability)
               │                               │
               │                               ▼
               │                        [ParsedDocument]
               │                               │
               │                 [SemanticDocumentBuilder]
               │                 (NLTokenizer, Virtual Paging)
               ▼                               ▼
      ┌─────────────────────────────────────────────────┐
      │                SemanticDocument                 │
      │  - Global Monotonic Word IDs (1, 2, 3...)       │
      │  - Paragraphs, Headings, List Items, Quotes     │
      │  - Virtual Paging (~500 words per page)         │
      └────────────────────────┬────────────────────────┘
                               │
            ┌──────────────────┴──────────────────┐
            ▼                                     ▼
   [PDFReaderView Layout]               [ReaderTextView Layout]
  (Original PDF coordinates)       (Dynamic OpenDyslexic / Themes)
            │                                     │
            └──────────────────┬──────────────────┘
                               ▼
                   [PlaybackCoordinator & TTS]
                 (Word & Sentence Highlighting)
```

- **Universal Parser Architecture (`Vachanam/Document/Parsers/`)**:
  - **`DocumentFormat`**: Auto-detects format from file extension, MIME type, or UTType (`.pdf`, `.epub`, `.markdown`, `.plainText`, `.webArticle`).
  - **`EPUBParser` & `ZipArchive`**: Zero-dependency pure Swift PKZip decompression and container navigation. Locates `META-INF/container.xml`, discovers the OPF manifest, follows the reading spine, strips HTML boilerplate while preserving semantic headers (`h1`–`h6`), paragraphs, list items (`li`), and quotes (`blockquote`).
  - **`MarkdownParser`**: Native parsing of ATX headings (`#`), bullet/numbered lists (`-`, `*`, `1.`), blockquotes (`>`), and text blocks into semantic nodes.
  - **`PlainTextParser`**: Double-newline paragraph segmentation with intelligent title deduction.
  - **`WebArticleParser`**: Asynchronous `URLSession` fetcher with a heuristic readability extractor that isolates `<article>`, `<main>`, or the densest text content block, stripping navigation headers, ads, sidebars, and tracking scripts.
- **`SemanticDocumentBuilder`**:
  - Ingests `ParsedDocument` and translates it into Vachanam's standard 3-layer `SemanticDocument`.
  - Runs Apple's `NLTokenizer` to extract linguistic words and sentence boundaries.
  - Partitions long documents into natural ~500-word "virtual pages", enabling instant navigation, thumbnail previews, progress percentages, and sleep timer "end of page" integration.
  - All non-PDF documents open seamlessly in **Reader View** with full support for OpenDyslexic typography, theme presets, reading ruler, and karaoke word/sentence highlights.

---

## Mac Audiobook Studio & iCloud Pre-Generated Audiobook Pipeline

For users with multiple devices (MacBook, iPad, iPhone, Android), Vachanam supports a powerful distributed audiobook workflow:

```
                  YOUR MACBOOK (Host Studio)
              ┌────────────────────────────────┐
              │   AudiobookGenerator (Mac)     │
              │  Kokoro CoreML / Neural Engine │
              └───────────────┬────────────────┘
                              │
               Pre-generate whole book in batch
                              │
                              ▼
                 [Standard Audiobook Bundle]
                 ├── manifest.json
                 ├── document_index.json
                 ├── chapters/
                 │   ├── chap_00.m4a (AAC 24kHz)
                 │   └── chap_00_timings.json
                 └── iCloud Drive Sync
                              │
               ┌──────────────┴──────────────┐
               ▼                             ▼
        [iPad Air / Mini]            [Android / Web Device]
   (PreGeneratedPlaybackAdapter)      (Standard HTTP Stream)
   - Zero-latency chunk audio        - Universal AAC .m4a
   - Exact word-by-word karaoke      - Standard JSON timestamps
   - Zero on-device battery drain    - 100% offline playback
```

- **Batch Synthesis Engine (`AudiobookGenerator.swift`)**:
  - Synthesizes an entire document chapter-by-chapter on the Mac with Apple Silicon acceleration.
  - Generates chaptered `.m4a` AAC audio (24kHz Mono, 64kbps) via `AudioEncoder.swift` (`AVAssetWriter`), producing compact files (~20MB for an entire 300-page book).
  - Emits microsecond-precision word timing files (`chap_XX_timings.json`) and document-wide word indices (`document_index.json`).
  - Resumable: Skips already-synthesized chunks if cancelled and restarted.
- **iCloud Drive Synchronization (`iCloudSyncManager.swift`)**:
  - Automatically writes bundles to the app's ubiquitous iCloud Drive container:
    `iCloud.com.vachanam.app/Audiobooks/<docHash>/`
  - Falls back gracefully to local Application Support if iCloud is unavailable.
- **Instant iPad Playback (`PreGeneratedPlaybackAdapter.swift`)**:
  - When opening a document on iPad, `AudiobookBundleLoader` detects if an iCloud pre-generated bundle exists.
  - If present, `PlaybackCoordinator` transparently routes playback to `PreGeneratedPlaybackAdapter`, streaming the pre-encoded AAC audio with zero local inference delay, zero device heating, and full word-by-word karaoke highlighting.
- **Mac Audiobook Studio UI (`AudiobookGeneratorView.swift`)**:
  - Dedicated studio interface on Mac Catalyst for selecting documents from reading history or file system.
  - Live progress display with percentage, chunk counter, time estimates, and cancellation.
  - Summary card with total audio duration, chunk breakdown, chapter list, and "Reveal in Finder" button.

---

## License

Personal accessibility open-source project. Free for all users.



