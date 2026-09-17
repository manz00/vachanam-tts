# Xcode Project & Build Rules for VachanamApple

## Project Configuration Files
- `VachanamApple/Vachanam.xcodeproj/project.pbxproj`
- `VachanamApple/Vachanam.xcodeproj/xcshareddata/xcschemes/Vachanam.xcscheme`

## Critical Project Generation Workflow
1. **Never hand-edit raw UUIDs in `project.pbxproj`**: The Xcode project structure and schemes are programmatically generated and maintained by `VachanamApple/generate_project.py`.
2. **Adding New Files**: Whenever adding new Swift files to `VachanamApple/`, always run:
   ```bash
   cd VachanamApple && python3 generate_project.py
   ```
   This automatically discovers all files, links compile phases, bundles resources (`model_registry.json`, `Assets.xcassets`, OpenDyslexic `.otf` fonts), and generates the shared `Vachanam.xcscheme`.
3. **Build & Test Verification**:
   After regenerating the project, verify with:
   ```bash
   xcodebuild -project VachanamApple/Vachanam.xcodeproj -scheme Vachanam -destination 'platform=iOS Simulator,name=iPad Air 11-inch (M4)' -only-testing:VachanamTests -quiet test
   ```
4. **Git Synchronization**:
   Always commit both `VachanamApple/generate_project.py` and the regenerated `VachanamApple/Vachanam.xcodeproj` so CI and teammate checkouts stay completely synced.
