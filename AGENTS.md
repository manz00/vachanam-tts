# Agent Guidelines & Repository Memory for Vachanam

## User Rules & Documentation Architecture
- Never open the browser to check or verify.
- Maintain synchronized documentation across tiers:
  - Root: `README.md` (monorepo overview) and `TECHNICAL.md` (cross-platform architecture & math grammar).
  - Apple (`VachanamApple/`): `VachanamApple/README.md` (product features, hardware tiers, shortcuts) and `VachanamApple/TECHNICAL.md` (Quartz 2D, CoreML/MLX, Apple audit history `[AUD-01]`..`[AUD-16]`, `[AUD-18]`).
  - Android (`VachanamAndroid/`): `VachanamAndroid/README.md` (Material 3, Compose UI, build guide) and `VachanamAndroid/TECHNICAL.md` (PDFBox, Android TTS/ONNX, Android audit `[AUD-17]`).
  - When user-facing features or guides change, update the relevant `README.md` files.
  - When algorithms, parsers, coordinate math, or technical fixes change, update the relevant `TECHNICAL.md` files.

## Xcode Project & Scheme Integrity (VachanamApple)
- The files `VachanamApple/Vachanam.xcodeproj/project.pbxproj` and `VachanamApple/Vachanam.xcodeproj/xcshareddata/xcschemes/Vachanam.xcscheme` are generated via `VachanamApple/generate_project.py`.
- Whenever any new Swift source file or resource is added or modified in `VachanamApple/`, always run:
  ```bash
  cd VachanamApple && python3 generate_project.py
  ```
- `generate_project.py` must always generate Xcode's full suite of recommended modern build settings (`SWIFT_COMPILATION_MODE`, `ONLY_ACTIVE_ARCH`, `ENABLE_USER_SCRIPT_SANDBOXING`, string & asset symbol generation, and `LastUpgradeCheck = 1600`) so Xcode never displays the "Validate Project Settings" modal.
- Verify Apple changes with:
  ```bash
  # iOS Simulator (iPad)
  xcodebuild -project VachanamApple/Vachanam.xcodeproj -scheme Vachanam -destination 'platform=iOS Simulator,name=iPad Air 11-inch (M4)' -quiet build
  xcodebuild -project VachanamApple/Vachanam.xcodeproj -scheme Vachanam -destination 'platform=iOS Simulator,name=iPad Air 11-inch (M4)' -only-testing:VachanamTests -quiet test

  # macOS / MacBook (Mac Catalyst)
  xcodebuild -project VachanamApple/Vachanam.xcodeproj -scheme Vachanam -destination 'platform=macOS,variant=Mac Catalyst' -quiet build
  xcodebuild -project VachanamApple/Vachanam.xcodeproj -scheme Vachanam -destination 'platform=macOS,variant=Mac Catalyst' -only-testing:VachanamTests -quiet test
  ```

## Android Project & Verification (VachanamAndroid)
- Verify Android changes with:
  ```bash
  cd VachanamAndroid
  ./gradlew testDebugUnitTest
  ./gradlew assembleDebug
  ```
