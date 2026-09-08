//
//  PDFReaderView.swift
//  Vachanam
//
//  PDFKit PDFView wrapper with page synchronization and text selection.
//

import SwiftUI
import PDFKit

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
        
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )
        
        context.coordinator.pdfView = pdfView
        
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
        
        init(_ parent: PDFReaderView) {
            self.parent = parent
        }
        
        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = pdfView, let page = pdfView.currentPage else { return }
            let index = parent.document.pdfDocument.index(for: page)
            if index != parent.currentPageIndex && index >= 0 {
                DispatchQueue.main.async {
                    self.parent.currentPageIndex = index
                }
            }
        }
    }
}
