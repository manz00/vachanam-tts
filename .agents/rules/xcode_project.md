# Xcode Project & Build Rules for Vachanam

## Project Configuration Files
- [Vachanam.xcodeproj/project.pbxproj](file:///Users/manjunath/VibeCoder/vachanam-tts/Vachanam.xcodeproj/project.pbxproj)
- [Vachanam.xcodeproj/xcshareddata/xcschemes/Vachanam.xcscheme](file:///Users/manjunath/VibeCoder/vachanam-tts/Vachanam.xcodeproj/xcshareddata/xcschemes/Vachanam.xcscheme)

## Critical Project Generation Workflow
1. **Never hand-edit raw UUIDs in `project.pbxproj`**: The Xcode project structure and schemes are programmatically generated and maintained by [generate_project.py](file:///Users/manjunath/VibeCoder/vachanam-tts/generate_project.py).
2. **Adding New Files**: Whenever adding new Swift files to `Vachanam/`, `VachanamTests/`, or `VachanamUITests/`, always run:
   ```bash
   python3 generate_project.py
   ```
   This automatically discovers all files, links compile phases, bundles resources (`model_registry.json`, `Assets.xcassets`, OpenDyslexic `.otf` fonts), and generates the shared `Vachanam.xcscheme`.
3. **Build & Test Verification**:
   After regenerating the project, verify with:
   ```bash
   xcodebuild -project Vachanam.xcodeproj -scheme Vachanam -destination 'platform=iOS Simulator,name=iPad Air 11-inch (M4)' build
   xcodebuild -project Vachanam.xcodeproj -scheme Vachanam -destination 'platform=iOS Simulator,name=iPad Air 11-inch (M4)' test
   ```
4. **Git Synchronization**:
   Always commit both `generate_project.py` and the regenerated `Vachanam.xcodeproj/project.pbxproj` + `Vachanam.xcscheme` so CI and teammate checkouts stay completely synced.
