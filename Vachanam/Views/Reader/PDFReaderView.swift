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
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        sentenceLayers.forEach { $0.isHidden = true }
        wordLayer.isHidden = true
        CATransaction.commit()
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
        
        // Re-use or lazily allocate sentence layers
        while sentenceLayers.count < sentenceRects.count {
            let l = CALayer()
            l.cornerRadius = 4.0
            layer.insertSublayer(l, below: wordLayer)
            sentenceLayers.append(l)
        }
        
        for (idx, rect) in sentenceRects.enumerated() {
            let l = sentenceLayers[idx]
            l.frame = rect
            l.backgroundColor = sentenceColor.cgColor
            l.isHidden = false
        }
        
        // Hide any unused sentence layers
        if sentenceLayers.count > sentenceRects.count {
            for idx in sentenceRects.count..<sentenceLayers.count {
                sentenceLayers[idx].isHidden = true
            }
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

/// Sanitizes PDFKit internal hit-testing to prevent UIKit assertions when internal tracking views
/// (such as `PDFAnnotationPointerTrackingView`) are returned while detached from the window hierarchy (`window == nil`).
private enum PDFDocumentViewHitTestSanitizer {
    private static var isSwizzled = false
    
    static func applyIfNeeded() {
        guard !isSwizzled else { return }
        isSwizzled = true
        
        guard let docViewClass = NSClassFromString("PDFDocumentView") else { return }
        let originalSelector = #selector(UIView.hitTest(_:with:))
        let swizzledSelector = #selector(UIView.vachanam_safePDFDocumentViewHitTest(_:with:))
        
        guard let originalMethod = class_getInstanceMethod(docViewClass, originalSelector),
              let swizzledMethod = class_getInstanceMethod(UIView.self, swizzledSelector) else {
            return
        }
        
        let didAdd = class_addMethod(
            docViewClass,
            swizzledSelector,
            method_getImplementation(originalMethod),
            method_getTypeEncoding(originalMethod)
        )
        if didAdd {
            class_replaceMethod(
                docViewClass,
                originalSelector,
                method_getImplementation(swizzledMethod),
                method_getTypeEncoding(swizzledMethod)
            )
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
    }
}

extension UIView {
    @objc func vachanam_safePDFDocumentViewHitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = self.vachanam_safePDFDocumentViewHitTest(point, with: event)
        // If PDFKit returns a detached or orphan view (e.g. PDFAnnotationPointerTrackingView with window == nil),
        // fallback to self (the PDFDocumentView) which resides in the window hierarchy.
        if let result = result, result.window == nil {
            return self
        }
        return result
    }
}

public class VachanamPDFView: PDFView {
    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        if let result = result, result.window == nil {
            return self
        }
        return result
    }
}

public struct PDFReaderView: UIViewRepresentable {
    public let document: ReaderDocument
    @Binding public var currentPageIndex: Int
    public var layoutMode: PDFDisplayLayoutMode
    
    public init(
        document: ReaderDocument,
        currentPageIndex: Binding<Int>,
        layoutMode: PDFDisplayLayoutMode = AccessibilityManager.shared.pdfDisplayLayout
    ) {
        self.document = document
        self._currentPageIndex = currentPageIndex
        self.layoutMode = layoutMode
    }
    
    public func makeUIView(context: Context) -> PDFView {
        PDFDocumentViewHitTestSanitizer.applyIfNeeded()
        let pdfView = VachanamPDFView()
        pdfView.document = document.pdfDocument
        pdfView.autoScales = true
        pdfView.displayMode = layoutMode.pdfDisplayMode
        pdfView.displayDirection = layoutMode.pdfDisplayDirection
        pdfView.usePageViewController(layoutMode.usesPageViewController)
        pdfView.backgroundColor = UIColor(Color(red: 0.05, green: 0.08, blue: 0.13))
        
        let overlayView = PDFHighlightOverlayView()
        overlayView.backgroundColor = .clear
        overlayView.isUserInteractionEnabled = false
        overlayView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlayView.frame = pdfView.bounds
        pdfView.addSubview(overlayView)
        pdfView.bringSubviewToFront(overlayView)
        
        // Tap-to-speak gesture recognizer
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tapGesture.cancelsTouchesInView = false
        pdfView.addGestureRecognizer(tapGesture)
        
        context.coordinator.pdfView = pdfView
        context.coordinator.overlayView = overlayView
        context.coordinator.setupObservers()
        context.coordinator.attachScrollObserver()
        
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
        
        if uiView.displayMode != layoutMode.pdfDisplayMode {
            uiView.displayMode = layoutMode.pdfDisplayMode
            uiView.displayDirection = layoutMode.pdfDisplayDirection
            uiView.usePageViewController(layoutMode.usesPageViewController)
            uiView.autoScales = true
            context.coordinator.attachScrollObserver()
        }
        
        if let current = uiView.currentPage, document.pdfDocument.index(for: current) != currentPageIndex {
            if let target = document.page(at: currentPageIndex) {
                uiView.go(to: target)
            }
        }
        
        if let overlay = context.coordinator.overlayView {
            overlay.frame = uiView.bounds
            uiView.bringSubviewToFront(overlay)
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
        private var scrollObserver: NSKeyValueObservation?
        
        init(_ parent: PDFReaderView) {
            self.parent = parent
        }
        
        deinit {
            scrollObserver?.invalidate()
        }
        
        func attachScrollObserver() {
            scrollObserver?.invalidate()
            scrollObserver = nil
            
            guard let pdfView = pdfView else { return }
            // Find internal UIScrollView inside PDFView
            if let scrollView = pdfView.subviews.compactMap({ $0 as? UIScrollView }).first {
                scrollObserver = scrollView.observe(\.contentOffset, options: [.new]) { [weak self] sv, _ in
                    self?.updateHighlights()
                    self?.evaluateScrollAwayState(scrollView: sv)
                }
            }
        }
        
        func evaluateScrollAwayState(scrollView: UIScrollView) {
            let coord = PlaybackCoordinator.shared
            guard coord.isPlaying, let currentSentence = coord.currentSentence, let pdfView = pdfView else {
                if coord.isUserScrolledAway {
                    DispatchQueue.main.async {
                        coord.isUserScrolledAway = false
                    }
                }
                return
            }
            
            guard let targetPage = parent.document.page(at: currentSentence.pageIndex) else { return }
            let visibleIndices = Set(pdfView.visiblePages.map { self.parent.document.pdfDocument.index(for: $0) })
            let convertedRect = pdfView.convert(currentSentence.bounds, from: targetPage)
            let visibleViewport = pdfView.bounds.insetBy(dx: 0, dy: 50)
            
            let isSentenceVisible = visibleIndices.contains(currentSentence.pageIndex) && visibleViewport.intersects(convertedRect)
            
            if isSentenceVisible {
                if coord.isUserScrolledAway {
                    DispatchQueue.main.async {
                        coord.isUserScrolledAway = false
                    }
                }
            } else {
                if scrollView.isDragging || scrollView.isTracking || scrollView.isDecelerating || coord.isUserScrolledAway {
                    updateScrolledAwayMetadata(for: currentSentence, convertedRect: convertedRect, visibleViewport: visibleViewport)
                }
            }
        }
        
        func updateScrolledAwayMetadata(for sentence: SentenceItem, convertedRect: CGRect? = nil, visibleViewport: CGRect? = nil) {
            let coord = PlaybackCoordinator.shared
            guard let pdfView = pdfView else { return }
            
            let viewport = visibleViewport ?? pdfView.bounds.insetBy(dx: 0, dy: 50)
            let targetPage = parent.document.page(at: sentence.pageIndex)
            let rect = convertedRect ?? (targetPage.map { pdfView.convert(sentence.bounds, from: $0) } ?? .zero)
            
            let currentVisiblePageIndex = pdfView.currentPage.map { parent.document.pdfDocument.index(for: $0) } ?? parent.currentPageIndex
            
            let direction: ScrolledAwayDirection
            if currentVisiblePageIndex > sentence.pageIndex {
                direction = .above
            } else if currentVisiblePageIndex < sentence.pageIndex {
                direction = .below
            } else {
                if rect.maxY < viewport.minY {
                    direction = .above
                } else {
                    direction = .below
                }
            }
            
            let snippet = sentence.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let shortSnippet = snippet.count > 50 ? String(snippet.prefix(47)) + "..." : snippet
            
            DispatchQueue.main.async {
                coord.isUserScrolledAway = true
                coord.scrolledAwayDirection = direction
                coord.scrolledAwayPageIndex = sentence.pageIndex
                coord.scrolledAwaySnippet = shortSnippet
            }
        }
        
        func setupObservers() {
            cancellables.removeAll()
            
            PlaybackCoordinator.shared.$isPlaying
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.updateHighlights() }
                .store(in: &cancellables)
            
            PlaybackCoordinator.shared.$currentSentence
                .receive(on: RunLoop.main)
                .sink { [weak self] sentence in
                    guard let self = self else { return }
                    if let s = sentence, let pdfView = self.pdfView {
                        let followMode = AccessibilityManager.shared.autoScrollFollowMode
                        
                        if PlaybackCoordinator.shared.isPlaying && followMode != .off {
                            let coord = PlaybackCoordinator.shared
                            if followMode == .alwaysFollow || !coord.isUserScrolledAway {
                                let visibleIndices = Set(pdfView.visiblePages.map { self.parent.document.pdfDocument.index(for: $0) })
                                if let targetPage = self.parent.document.page(at: s.pageIndex) {
                                    let convertedRect = pdfView.convert(s.bounds, from: targetPage)
                                    let visibleViewport = pdfView.bounds.insetBy(dx: 0, dy: 50)
                                    
                                    if !visibleIndices.contains(s.pageIndex) || !visibleViewport.intersects(convertedRect) {
                                        pdfView.go(to: s.bounds, on: targetPage)
                                        DispatchQueue.main.async {
                                            self.parent.currentPageIndex = s.pageIndex
                                            PlaybackCoordinator.shared.setVisiblePageIndex(s.pageIndex)
                                        }
                                    }
                                }
                            } else {
                                // User has scrolled away: do not force call back!
                                self.updateScrolledAwayMetadata(for: s)
                            }
                        }
                    }
                    self.updateHighlights()
                }
                .store(in: &cancellables)
            
            NotificationCenter.default.publisher(for: .jumpToSpokenSentence)
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    guard let self = self,
                          let pdfView = self.pdfView,
                          let s = PlaybackCoordinator.shared.currentSentence,
                          let targetPage = self.parent.document.page(at: s.pageIndex) else {
                        return
                    }
                    pdfView.go(to: s.bounds, on: targetPage)
                    DispatchQueue.main.async {
                        self.parent.currentPageIndex = s.pageIndex
                        PlaybackCoordinator.shared.setVisiblePageIndex(s.pageIndex)
                        PlaybackCoordinator.shared.isUserScrolledAway = false
                        self.updateHighlights()
                    }
                }
                .store(in: &cancellables)
            
            PlaybackCoordinator.shared.$currentWord
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
            
            AccessibilityManager.shared.$pdfDisplayLayout
                .receive(on: RunLoop.main)
                .sink { [weak self] newLayout in
                    guard let self = self, let pdfView = self.pdfView else { return }
                    if pdfView.displayMode != newLayout.pdfDisplayMode {
                        pdfView.displayMode = newLayout.pdfDisplayMode
                        pdfView.displayDirection = newLayout.pdfDisplayDirection
                        pdfView.usePageViewController(newLayout.usesPageViewController)
                        pdfView.autoScales = true
                        if let target = self.parent.document.page(at: self.parent.currentPageIndex) {
                            pdfView.go(to: target)
                        }
                        self.attachScrollObserver()
                        self.updateHighlights()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                            self?.attachScrollObserver()
                            self?.updateHighlights()
                        }
                    }
                }
                .store(in: &cancellables)
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let pdfView = pdfView else { return }
            let pointInView = gesture.location(in: pdfView)
            
            // Accurately resolve page using PDFKit's native hit test
            guard let targetPage = pdfView.page(for: pointInView, nearest: true) else { return }
            let pointInPage = pdfView.convert(pointInView, to: targetPage)
            let pageIndex = parent.document.pdfDocument.index(for: targetPage)
            guard pageIndex >= 0 else { return }
            
            if let doc = PlaybackCoordinator.shared.activeSemanticDocument,
               let word = doc.findWord(at: pointInPage, onPageIndex: pageIndex) {
                PlaybackCoordinator.shared.play(fromWordID: word.globalWordID)
            }
        }
        
        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = pdfView, let page = pdfView.currentPage else { return }
            let index = parent.document.pdfDocument.index(for: page)
            if index != parent.currentPageIndex && index >= 0 {
                DispatchQueue.main.async {
                    self.parent.currentPageIndex = index
                    PlaybackCoordinator.shared.setVisiblePageIndex(index)
                    self.updateHighlights()
                }
            }
        }
        
        @objc func viewScrolledOrScaled(_ notification: Notification) {
            self.updateHighlights()
        }
        
        func updateHighlights() {
            guard let pdfView = pdfView, let overlay = overlayView else { return }
            
            // Keep overlay frame locked to PDFView bounds and at the top of the z-hierarchy
            if overlay.frame != pdfView.bounds {
                overlay.frame = pdfView.bounds
            }
            pdfView.bringSubviewToFront(overlay)
            
            let coord = PlaybackCoordinator.shared
            let isHighlightActive = coord.isPlaying || coord.isGenerating
            let sentence = coord.currentSentence
            let word = coord.currentWord
            let mode = AccessibilityManager.shared.highlightMode
            let colors = AccessibilityManager.shared.colorChoice
            
            guard isHighlightActive, let currentSentence = sentence else {
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
            
            // In continuous scroll or two-up spread, multiple pages are visible simultaneously
            let visiblePages = pdfView.visiblePages
            let visibleIndices = Set(visiblePages.map { parent.document.pdfDocument.index(for: $0) })
            let isTransitioning = visiblePages.isEmpty
            
            // Convert sentence line bounds from PDF page space to View space across all visible pages
            var sentenceViewRects: [CGRect] = []
            if mode == .both || mode == .sentenceOnly {
                let pagesToCheck: [Int]
                if let doc = coord.activeSemanticDocument,
                   let semSentence = doc.sentence(id: currentSentence.sentenceIndex) {
                    pagesToCheck = Array(semSentence.pageSpans)
                } else {
                    pagesToCheck = [currentSentence.pageIndex]
                }
                
                for pageIdx in pagesToCheck {
                    if isTransitioning || visibleIndices.contains(pageIdx) {
                        if let pageObj = parent.document.page(at: pageIdx) {
                            if let doc = coord.activeSemanticDocument,
                               let semSentence = doc.sentence(id: currentSentence.sentenceIndex) {
                                let rects = semSentence.lineBounds(for: pageIdx).map { lineBound in
                                    pdfView.convert(lineBound, from: pageObj)
                                }
                                sentenceViewRects.append(contentsOf: rects)
                            } else if pageIdx == currentSentence.pageIndex {
                                let rects = currentSentence.lineBounds.map { lineBound in
                                    pdfView.convert(lineBound, from: pageObj)
                                }
                                sentenceViewRects.append(contentsOf: rects)
                            }
                        }
                    }
                }
            }
            
            // Convert word bounds from PDF page space to View space
            var wordViewRect: CGRect? = nil
            if (mode == .both || mode == .wordOnly),
               let currentWord = word,
               (isTransitioning || visibleIndices.contains(currentWord.pageIndex)),
               let wordPage = parent.document.page(at: currentWord.pageIndex) {
                wordViewRect = pdfView.convert(currentWord.bounds, from: wordPage)
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
