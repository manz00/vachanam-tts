//
//  MultiFormatDocumentTests.swift
//  VachanamTests
//
//  Unit tests for EPUB, Markdown, Plain Text, and Web Article ingestion pipelines.
//

import XCTest
@testable import Vachanam

final class MultiFormatDocumentTests: XCTestCase {
    
    // MARK: - Document Format Detection
    
    func testDocumentFormatDetection() {
        XCTAssertEqual(DocumentFormat.detect(from: URL(fileURLWithPath: "/docs/book.pdf")), .pdf)
        XCTAssertEqual(DocumentFormat.detect(from: URL(fileURLWithPath: "/docs/novel.epub")), .epub)
        XCTAssertEqual(DocumentFormat.detect(from: URL(fileURLWithPath: "/docs/readme.md")), .markdown)
        XCTAssertEqual(DocumentFormat.detect(from: URL(fileURLWithPath: "/docs/notes.markdown")), .markdown)
        XCTAssertEqual(DocumentFormat.detect(from: URL(fileURLWithPath: "/docs/plain.txt")), .plainText)
        XCTAssertEqual(DocumentFormat.detect(from: URL(string: "https://example.com/blog/article")!), .webArticle)
    }
    
    // MARK: - Markdown Parser
    
    func testMarkdownParserStructure() async throws {
        let md = """
        # Deep Learning Principles
        
        Deep learning is a subset of machine learning based on artificial neural networks.
        
        ## Core Concepts
        
        Here are the fundamental building blocks:
        
        - Artificial Neurons
        - Backpropagation algorithm
        - Activation functions
        
        > Neural networks are universal function approximators.
        
        1. Forward pass computes loss
        2. Backward pass computes gradients
        """
        
        let parser = MarkdownParser()
        let parsed = try await parser.parse(from: .rawText(md, title: "Default"))
        
        XCTAssertEqual(parsed.title, "Deep Learning Principles")
        XCTAssertEqual(parsed.format, .markdown)
        XCTAssertFalse(parsed.chapters.isEmpty)
        
        let allBlocks = parsed.allBlocks
        XCTAssertTrue(allBlocks.contains(where: { $0.type == .heading && $0.text == "Deep Learning Principles" }))
        XCTAssertTrue(allBlocks.contains(where: { $0.type == .heading && $0.text == "Core Concepts" }))
        XCTAssertTrue(allBlocks.contains(where: { $0.type == .paragraph && $0.text.contains("subset of machine learning") }))
        XCTAssertTrue(allBlocks.contains(where: { $0.type == .listItem && $0.text == "Artificial Neurons" }))
        XCTAssertTrue(allBlocks.contains(where: { $0.type == .quote && $0.text.contains("universal function") }))
    }
    
    func testMarkdownSyntaxCleaning() async throws {
        let md = """
        This is **bold** and *italic* and `inline code` and [a link](https://apple.com) and ~~strikethrough~~.
        """
        let parser = MarkdownParser()
        let parsed = try await parser.parse(from: .rawText(md, title: "Cleaning Test"))
        let firstBlock = parsed.allBlocks.first
        
        XCTAssertNotNil(firstBlock)
        XCTAssertEqual(firstBlock?.text, "This is bold and italic and inline code and a link and strikethrough.")
    }
    
    // MARK: - Plain Text Parser
    
    func testPlainTextParser() async throws {
        let text = """
        Speech and Accessibility
        
        Text to speech technology transforms written content into natural sounding spoken audio.
        
        This enables readers with dyslexia, visual impairments, or busy schedules to consume long-form documents.
        """
        
        let parser = PlainTextParser()
        let parsed = try await parser.parse(from: .rawText(text, title: "Untitled"))
        
        XCTAssertEqual(parsed.title, "Speech and Accessibility")
        XCTAssertEqual(parsed.format, .plainText)
        XCTAssertEqual(parsed.allBlocks.count, 2)
        XCTAssertEqual(parsed.allBlocks[0].text, "Text to speech technology transforms written content into natural sounding spoken audio.")
    }
    
    // MARK: - Web Article Parser
    
    func testWebArticleParser() async throws {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <title>The Future of Voice Synthesis | Tech Insights</title>
            <meta name="author" content="Dr. Alan Turing">
        </head>
        <body>
            <nav><a href="/">Home</a></nav>
            <article>
                <h1>The Future of Voice Synthesis</h1>
                <p>Neural speech models like Kokoro bring studio quality TTS directly onto user devices.</p>
                <p>Zero server dependencies guarantee total privacy and instant response times.</p>
            </article>
            <footer>Copyright 2026</footer>
        </body>
        </html>
        """
        
        let parser = WebArticleParser()
        let parsed = parser.parseHTMLArticle(html, defaultTitle: "Web Test")
        
        XCTAssertEqual(parsed.title, "The Future of Voice Synthesis")
        XCTAssertEqual(parsed.author, "Dr. Alan Turing")
        XCTAssertEqual(parsed.format, .webArticle)
        
        let texts = parsed.allBlocks.map { $0.text }
        XCTAssertTrue(texts.contains(where: { $0.contains("Neural speech models like Kokoro") }))
        XCTAssertTrue(texts.contains(where: { $0.contains("Zero server dependencies") }))
        // Confirm navigation and footer were stripped
        XCTAssertFalse(texts.contains(where: { $0.contains("Home") }))
        XCTAssertFalse(texts.contains(where: { $0.contains("Copyright") }))
    }
    
    // MARK: - Semantic Document Builder
    
    func testSemanticDocumentBuilder() {
        let chapter1 = ParsedChapter(title: "Chapter 1", blocks: [
            ParsedBlock(type: .heading, text: "Introduction to Acoustics", level: 1),
            ParsedBlock(type: .paragraph, text: "Sound is a vibration that propagates as an acoustic wave through a medium such as gas, liquid or solid.")
        ])
        let chapter2 = ParsedChapter(title: "Chapter 2", blocks: [
            ParsedBlock(type: .heading, text: "Frequency and Pitch", level: 1),
            ParsedBlock(type: .paragraph, text: "Pitch is a perceptual property of sounds that allows their ordering on a frequency-related scale.")
        ])
        
        let parsedDoc = ParsedDocument(
            title: "Physics of Sound",
            author: "Heinrich Hertz",
            format: .epub,
            chapters: [chapter1, chapter2]
        )
        
        let semDoc = SemanticDocumentBuilder.shared.build(from: parsedDoc)
        
        XCTAssertEqual(semDoc.title, "Physics of Sound")
        XCTAssertEqual(semDoc.pageCount, 2) // 2 chapters = 2 virtual pages
        XCTAssertFalse(semDoc.sentences.isEmpty)
        XCTAssertFalse(semDoc.words.isEmpty)
        XCTAssertFalse(semDoc.chunks.isEmpty)
        
        // Verify monotonic global word IDs
        for i in 0..<semDoc.words.count {
            XCTAssertEqual(semDoc.words[i].globalWordID, i)
        }
        
        // Verify sentence and block mapping
        for sentence in semDoc.sentences {
            XCTAssertFalse(sentence.words.isEmpty)
            XCTAssertNotNil(semDoc.sentence(id: sentence.sentenceID))
        }
        
        // Verify chunks cover all sentences
        let chunkSentences = Set(semDoc.chunks.flatMap { $0.sentenceIDs })
        let docSentences = Set(semDoc.sentences.map { $0.sentenceID })
        XCTAssertEqual(chunkSentences, docSentences)
    }
}
