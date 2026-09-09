//
//  AudiobookGenerationTests.swift
//  VachanamTests
//
//  Unit tests for Audiobook Generator, Manifest serialization, AudioEncoder,
//  and PreGeneratedPlaybackAdapter.
//

import XCTest
import AVFoundation
@testable import Vachanam

final class AudiobookGenerationTests: XCTestCase {
    
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("vachanam_test_\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }
    
    // MARK: - Manifest Serialization
    
    func testManifestSerialization() throws {
        let chunk = AudiobookExportChunk(
            index: 0,
            chapterIndex: 0,
            audioM4A: "chapters/chapter-01/chunk-001.m4a",
            audioOpus: nil,
            timingsPath: "timings/chapter-01/chunk-001.json",
            duration: 32.5,
            startGlobalWordID: 0,
            endGlobalWordID: 64,
            sentenceIDs: [0, 1]
        )
        
        let chapter = AudiobookChapterManifest(
            index: 0,
            title: "Chapter 1: The Beginning",
            startPage: 0,
            endPage: 5,
            chunks: [chunk]
        )
        
        let manifest = AudiobookManifest(
            version: 1,
            documentHash: "hash-test-123456",
            title: "Testing Architecture",
            author: "Author Name",
            generatedAt: Date(),
            model: "kokoro-v1.0-en",
            voice: "af_heart",
            speed: 1.0,
            sampleRate: 24000.0,
            totalDuration: 32.5,
            totalChunks: 1,
            chapters: [chapter]
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(manifest)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(AudiobookManifest.self, from: data)
        
        XCTAssertEqual(decoded.version, 1)
        XCTAssertEqual(decoded.documentHash, "hash-test-123456")
        XCTAssertEqual(decoded.title, "Testing Architecture")
        XCTAssertEqual(decoded.totalChunks, 1)
        XCTAssertEqual(decoded.chapters.count, 1)
        XCTAssertEqual(decoded.chapters[0].chunks.count, 1)
        XCTAssertEqual(decoded.chapters[0].chunks[0].duration, 32.5)
    }
    
    // MARK: - Content Hash Determinism
    
    func testContentHashDeterminism() {
        let syncManager = iCloudSyncManager.shared
        
        let chapter = ParsedChapter(title: "Chapter 1", blocks: [
            ParsedBlock(type: .paragraph, text: "Deterministic hashing guarantees that iPad and Mac match identical documents regardless of filesystem paths.")
        ])
        let parsed = ParsedDocument(title: "Hash Test", format: .plainText, chapters: [chapter])
        let semDoc = SemanticDocumentBuilder.shared.build(from: parsed)
        
        let hash1 = syncManager.computeHash(for: semDoc)
        let hash2 = syncManager.computeHash(for: semDoc)
        
        XCTAssertFalse(hash1.isEmpty)
        XCTAssertEqual(hash1, hash2, "Content hash must be completely deterministic")
    }
    
    // MARK: - Audio Encoder
    
    func testAudioEncoderM4A() throws {
        let sampleRate: Double = 24000.0
        let frameCount = 24000 // 1 second of audio
        
        // Generate 1 second sine wave PCM buffer
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false),
              let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else {
            XCTFail("Failed to allocate test PCM buffer")
            return
        }
        pcmBuffer.frameLength = AVAudioFrameCount(frameCount)
        let channel = pcmBuffer.floatChannelData![0]
        for i in 0..<frameCount {
            channel[i] = sin(Float(i) * 2.0 * .pi * 440.0 / Float(sampleRate)) * 0.5
        }
        
        let testResult = TTSAudioResult(
            audioData: Data(),
            pcmBuffer: pcmBuffer,
            sampleRate: sampleRate,
            duration: 1.0,
            wordTimestamps: []
        )
        
        let destURL = tempDirectory.appendingPathComponent("test_encoded.m4a")
        try AudioEncoder.shared.encodeToM4A(result: testResult, destinationURL: destURL)
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: destURL.path))
        XCTAssertGreaterThan(try Data(contentsOf: destURL).count, 1000)
        
        // Verify output file is a readable audio file with valid duration
        let audioFile = try AVAudioFile(forReading: destURL)
        let duration = Double(audioFile.length) / audioFile.fileFormat.sampleRate
        XCTAssertEqual(duration, 1.0, accuracy: 0.1)
    }
    
    // MARK: - Bundle Loader & Playback Adapter
    
    func testBundleLoaderAndAdapter() throws {
        let bundleHash = "bundle-test-\(UUID().uuidString)"
        let bundleDir = iCloudSyncManager.shared.bundleDirectory(for: bundleHash)
        let chapterDir = bundleDir.appendingPathComponent("chapters/chapter-01", isDirectory: true)
        let timingDir = bundleDir.appendingPathComponent("timings/chapter-01", isDirectory: true)
        
        try FileManager.default.createDirectory(at: chapterDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: timingDir, withIntermediateDirectories: true)
        
        // 1. Encode test audio chunk
        let sampleRate: Double = 24000.0
        let frameCount = 24000
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false)!
        let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount))!
        pcmBuffer.frameLength = AVAudioFrameCount(frameCount)
        
        let audioDestURL = chapterDir.appendingPathComponent("chunk-001.m4a")
        let dummyResult = TTSAudioResult(audioData: Data(), pcmBuffer: pcmBuffer, sampleRate: sampleRate, duration: 1.0)
        try AudioEncoder.shared.encodeToM4A(result: dummyResult, destinationURL: audioDestURL)
        
        // 2. Write timings JSON
        let timings = AudiobookChunkTimings(
            chunkIndex: 0,
            chapterIndex: 0,
            words: [
                AudiobookWordTimestamp(globalWordID: 0, text: "Vachanam", startTime: 0.0, endTime: 0.5),
                AudiobookWordTimestamp(globalWordID: 1, text: "Studio", startTime: 0.5, endTime: 1.0)
            ]
        )
        let timingDestURL = timingDir.appendingPathComponent("chunk-001.json")
        try JSONEncoder().encode(timings).write(to: timingDestURL)
        
        // 3. Write manifest.json
        let chunk = AudiobookExportChunk(
            index: 0,
            chapterIndex: 0,
            audioM4A: "chapters/chapter-01/chunk-001.m4a",
            audioOpus: nil,
            timingsPath: "timings/chapter-01/chunk-001.json",
            duration: 1.0,
            startGlobalWordID: 0,
            endGlobalWordID: 1,
            sentenceIDs: [0]
        )
        let manifest = AudiobookManifest(
            version: 1,
            documentHash: bundleHash,
            title: "Studio Test Book",
            model: "kokoro-v1.0-en",
            totalDuration: 1.0,
            totalChunks: 1,
            chapters: [AudiobookChapterManifest(index: 0, title: "Chapter 1", startPage: 0, endPage: 1, chunks: [chunk])]
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(manifest).write(to: bundleDir.appendingPathComponent("manifest.json"))
        
        // Verify AudiobookBundleLoader
        XCTAssertTrue(iCloudSyncManager.shared.hasBundle(for: bundleHash))
        
        let loadedManifest = iCloudSyncManager.shared.loadManifest(for: bundleHash)
        XCTAssertNotNil(loadedManifest)
        XCTAssertEqual(loadedManifest?.title, "Studio Test Book")
        
        let lookup = AudiobookBundleLoader.shared.findExportChunk(forGlobalWordID: 1, in: loadedManifest!)
        XCTAssertNotNil(lookup)
        XCTAssertEqual(lookup?.chunk.index, 0)
        
        // Verify PreGeneratedPlaybackAdapter
        let playbackResult = PreGeneratedPlaybackAdapter.shared.loadAudioResult(for: chunk, in: loadedManifest!)
        XCTAssertNotNil(playbackResult)
        XCTAssertEqual(playbackResult?.wordTimestamps.count, 2)
        XCTAssertEqual(playbackResult?.wordTimestamps[0].word, "Vachanam")
        XCTAssertEqual(playbackResult?.wordTimestamps[1].word, "Studio")
        
        // Clean up
        try? FileManager.default.removeItem(at: bundleDir)
    }
}
