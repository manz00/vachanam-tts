//
//  TTSAudioCacheTests.swift
//  VachanamTests
//

import XCTest
@testable import Vachanam

final class TTSAudioCacheTests: XCTestCase {
    
    func testCacheKeyDeterministic() {
        let cache = TTSAudioCache.shared
        let docID = UUID()
        
        let key1 = cache.makeKey(
            documentID: docID,
            modelId: "kokoro-v1.0-en",
            voice: "af_heart",
            speed: 1.0,
            text: "Hello world"
        )
        let key2 = cache.makeKey(
            documentID: docID,
            modelId: "kokoro-v1.0-en",
            voice: "af_heart",
            speed: 1.0,
            text: "Hello world"
        )
        let keyDifferentSpeed = cache.makeKey(
            documentID: docID,
            modelId: "kokoro-v1.0-en",
            voice: "af_heart",
            speed: 1.25,
            text: "Hello world"
        )
        
        XCTAssertEqual(key1, key2)
        XCTAssertNotEqual(key1, keyDifferentSpeed)
    }
    
    func testStoreAndRetrieve() {
        let cache = TTSAudioCache.shared
        let key = "test-key-\(UUID().uuidString)"
        
        let dummyData = "test audio data".data(using: .utf8)!
        let sampleResult = TTSAudioResult(
            audioData: dummyData,
            pcmBuffer: nil,
            sampleRate: 24000.0,
            duration: 1.5,
            wordTimestamps: [WordTimestamp(word: "test", startTime: 0.0, endTime: 1.5)]
        )
        
        cache.store(key: key, result: sampleResult)
        
        let retrieved = cache.retrieve(key: key)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.audioData, dummyData)
        XCTAssertEqual(retrieved?.duration, 1.5)
        XCTAssertEqual(retrieved?.sampleRate, 24000.0)
    }
}
