# Vachanam for Android (Kotlin + Jetpack Compose)

[![Platform: Android 12+](https://img.shields.io/badge/Platform-Android%2012+%20(API%2031+)-green.svg?style=flat-square)](https://developer.android.com)
[![Kotlin 2.0.21](https://img.shields.io/badge/Kotlin-2.0.21-blue.svg?style=flat-square)](https://kotlinlang.org)
[![Jetpack Compose Material 3](https://img.shields.io/badge/Compose-Material%203-purple.svg?style=flat-square)](https://developer.android.com/jetpack/compose)

**Vachanam for Android** is the native Android implementation of the Vachanam universal accessible document reader and TTS studio, built from scratch using **Kotlin** and **Jetpack Compose (Material 3)**. It achieves full architectural and feature parity with the Apple edition.

---

## Key Features

### 📖 3-Layer Universal Document Ingestion
- **PDF**: `PdfTextExtractor` using PDFBox-Android for spatial word/sentence boundaries + `PdfDocumentWrapper` utilizing `android.graphics.pdf.PdfRenderer` for 2x high-resolution page bitmaps.
- **EPUB**: `EPUBParser` with streaming ZIP archive decompression, OPF manifest/spine parsing, clean entity decoding, and word-gluing prevention.
- **Markdown**: `MarkdownParser` parsing ATX/Setext headers, nested lists, quotes, and code blocks.
- **Plain Text**: `PlainTextParser` with multi-encoding fallback cascade (`UTF-8` $\to$ `ISO-8859-1` $\to$ `Windows-1252` $\to$ `UTF-16` $\to$ `ASCII`).
- **Web Articles**: `WebArticleParser` with URL HTTP content extraction and boilerplate stripping.
- **Sentence-Aligned Virtual Pagination**: Non-PDF books are segmented into sentence-aligned virtual pages (`SemanticDocumentBuilder`) so sentences are never fractured across page turns.

### 🎙️ Pluggable TTS & Real-Time Karaoke Highlighting
- **`TTSModelProtocol`**: Modular contract allowing swappable TTS backends.
- **`AndroidSystemAdapter`**: Zero-download offline synthesis utilizing Android's native `TextToSpeech` engine and `UtteranceProgressListener.onRangeStart` for precise, word-by-word karaoke highlighting.
- **`KokoroOnnxAdapter`**: On-device neural synthesis via ONNX Runtime for the Kokoro 82M voice model.
- **`PronunciationManager`**: Custom word/phoneme override dictionary with persistent storage.
- **`TTSController`**: High-level playback coordinator managing play/pause, sentence skipping, and speech rate scaling (0.5x – 2.5x).

### ♿ Accessibility First & Material You
- **5 Theme Palettes**: Cream, Sepia, Dark Slate (default), OLED Black, and Paper White with automatic contrast adjustment.
- **OpenDyslexic Typography**: Bundled `opendyslexic_regular.otf` and `opendyslexic_bold.otf` in `res/font/`.
- **Bionic Reading Mode**: Automatically bolds initial fixation characters of each word to guide the eye.
- **Dyslexia Reading Ruler**: Draggable horizontal focus guide with customizable window height and dimming mask.

### 🎧 Ambient Focus Soundscapes
- 5 bundled `.m4a` focus soundscapes in `res/raw/`:
  - **Brown Noise**
  - **Pink Noise**
  - **40Hz Binaural Beats**
  - **Soft Rain**
  - **Library & Café**
- Independent volume slider (`0.0`–`1.0`), infinite looping, smooth crossfades, and study mode toggle.
- **`SleepTimer`**: Configurable countdown timer for automatic playback cessation.

---

## Directory Structure

```
VachanamAndroid/
├── build.gradle.kts
├── settings.gradle.kts
├── gradle.properties
├── gradlew
├── gradle/
│   ├── libs.versions.toml
│   └── wrapper/gradle-wrapper.properties
└── app/
    ├── build.gradle.kts
    ├── proguard-rules.pro
    └── src/
        ├── main/
        │   ├── AndroidManifest.xml
        │   ├── assets/
        │   │   ├── Benchmark/The_Ultimate_Multi_Discipline_TTS_Benchmark.pdf
        │   │   └── MathMaps/*.json
        │   ├── res/
        │   │   ├── font/ (OpenDyslexic fonts)
        │   │   ├── raw/ (5 focus soundscape loops)
        │   │   └── values/ (themes, colors, strings)
        │   └── java/com/vachanam/reader/
        │       ├── app/ (AppState ViewModel & lifecycle)
        │       ├── data/ (Semantic models, parsers, text engines)
        │       ├── pdf/ (PDFBox extraction, renderer wrapper)
        │       ├── tts/ (TTSModelProtocol, AndroidSystemAdapter, KokoroOnnxAdapter)
        │       ├── audio/ (AmbientSoundscapePlayer, SleepTimer)
        │       ├── accessibility/ (AccessibilityManager, ThemeManager)
        │       └── ui/ (Compose screens: Library, Reader, Scrubber, Controls, Settings)
        └── test/java/com/vachanam/reader/
            └── VachanamCoreLogicTest.kt
```

---

## How to Build & Run

### Prerequisites
- Android SDK with Platform 35 (`platforms/android-35`)
- Java 17+ (or Android Studio Ladybug / Meerkat)
- Connected Android 12+ device (API 31+) or emulator

### Commands
```bash
cd VachanamAndroid

# Run unit tests on JVM
./gradlew testDebugUnitTest

# Assemble debug APK
./gradlew assembleDebug

# Install on connected device/emulator
./gradlew installDebug
```
