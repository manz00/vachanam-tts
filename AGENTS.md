# Agent Guidelines & Repository Memory for Vachanam

## User Rules & Documentation Architecture
- Never open the browser to check or verify.
- Maintain 2 synchronized documentation files:
  - `README.md`: User-facing product documentation (overview, features, UI capabilities, hardware tiers, build & run guides, keyboard shortcuts, troubleshooting).
  - `TECHNICAL.md`: Technical architecture and core logic (3-layer model, coordinate systems, math normalization engines, parser specifications, audio pipelines, memory management, and technical audit entries `[AUD-XX]`).
  - When user-facing features or guides change, update `README.md`.
  - When algorithms, parsers, coordinate math, or technical fixes change, update `TECHNICAL.md`.

## Xcode Project & Scheme Integrity
- The files [Vachanam.xcodeproj/project.pbxproj](file:///Users/manjunath/VibeCoder/vachanam-tts/Vachanam.xcodeproj/project.pbxproj) and [Vachanam.xcodeproj/xcshareddata/xcschemes/Vachanam.xcscheme](file:///Users/manjunath/VibeCoder/vachanam-tts/Vachanam.xcodeproj/xcshareddata/xcschemes/Vachanam.xcscheme) are generated via [generate_project.py](file:///Users/manjunath/VibeCoder/vachanam-tts/generate_project.py).
- Whenever any new Swift source file or resource is added or modified in the directory structure, always run `python3 generate_project.py` to ensure all targets, build phases, resources, and schemes remain synchronized and build cleanly.
- [generate_project.py](file:///Users/manjunath/VibeCoder/vachanam-tts/generate_project.py) must always generate Xcode's full suite of recommended modern build settings (recommended Clang/GCC warnings, `SWIFT_COMPILATION_MODE`, `ONLY_ACTIVE_ARCH`, `ENABLE_USER_SCRIPT_SANDBOXING`, string & asset symbol generation, and modern `LastUpgradeCheck = 1600`) so Xcode never displays the "Validate Project Settings" / "Update to recommended settings" modal.
- Verify changes with:
  ```bash
  # iOS Simulator (iPad)
  xcodebuild -project Vachanam.xcodeproj -scheme Vachanam -destination 'platform=iOS Simulator,name=iPad Air 11-inch (M4)' -quiet build
  xcodebuild -project Vachanam.xcodeproj -scheme Vachanam -destination 'platform=iOS Simulator,name=iPad Air 11-inch (M4)' -quiet test

  # macOS / MacBook (Mac Catalyst)
  xcodebuild -project Vachanam.xcodeproj -scheme Vachanam -destination 'platform=macOS,variant=Mac Catalyst' -quiet build
  xcodebuild -project Vachanam.xcodeproj -scheme Vachanam -destination 'platform=macOS,variant=Mac Catalyst' -quiet test
  ```

