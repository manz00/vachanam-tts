# Agent Guidelines & Repository Memory for Vachanam

## User Rules
- Never open the browser to check or verify.
- Always update `README.md` whenever changes or additions are made.

## Xcode Project & Scheme Integrity
- The files [Vachanam.xcodeproj/project.pbxproj](file:///Users/manjunath/VibeCoder/vachanam-tts/Vachanam.xcodeproj/project.pbxproj) and [Vachanam.xcodeproj/xcshareddata/xcschemes/Vachanam.xcscheme](file:///Users/manjunath/VibeCoder/vachanam-tts/Vachanam.xcodeproj/xcshareddata/xcschemes/Vachanam.xcscheme) are generated via [generate_project.py](file:///Users/manjunath/VibeCoder/vachanam-tts/generate_project.py).
- Whenever any new Swift source file or resource is added or modified in the directory structure, always run `python3 generate_project.py` to ensure all targets, build phases, resources, and schemes remain synchronized and build cleanly.
- Verify changes with:
  ```bash
  xcodebuild -project Vachanam.xcodeproj -scheme Vachanam -destination 'platform=iOS Simulator,name=iPad Air 11-inch (M4)' -quiet build
  xcodebuild -project Vachanam.xcodeproj -scheme Vachanam -destination 'platform=iOS Simulator,name=iPad Air 11-inch (M4)' -quiet test
  ```
