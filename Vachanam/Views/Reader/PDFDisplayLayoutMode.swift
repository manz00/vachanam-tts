//
//  PDFDisplayLayoutMode.swift
//  Vachanam
//
//  Display layout modes for PDFKit rendering: single-page paging, continuous vertical scrolling,
//  and two-page book spreads.
//

import SwiftUI
import PDFKit

public enum PDFDisplayLayoutMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case singlePage = "Single Page"
    case singlePageContinuous = "Continuous Scroll"
    case twoUp = "Two-Page Spread"
    case twoUpContinuous = "Continuous Spread"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .singlePage: return "doc.text"
        case .singlePageContinuous: return "arrow.up.arrow.down"
        case .twoUp: return "book.pages"
        case .twoUpContinuous: return "book.pages.fill"
        }
    }
    
    public var pdfDisplayMode: PDFDisplayMode {
        switch self {
        case .singlePage: return .singlePage
        case .singlePageContinuous: return .singlePageContinuous
        case .twoUp: return .twoUp
        case .twoUpContinuous: return .twoUpContinuous
        }
    }
    
    public var pdfDisplayDirection: PDFDisplayDirection {
        switch self {
        case .singlePage: return .horizontal
        case .singlePageContinuous: return .vertical
        case .twoUp: return .horizontal
        case .twoUpContinuous: return .vertical
        }
    }
    
    public var usesPageViewController: Bool {
        return self == .singlePage
    }
}
