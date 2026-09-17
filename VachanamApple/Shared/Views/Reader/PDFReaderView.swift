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
    var onFirstLayout: (() -> Void)?
    private var hasLaidOut = false
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        if !hasLaidOut && bounds.width > 0 && bounds.height > 0 {
            hasLaidOut = true
            onFirstLayout?()
        }
    }
    
    public override var canBecomeFirstResponder: Bool {
        return true
    }
    
    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        if let result = result, result.window == nil {
            return self
        }
        return result
    }
    
    public override var keyCommands: [UIKeyCommand]? {
        let prevPage = UIKeyCommand(title: "Previous Page", image: nil, action: #selector(pdfKeyPrevPage), input: UIKeyCommand.inputLeftArrow, modifierFlags: [])
        let nextPage = UIKeyCommand(title: "Next Page", image: nil, action: #selector(pdfKeyNextPage), input: UIKeyCommand.inputRightArrow, modifierFlags: [])
        let upPage = UIKeyCommand(title: "Scroll Up / Prev", image: nil, action: #selector(pdfKeyUp), input: UIKeyCommand.inputUpArrow, modifierFlags: [])
        let downPage = UIKeyCommand(title: "Scroll Down / Next", image: nil, action: #selector(pdfKeyDown), input: UIKeyCommand.inputDownArrow, modifierFlags: [])
        let pageUp = UIKeyCommand(title: "Page Up", image: nil, action: #selector(pdfKeyPageUp), input: UIKeyCommand.inputPageUp, modifierFlags: [])
        let pageDown = UIKeyCommand(title: "Page Down", image: nil, action: #selector(pdfKeyPageDown), input: UIKeyCommand.inputPageDown, modifierFlags: [])
        let space = UIKeyCommand(title: "Space Scroll / Page", image: nil, action: #selector(pdfKeySpace), input: " ", modifierFlags: [])
        let shiftSpace = UIKeyCommand(title: "Shift Space Scroll Up", image: nil, action: #selector(pdfKeyShiftSpace), input: " ", modifierFlags: .shift)
        let home = UIKeyCommand(title: "First Page", image: nil, action: #selector(pdfKeyFirstPage), input: UIKeyCommand.inputHome, modifierFlags: [])
        let end = UIKeyCommand(title: "Last Page", image: nil, action: #selector(pdfKeyLastPage), input: UIKeyCommand.inputEnd, modifierFlags: [])
        let cmdLeft = UIKeyCommand(title: "First Page", image: nil, action: #selector(pdfKeyFirstPage), input: UIKeyCommand.inputLeftArrow, modifierFlags: .command)
        let cmdRight = UIKeyCommand(title: "Last Page", image: nil, action: #selector(pdfKeyLastPage), input: UIKeyCommand.inputRightArrow, modifierFlags: .command)
        let zoomInPlus = UIKeyCommand(title: "Zoom In", image: nil, action: #selector(pdfKeyZoomIn), input: "+", modifierFlags: .command)
        let zoomInEquals = UIKeyCommand(title: "Zoom In", image: nil, action: #selector(pdfKeyZoomIn), input: "=", modifierFlags: .command)
        let zoomOut = UIKeyCommand(title: "Zoom Out", image: nil, action: #selector(pdfKeyZoomOut), input: "-", modifierFlags: .command)
        let zoomReset = UIKeyCommand(title: "Actual Size", image: nil, action: #selector(pdfKeyResetZoom), input: "0", modifierFlags: .command)
        
        return [prevPage, nextPage, upPage, downPage, pageUp, pageDown, space, shiftSpace, home, end, cmdLeft, cmdRight, zoomInPlus, zoomInEquals, zoomOut, zoomReset]
    }
    
    @objc func pdfKeyPrevPage() {
        NotificationCenter.default.post(name: .readerGoToPreviousPage, object: nil)
    }
    
    @objc func pdfKeyNextPage() {
        NotificationCenter.default.post(name: .readerGoToNextPage, object: nil)
    }
    
    @objc func pdfKeyUp() {
        NotificationCenter.default.post(name: .readerScrollUp, object: nil)
    }
    
    @objc func pdfKeyDown() {
        NotificationCenter.default.post(name: .readerScrollDown, object: nil)
    }
    
    @objc func pdfKeyPageUp() {
        NotificationCenter.default.post(name: .readerPageUp, object: nil)
    }
    
    @objc func pdfKeyPageDown() {
        NotificationCenter.default.post(name: .readerPageDown, object: nil)
    }
    
    @objc func pdfKeySpace() {
        NotificationCenter.default.post(name: .readerPageDown, object: nil)
    }
    
    @objc func pdfKeyShiftSpace() {
        NotificationCenter.default.post(name: .readerPageUp, object: nil)
    }
    
    @objc func pdfKeyFirstPage() {
        NotificationCenter.default.post(name: .readerGoToFirstPage, object: nil)
    }
    
    @objc func pdfKeyLastPage() {
        NotificationCenter.default.post(name: .readerGoToLastPage, object: nil)
    }
    
    @objc func pdfKeyZoomIn() {
        NotificationCenter.default.post(name: .readerZoomIn, object: nil)
    }
    
    @objc func pdfKeyZoomOut() {
        NotificationCenter.default.post(name: .readerZoomOut, object: nil)
    }
    
    @objc func pdfKeyResetZoom() {
        NotificationCenter.default.post(name: .readerResetZoom, object: nil)
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
        PDFLoggingSanitizer.shared.install()
        let pdfView = VachanamPDFView()
        pdfView.document = document.pdfDocument
        pdfView.autoScales = true
        pdfView.displayMode = layoutMode.pdfDisplayMode
        pdfView.displayDirection = layoutMode.pdfDisplayDirection
        pdfView.usePageViewController(false)
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
        
        // Horizontal swipe gestures for page navigation
        let swipeLeft = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleSwipeLeft(_:)))
        swipeLeft.direction = .left
        swipeLeft.cancelsTouchesInView = false
        swipeLeft.delegate = context.coordinator
        pdfView.addGestureRecognizer(swipeLeft)
        
        let swipeRight = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleSwipeRight(_:)))
        swipeRight.direction = .right
        swipeRight.cancelsTouchesInView = false
        swipeRight.delegate = context.coordinator
        pdfView.addGestureRecognizer(swipeRight)
        
        context.coordinator.pdfView = pdfView
        context.coordinator.overlayView = overlayView
        context.coordinator.lastAppliedLayoutMode = layoutMode
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
        
        pdfView.onFirstLayout = { [weak pdfView, weak coordinator = context.coordinator] in
            guard let pdfView = pdfView, let coordinator = coordinator else { return }
            let targetIndex = coordinator.parent.currentPageIndex
            if let target = pdfView.document?.page(at: targetIndex) {
                coordinator.isProgrammaticScroll = true
                pdfView.go(to: target)
                coordinator.lastHandledPageIndex = targetIndex
                coordinator.updateHighlights()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    coordinator.isProgrammaticScroll = false
                }
            }
        }
        
        return pdfView
    }
    
    public func updateUIView(_ uiView: PDFView, context: Context) {
        if context.coordinator.isHandlingPageChange {
            return
        }
        
        if uiView.document != document.pdfDocument {
            uiView.document = document.pdfDocument
        }
        
        let layoutChanged = context.coordinator.lastAppliedLayoutMode != layoutMode
        if layoutChanged {
            context.coordinator.lastAppliedLayoutMode = layoutMode
            context.coordinator.isProgrammaticScroll = true
            uiView.displayMode = layoutMode.pdfDisplayMode
            uiView.displayDirection = layoutMode.pdfDisplayDirection
            uiView.usePageViewController(false)
            uiView.autoScales = true
            
            let targetIndex = currentPageIndex
            context.coordinator.lastHandledPageIndex = targetIndex
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak uiView, weak coordinator = context.coordinator] in
                guard let uiView = uiView, let coordinator = coordinator else { return }
                if let target = uiView.document?.page(at: targetIndex) {
                    uiView.go(to: target)
                }
                coordinator.attachScrollObserver()
                coordinator.updateHighlights()
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak coordinator = context.coordinator] in
                coordinator?.isProgrammaticScroll = false
            }
        } else if context.coordinator.scrollObserver == nil {
            context.coordinator.attachScrollObserver()
        }
        
        if !layoutChanged {
            if context.coordinator.lastHandledPageIndex != currentPageIndex {
                // Programmatic page change from scrubber, keyboard shortcuts, buttons, TOC, or thumbnails.
                context.coordinator.lastHandledPageIndex = currentPageIndex
                context.coordinator.isProgrammaticScroll = true
                let targetIndex = currentPageIndex
                DispatchQueue.main.async { [weak uiView, weak coordinator = context.coordinator] in
                    guard let uiView = uiView, let coordinator = coordinator else { return }
                    if let target = uiView.document?.page(at: targetIndex) {
                        uiView.go(to: target)
                        coordinator.updateHighlights()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            coordinator.isProgrammaticScroll = false
                        }
                    } else {
                        coordinator.isProgrammaticScroll = false
                    }
                }
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
    
    public class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: PDFReaderView
        weak var pdfView: PDFView?
        weak var overlayView: PDFHighlightOverlayView?
        private var cancellables = Set<AnyCancellable>()
        var scrollObserver: NSKeyValueObservation?
        
        var lastHandledPageIndex: Int = -1
        var isProgrammaticScroll: Bool = false
        var isHandlingPageChange: Bool = false
        var lastAppliedLayoutMode: PDFDisplayLayoutMode?
        var lastUserScrollTime: Date = .distantPast
        
        var internalScrollView: UIScrollView? {
            guard let pdfView = pdfView else { return nil }
            return findScrollView(in: pdfView)
        }
        
        var isUserScrolling: Bool {
            if Date().timeIntervalSince(lastUserScrollTime) < 0.6 {
                return true
            }
            guard let sv = internalScrollView else { return false }
            return sv.isDragging || sv.isTracking || sv.isDecelerating
        }
        
        private func findScrollView(in view: UIView) -> UIScrollView? {
            if let sv = view as? UIScrollView { return sv }
            for sub in view.subviews {
                if let found = findScrollView(in: sub) { return found }
            }
            return nil
        }
        
        init(_ parent: PDFReaderView) {
            self.parent = parent
        }
        
        deinit {
            scrollObserver?.invalidate()
        }
        
        func attachScrollObserver(retryCount: Int = 3) {
            scrollObserver?.invalidate()
            scrollObserver = nil
            
            guard let pdfView = pdfView else { return }
            if let scrollView = findScrollView(in: pdfView) {
                #if targetEnvironment(macCatalyst)
                if self.parent.layoutMode.pdfDisplayDirection == .horizontal {
                    scrollView.showsHorizontalScrollIndicator = true
                    scrollView.showsVerticalScrollIndicator = false
                } else {
                    scrollView.showsVerticalScrollIndicator = true
                    scrollView.showsHorizontalScrollIndicator = false
                }
                #endif
                scrollObserver = scrollView.observe(\.contentOffset, options: [.new]) { [weak self] sv, _ in
                    guard let self = self else { return }
                    if !self.isProgrammaticScroll {
                        self.lastUserScrollTime = Date()
                        self.evaluateScrollAwayState(scrollView: sv)
                    }
                    self.updateHighlights()
                }
            } else if retryCount > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                    self?.attachScrollObserver(retryCount: retryCount - 1)
                }
            }
        }
        
        func evaluateScrollAwayState(scrollView: UIScrollView) {
            if isProgrammaticScroll { return }
            
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
                    let isUserInteracting = scrollView.isDragging || scrollView.isTracking || scrollView.isDecelerating
                    if !isUserInteracting {
                        DispatchQueue.main.async {
                            coord.isUserScrolledAway = false
                        }
                    }
                }
            } else {
                updateScrolledAwayMetadata(for: currentSentence, convertedRect: convertedRect, visibleViewport: visibleViewport)
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
                        let coord = PlaybackCoordinator.shared
                        
                        if coord.isPlaying && followMode != .off {
                            let isUserInteracting = self.isUserScrolling
                            if !coord.isUserScrolledAway && !isUserInteracting {
                                let visibleIndices = Set(pdfView.visiblePages.map { self.parent.document.pdfDocument.index(for: $0) })
                                if let targetPage = self.parent.document.page(at: s.pageIndex) {
                                    let convertedRect = pdfView.convert(s.bounds, from: targetPage)
                                    let visibleViewport = pdfView.bounds.insetBy(dx: 0, dy: 50)
                                    
                                    if !visibleIndices.contains(s.pageIndex) || !visibleViewport.intersects(convertedRect) {
                                        self.isProgrammaticScroll = true
                                        pdfView.go(to: s.bounds, on: targetPage)
                                        self.lastHandledPageIndex = s.pageIndex
                                        DispatchQueue.main.async {
                                            self.isProgrammaticScroll = false
                                            if self.parent.currentPageIndex != s.pageIndex {
                                                self.parent.currentPageIndex = s.pageIndex
                                            }
                                            PlaybackCoordinator.shared.setVisiblePageIndex(s.pageIndex)
                                        }
                                    }
                                }
                            } else {
                                // Auto-follow paused: update metadata for the Resume button
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
                    self.isProgrammaticScroll = true
                    pdfView.go(to: s.bounds, on: targetPage)
                    self.lastHandledPageIndex = s.pageIndex
                    DispatchQueue.main.async {
                        if self.parent.currentPageIndex != s.pageIndex {
                            self.parent.currentPageIndex = s.pageIndex
                        }
                        PlaybackCoordinator.shared.setVisiblePageIndex(s.pageIndex)
                        PlaybackCoordinator.shared.isUserScrolledAway = false
                        self.updateHighlights()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            self.isProgrammaticScroll = false
                        }
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
            
            NotificationCenter.default.publisher(for: .readerGoToNextPage)
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.handleNextPage() }
                .store(in: &cancellables)
            
            NotificationCenter.default.publisher(for: .readerGoToPreviousPage)
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.handlePreviousPage() }
                .store(in: &cancellables)
            
            NotificationCenter.default.publisher(for: .readerGoToFirstPage)
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.handleFirstPage() }
                .store(in: &cancellables)
            
            NotificationCenter.default.publisher(for: .readerGoToLastPage)
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.handleLastPage() }
                .store(in: &cancellables)
            
            NotificationCenter.default.publisher(for: .readerScrollDown)
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    guard let self = self else { return }
                    if self.parent.layoutMode == .singlePageContinuous || self.parent.layoutMode == .twoUpContinuous {
                        self.scrollBy(offset: 140)
                    } else {
                        self.handleNextPage()
                    }
                }
                .store(in: &cancellables)
            
            NotificationCenter.default.publisher(for: .readerScrollUp)
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    guard let self = self else { return }
                    if self.parent.layoutMode == .singlePageContinuous || self.parent.layoutMode == .twoUpContinuous {
                        self.scrollBy(offset: -140)
                    } else {
                        self.handlePreviousPage()
                    }
                }
                .store(in: &cancellables)
            
            NotificationCenter.default.publisher(for: .readerPageDown)
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.handlePageDown() }
                .store(in: &cancellables)
            
            NotificationCenter.default.publisher(for: .readerPageUp)
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.handlePageUp() }
                .store(in: &cancellables)
            
            NotificationCenter.default.publisher(for: .readerZoomIn)
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.pdfView?.zoomIn(nil) }
                .store(in: &cancellables)
            
            NotificationCenter.default.publisher(for: .readerZoomOut)
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.pdfView?.zoomOut(nil) }
                .store(in: &cancellables)
            
            NotificationCenter.default.publisher(for: .readerResetZoom)
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    guard let pdf = self?.pdfView else { return }
                    pdf.autoScales = true
                    pdf.scaleFactor = pdf.scaleFactorForSizeToFit
                }
                .store(in: &cancellables)
            
            NotificationCenter.default.publisher(for: .readerJumpToPage)
                .receive(on: RunLoop.main)
                .sink { [weak self] notification in
                    guard let self = self, let targetIndex = notification.userInfo?["pageIndex"] as? Int else { return }
                    if let targetPage = self.parent.document.page(at: targetIndex) {
                        self.isProgrammaticScroll = true
                        self.pdfView?.go(to: targetPage)
                        self.lastHandledPageIndex = targetIndex
                        self.updateHighlights()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            self.isProgrammaticScroll = false
                        }
                    }
                }
                .store(in: &cancellables)
        }
        
        public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
        
        @objc func handleSwipeLeft(_ gesture: UISwipeGestureRecognizer) {
            guard parent.layoutMode == .singlePage || parent.layoutMode == .twoUp else { return }
            guard let pdfView = pdfView else { return }
            
            // If zoomed in, only turn page when at the far right edge of the page
            if let sv = internalScrollView, pdfView.scaleFactor > (pdfView.scaleFactorForSizeToFit * 1.15) {
                let atRightEdge = sv.contentOffset.x >= (sv.contentSize.width - sv.bounds.width - 25)
                guard atRightEdge else { return }
            }
            
            handleNextPage()
        }
        
        @objc func handleSwipeRight(_ gesture: UISwipeGestureRecognizer) {
            guard parent.layoutMode == .singlePage || parent.layoutMode == .twoUp else { return }
            guard let pdfView = pdfView else { return }
            
            // If zoomed in, only turn page when at the far left edge of the page
            if let sv = internalScrollView, pdfView.scaleFactor > (pdfView.scaleFactorForSizeToFit * 1.15) {
                let atLeftEdge = sv.contentOffset.x <= 25
                guard atLeftEdge else { return }
            }
            
            handlePreviousPage()
        }
        
        func handleNextPage() {
            guard let pdfView = pdfView else { return }
            let nextIndex = min(parent.currentPageIndex + 1, parent.document.pageCount - 1)
            guard nextIndex != parent.currentPageIndex else { return }
            if let target = parent.document.page(at: nextIndex) {
                isProgrammaticScroll = true
                pdfView.go(to: target)
                lastHandledPageIndex = nextIndex
                parent.currentPageIndex = nextIndex
                PlaybackCoordinator.shared.setVisiblePageIndex(nextIndex)
                updateHighlights()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                    self?.isProgrammaticScroll = false
                }
            }
        }
        
        func handlePreviousPage() {
            guard let pdfView = pdfView else { return }
            let prevIndex = max(parent.currentPageIndex - 1, 0)
            guard prevIndex != parent.currentPageIndex else { return }
            if let target = parent.document.page(at: prevIndex) {
                isProgrammaticScroll = true
                pdfView.go(to: target)
                lastHandledPageIndex = prevIndex
                parent.currentPageIndex = prevIndex
                PlaybackCoordinator.shared.setVisiblePageIndex(prevIndex)
                updateHighlights()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                    self?.isProgrammaticScroll = false
                }
            }
        }
        
        func handlePageDown() {
            guard let pdfView = pdfView else { return }
            if parent.layoutMode == .singlePage || parent.layoutMode == .twoUp {
                handleNextPage()
            } else {
                scrollBy(offset: pdfView.bounds.height * 0.85)
            }
        }
        
        func handlePageUp() {
            guard let pdfView = pdfView else { return }
            if parent.layoutMode == .singlePage || parent.layoutMode == .twoUp {
                handlePreviousPage()
            } else {
                scrollBy(offset: -pdfView.bounds.height * 0.85)
            }
        }
        
        func handleFirstPage() {
            guard let pdfView = pdfView else { return }
            if parent.layoutMode == .singlePage || parent.layoutMode == .twoUp {
                if pdfView.canGoToFirstPage {
                    isProgrammaticScroll = true
                    pdfView.goToFirstPage(nil)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                        self?.isProgrammaticScroll = false
                    }
                } else {
                    if parent.currentPageIndex != 0 {
                        parent.currentPageIndex = 0
                    }
                }
            } else {
                scrollToTop()
            }
        }
        
        func handleLastPage() {
            guard let pdfView = pdfView else { return }
            if parent.layoutMode == .singlePage || parent.layoutMode == .twoUp {
                if pdfView.canGoToLastPage {
                    isProgrammaticScroll = true
                    pdfView.goToLastPage(nil)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                        self?.isProgrammaticScroll = false
                    }
                } else {
                    let lastIdx = max(0, parent.document.pageCount - 1)
                    if parent.currentPageIndex != lastIdx {
                        parent.currentPageIndex = lastIdx
                    }
                }
            } else {
                scrollToBottom()
            }
        }
        
        func scrollBy(offset: CGFloat, animated: Bool = true) {
            guard let sv = internalScrollView else { return }
            let targetY = max(0, min(sv.contentOffset.y + offset, max(0, sv.contentSize.height - sv.bounds.height)))
            sv.setContentOffset(CGPoint(x: sv.contentOffset.x, y: targetY), animated: animated)
        }
        
        func scrollToTop(animated: Bool = true) {
            guard let sv = internalScrollView else { return }
            sv.setContentOffset(CGPoint(x: sv.contentOffset.x, y: 0), animated: animated)
        }
        
        func scrollToBottom(animated: Bool = true) {
            guard let sv = internalScrollView else { return }
            let maxY = max(0, sv.contentSize.height - sv.bounds.height)
            sv.setContentOffset(CGPoint(x: sv.contentOffset.x, y: maxY), animated: animated)
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
            guard !isProgrammaticScroll else { return }
            guard !isHandlingPageChange else { return }
            guard let pdfView = pdfView else { return }
            
            // In two-up spread modes, check if current page index is already visible
            let reportedPage = pdfView.currentPage
            let visiblePages = pdfView.visiblePages
            let targetPage: PDFPage?
            if (parent.layoutMode == .twoUp || parent.layoutMode == .twoUpContinuous), !visiblePages.isEmpty {
                let visibleIndices = visiblePages.map { parent.document.pdfDocument.index(for: $0) }
                if visibleIndices.contains(parent.currentPageIndex) {
                    // Current page index is already visible on the spread; preserve it
                    return
                }
                targetPage = visiblePages.first ?? reportedPage
            } else {
                targetPage = reportedPage
            }
            
            guard let page = targetPage else { return }
            let index = parent.document.pdfDocument.index(for: page)
            guard index >= 0 else { return }
            if lastHandledPageIndex == index { return }
            lastHandledPageIndex = index
            if parent.currentPageIndex != index {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    guard !self.isProgrammaticScroll else { return }
                    self.isHandlingPageChange = true
                    if self.parent.currentPageIndex != index {
                        self.parent.currentPageIndex = index
                    }
                    PlaybackCoordinator.shared.setVisiblePageIndex(index)
                    self.updateHighlights()
                    self.isHandlingPageChange = false
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
                if AccessibilityManager.shared.isReadingRulerEnabled && TTSController.shared.currentSentenceViewRect != nil {
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
                var wRect = pdfView.convert(currentWord.bounds, from: wordPage)
                // If a matching sentence line rect covers this word, clamp the word height and Y alignment
                // so word highlights are never taller than the sentence line and never bleed into adjacent lines
                if let matchingLine = sentenceViewRects.first(where: { abs($0.midY - wRect.midY) < max(wRect.height, $0.height) * 0.6 }) {
                    if wRect.height > matchingLine.height {
                        wRect = CGRect(x: wRect.minX, y: matchingLine.minY, width: wRect.width, height: matchingLine.height)
                    }
                }
                wordViewRect = wRect
            }
            
            // Update tracking rects for ruler asynchronously if ruler is enabled
            if AccessibilityManager.shared.isReadingRulerEnabled {
                let firstLine = sentenceViewRects.first
                if TTSController.shared.currentSentenceViewRect != firstLine {
                    DispatchQueue.main.async {
                        if TTSController.shared.currentSentenceViewRect != firstLine {
                            TTSController.shared.currentSentenceViewRect = firstLine
                        }
                    }
                }
            } else if TTSController.shared.currentSentenceViewRect != nil {
                DispatchQueue.main.async {
                    if TTSController.shared.currentSentenceViewRect != nil {
                        TTSController.shared.currentSentenceViewRect = nil
                    }
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
