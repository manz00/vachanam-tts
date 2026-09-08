//
//  PDFReaderView.swift
//  Vachanam
//
//  PDFKit PDFView wrapper with page synchronization and precise coordinate-converted live text highlights.
//

import SwiftUI
import PDFKit
import Combine

public class PDFHighlightOverlayView: UIView {
    private var sentenceLayers: [CALayer] = []
    private var wordLayer = CALayer()
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayers()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
    }
    
    private func setupLayers() {
        wordLayer.cornerRadius = 3.0
        wordLayer.borderWidth = 1.5
        layer.addSublayer(wordLayer)
    }
    
    public func clear() {
        sentenceLayers.forEach { $0.removeFromSuperlayer() }
        sentenceLayers.removeAll()
        wordLayer.isHidden = true
    }
    
    public func render(
        sentenceRects: [CGRect],
        sentenceColor: UIColor,
        wordRect: CGRect?,
        wordColor: UIColor,
        wordBorderColor: UIColor
    ) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        // Re-use or rebuild sentence layers
        while sentenceLayers.count < sentenceRects.count {
            let l = CALayer()
            l.cornerRadius = 4.0
            layer.insertSublayer(l, below: wordLayer)
            sentenceLayers.append(l)
        }
        while sentenceLayers.count > sentenceRects.count {
            sentenceLayers.removeLast().removeFromSuperlayer()
        }
        
        for (idx, rect) in sentenceRects.enumerated() {
            let l = sentenceLayers[idx]
            l.frame = rect
            l.backgroundColor = sentenceColor.cgColor
            l.isHidden = false
        }
        
        // Word layer
        if let wRect = wordRect, !wRect.isEmpty {
            wordLayer.frame = wRect
            wordLayer.backgroundColor = wordColor.cgColor
            wordLayer.borderColor = wordBorderColor.cgColor
            wordLayer.isHidden = false
        } else {
            wordLayer.isHidden = true
        }
        
        CATransaction.commit()
    }
}

public struct PDFReaderView: UIViewRepresentable {
    public let document: ReaderDocument
    @Binding public var currentPageIndex: Int
    
    public init(document: ReaderDocument, currentPageIndex: Binding<Int>) {
        self.document = document
        self._currentPageIndex = currentPageIndex
    }
    
    public func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document.pdfDocument
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .horizontal
        pdfView.usePageViewController(true)
        pdfView.backgroundColor = UIColor(Color(red: 0.05, green: 0.08, blue: 0.13))
        
        let overlayView = PDFHighlightOverlayView()
        overlayView.backgroundColor = .clear
        overlayView.isUserInteractionEnabled = false
        overlayView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlayView.frame = pdfView.bounds
        pdfView.addSubview(overlayView)
        
        context.coordinator.pdfView = pdfView
        context.coordinator.overlayView = overlayView
        context.coordinator.setupObservers()
        
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.viewScrolledOrScaled(_:)),
            name: .PDFViewScaleChanged,
            object: pdfView
        )
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.viewScrolledOrScaled(_:)),
            name: .PDFViewVisiblePagesChanged,
            object: pdfView
        )
        
        if let page = document.page(at: currentPageIndex) {
            pdfView.go(to: page)
        }
        
        return pdfView
    }
    
    public func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document != document.pdfDocument {
            uiView.document = document.pdfDocument
        }
        
        if let current = uiView.currentPage, document.pdfDocument.index(for: current) != currentPageIndex {
            if let target = document.page(at: currentPageIndex) {
                uiView.go(to: target)
            }
        }
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public class Coordinator: NSObject {
        var parent: PDFReaderView
        weak var pdfView: PDFView?
        weak var overlayView: PDFHighlightOverlayView?
        private var cancellables = Set<AnyCancellable>()
        
        init(_ parent: PDFReaderView) {
            self.parent = parent
        }
        
        func setupObservers() {
            cancellables.removeAll()
            
            TTSController.shared.$isPlaying
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.updateHighlights() }
                .store(in: &cancellables)
            
            TTSController.shared.$currentSentence
                .receive(on: RunLoop.main)
                .sink { [weak self] sentence in
                    guard let self = self else { return }
                    if let s = sentence, let pdfView = self.pdfView {
                        if s.pageIndex != self.parent.currentPageIndex, let targetPage = self.parent.document.page(at: s.pageIndex) {
                            pdfView.go(to: targetPage)
                            DispatchQueue.main.async {
                                self.parent.currentPageIndex = s.pageIndex
                            }
                        }
                    }
                    self.updateHighlights()
                }
                .store(in: &cancellables)
            
            TTSController.shared.$currentWord
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.updateHighlights() }
                .store(in: &cancellables)
            
            AccessibilityManager.shared.$highlightMode
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.updateHighlights() }
                .store(in: &cancellables)
            
            AccessibilityManager.shared.$colorChoice
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.updateHighlights() }
                .store(in: &cancellables)
        }
        
        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = pdfView, let page = pdfView.currentPage else { return }
            let index = parent.document.pdfDocument.index(for: page)
            if index != parent.currentPageIndex && index >= 0 {
                DispatchQueue.main.async {
                    self.parent.currentPageIndex = index
                    self.updateHighlights()
                }
            }
        }
        
        @objc func viewScrolledOrScaled(_ notification: Notification) {
            DispatchQueue.main.async {
                self.updateHighlights()
            }
        }
        
        func updateHighlights() {
            guard let pdfView = pdfView, let page = pdfView.currentPage, let overlay = overlayView else { return }
            let currentPageIdx = parent.document.pdfDocument.index(for: page)
            
            let isPlaying = TTSController.shared.isPlaying
            let sentence = TTSController.shared.currentSentence
            let word = TTSController.shared.currentWord
            let mode = AccessibilityManager.shared.highlightMode
            let colors = AccessibilityManager.shared.colorChoice
            
            guard isPlaying, let currentSentence = sentence, currentSentence.pageIndex == currentPageIdx else {
                overlay.clear()
                if TTSController.shared.currentSentenceViewRect != nil {
                    DispatchQueue.main.async {
                        if TTSController.shared.currentSentenceViewRect != nil {
                            TTSController.shared.currentSentenceViewRect = nil
                        }
                    }
                }
                return
            }
            
            // Convert sentence line bounds from PDF page space to View space
            var sentenceViewRects: [CGRect] = []
            if mode == .both || mode == .sentenceOnly {
                sentenceViewRects = currentSentence.lineBounds.map { lineBound in
                    pdfView.convert(lineBound, from: page)
                }
            }
            
            // Convert word bounds from PDF page space to View space
            var wordViewRect: CGRect? = nil
            if (mode == .both || mode == .wordOnly), let currentWord = word, currentWord.pageIndex == currentPageIdx {
                wordViewRect = pdfView.convert(currentWord.bounds, from: page)
            }
            
            // Update tracking rects for ruler asynchronously if ruler is enabled
            if AccessibilityManager.shared.isReadingRulerEnabled {
                let firstLine = sentenceViewRects.first
                if TTSController.shared.currentSentenceViewRect != firstLine {
                    DispatchQueue.main.async {
                        TTSController.shared.currentSentenceViewRect = firstLine
                    }
                }
            } else if TTSController.shared.currentSentenceViewRect != nil {
                DispatchQueue.main.async {
                    TTSController.shared.currentSentenceViewRect = nil
                }
            }
            
            // Render on overlay
            overlay.render(
                sentenceRects: sentenceViewRects,
                sentenceColor: UIColor(colors.sentenceColor).withAlphaComponent(0.22),
                wordRect: wordViewRect,
                wordColor: UIColor(colors.wordColor).withAlphaComponent(0.35),
                wordBorderColor: UIColor(colors.wordColor)
            )
        }
    }
}
