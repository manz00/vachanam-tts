//
//  AmbientSoundscapeTests.swift
//  VachanamTests
//

import XCTest
@testable import Vachanam

final class AmbientSoundscapeTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "vachanam.soundscape.preset")
        UserDefaults.standard.removeObject(forKey: "vachanam.soundscape.volume")
        UserDefaults.standard.removeObject(forKey: "vachanam.soundscape.studyMode")
    }
    
    func testAllPresetsConfigured() {
        let presets = SoundscapePreset.allCases
        XCTAssertEqual(presets.count, 5)
        
        for preset in presets {
            XCTAssertFalse(preset.title.isEmpty, "Preset \(preset) should have a title")
            XCTAssertFalse(preset.subtitle.isEmpty, "Preset \(preset) should have a subtitle")
            XCTAssertFalse(preset.systemImage.isEmpty, "Preset \(preset) should have a systemImage")
            XCTAssertFalse(preset.resourceName.isEmpty, "Preset \(preset) should have a resourceName")
        }
    }
    
    func testVolumeClampingAndPersistence() {
        let player = AmbientSoundscapePlayer.shared
        
        player.setVolume(0.5)
        XCTAssertEqual(player.volume, 0.5, accuracy: 0.001)
        XCTAssertEqual(UserDefaults.standard.float(forKey: "vachanam.soundscape.volume"), 0.5, accuracy: 0.001)
        
        player.setVolume(1.8)
        XCTAssertEqual(player.volume, 1.0, accuracy: 0.001)
        
        player.setVolume(-0.5)
        XCTAssertEqual(player.volume, 0.0, accuracy: 0.001)
    }
    
    func testPresetSelectionAndPersistence() {
        let player = AmbientSoundscapePlayer.shared
        
        player.selectPreset(.brownNoise)
        XCTAssertEqual(player.currentPreset, .brownNoise)
        XCTAssertEqual(UserDefaults.standard.string(forKey: "vachanam.soundscape.preset"), "brown_noise")
        
        player.selectPreset(.softRain)
        XCTAssertEqual(player.currentPreset, .softRain)
        XCTAssertEqual(UserDefaults.standard.string(forKey: "vachanam.soundscape.preset"), "soft_rain")
        
        player.selectPreset(nil)
        XCTAssertNil(player.currentPreset)
        XCTAssertNil(UserDefaults.standard.string(forKey: "vachanam.soundscape.preset"))
    }
    
    func testStudyModeToggle() {
        let player = AmbientSoundscapePlayer.shared
        
        player.setStudyMode(true)
        XCTAssertTrue(player.isStudyModeEnabled)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "vachanam.soundscape.studyMode"))
        
        player.setStudyMode(false)
        XCTAssertFalse(player.isStudyModeEnabled)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "vachanam.soundscape.studyMode"))
    }
    
    func testTTSLifecycleInteraction() {
        let player = AmbientSoundscapePlayer.shared
        player.selectPreset(nil)
        player.setStudyMode(false)
        
        // When no preset is selected, TTS play start does nothing
        player.handleTTSPlayStarted()
        XCTAssertFalse(player.isPlaying)
        
        // Select preset
        player.selectPreset(.binauralFocus)
        player.setStudyMode(false)
        
        player.handleTTSPaused()
        // If not in study mode, paused TTS stops or pauses ambient
        XCTAssertFalse(player.isPlaying)
        
        player.handleTTSStopped()
        XCTAssertFalse(player.isPlaying)
        
        // Clean up
        player.selectPreset(nil)
    }
}
