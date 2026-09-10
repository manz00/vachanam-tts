//
//  ReaderScrubberBar.swift
//  Vachanam
//
//  Floating page scrubber and quick navigation toolbar with live scrubbing, page jump, and zoom controls.
//

import SwiftUI

public struct ReaderScrubberBar: View {
    @Binding public var currentPageIndex: Int
    public let totalPages: Int
    public let isPDF: Bool
    
    @State private var isScrubbing: Bool = false
    @State private var scrubbedPageIndex: Double = 0.0
    @State private var isJumpPopoverPresented: Bool = false
    @State private var jumpTargetPageString: String = ""
    @State private var isShortcutsPresented: Bool = false
    
    public init(currentPageIndex: Binding<Int>, totalPages: Int, isPDF: Bool = true) {
        self._currentPageIndex = currentPageIndex
        self.totalPages = totalPages
        self.isPDF = isPDF
        self._scrubbedPageIndex = State(initialValue: Double(currentPageIndex.wrappedValue))
    }
    
    private var displayedPage: Int {
        if isScrubbing {
            return min(max(Int(scrubbedPageIndex.rounded()), 0), max(0, totalPages - 1))
        }
        return min(max(currentPageIndex, 0), max(0, totalPages - 1))
    }
    
    public var body: some View {
        HStack(spacing: 10) {
            // First Page Button
            Button {
                NotificationCenter.default.post(name: .readerGoToFirstPage, object: nil)
            } label: {
                Image(systemName: "arrow.up.to.line")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(currentPageIndex > 0 ? .white.opacity(0.85) : .white.opacity(0.3))
            }
            .disabled(currentPageIndex <= 0)
            .help("First Page (Home or ⌘←)")
            
            // Previous Page Button
            Button {
                NotificationCenter.default.post(name: .readerGoToPreviousPage, object: nil)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(currentPageIndex > 0 ? Color.amberAccent : .white.opacity(0.3))
            }
            .disabled(currentPageIndex <= 0)
            .help("Previous Page (← or ↑)")
            
            // Interactive Page Scrubber Slider
            if totalPages > 1 {
                Slider(
                    value: Binding(
                        get: { scrubbedPageIndex },
                        set: { newValue in
                            scrubbedPageIndex = newValue
                            if !isScrubbing {
                                isScrubbing = true
                            }
                        }
                    ),
                    in: 0...Double(max(1, totalPages - 1)),
                    step: 1.0,
                    onEditingChanged: { editing in
                        isScrubbing = editing
                        if !editing {
                            let target = min(max(Int(scrubbedPageIndex.rounded()), 0), totalPages - 1)
                            currentPageIndex = target
                            NotificationCenter.default.post(
                                name: .readerJumpToPage,
                                object: nil,
                                userInfo: ["pageIndex": target]
                            )
                        }
                    }
                )
                .accentColor(Color.amberAccent)
                .frame(minWidth: 120, maxWidth: 280)
            }
            
            // Next Page Button
            Button {
                NotificationCenter.default.post(name: .readerGoToNextPage, object: nil)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(currentPageIndex < totalPages - 1 ? Color.amberAccent : .white.opacity(0.3))
            }
            .disabled(currentPageIndex >= totalPages - 1)
            .help("Next Page (→ or ↓)")
            
            // Last Page Button
            Button {
                NotificationCenter.default.post(name: .readerGoToLastPage, object: nil)
            } label: {
                Image(systemName: "arrow.down.to.line")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(currentPageIndex < totalPages - 1 ? .white.opacity(0.85) : .white.opacity(0.3))
            }
            .disabled(currentPageIndex >= totalPages - 1)
            .help("Last Page (End or ⌘→)")
            
            Divider()
                .frame(height: 18)
                .background(Color.white.opacity(0.2))
            
            // Page Number Badge Button (Tap to Jump to Page)
            Button {
                jumpTargetPageString = "\(displayedPage + 1)"
                isJumpPopoverPresented = true
            } label: {
                HStack(spacing: 4) {
                    Text("\(displayedPage + 1)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Color.amberAccent)
                    Text("/ \(totalPages)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.10))
                .cornerRadius(6)
            }
            .help("Jump to Page (⌘J)")
            .popover(isPresented: $isJumpPopoverPresented) {
                VStack(spacing: 12) {
                    Text("Go to Page")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 8) {
                        TextField("Page (1–\(totalPages))", text: $jumpTargetPageString)
                            #if !os(macOS)
                            .keyboardType(.numberPad)
                            #endif
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 90)
                            .onSubmit {
                                performJump()
                            }
                        
                        Button("Go") {
                            performJump()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.amberAccent)
                    }
                }
                .padding(16)
                .background(Color(red: 0.12, green: 0.16, blue: 0.22))
            }
            
            if isPDF {
                Divider()
                    .frame(height: 18)
                    .background(Color.white.opacity(0.2))
                
                // Zoom Out
                Button {
                    NotificationCenter.default.post(name: .readerZoomOut, object: nil)
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.85))
                }
                .help("Zoom Out (⌘-)")
                
                // Fit Page
                Button {
                    NotificationCenter.default.post(name: .readerResetZoom, object: nil)
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.85))
                }
                .help("Fit to Page (⌘0)")
                
                // Zoom In
                Button {
                    NotificationCenter.default.post(name: .readerZoomIn, object: nil)
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.85))
                }
                .help("Zoom In (⌘+)")
            }
            
            Divider()
                .frame(height: 18)
                .background(Color.white.opacity(0.2))
            
            // Shortcuts Help Button
            Button {
                isShortcutsPresented = true
            } label: {
                Image(systemName: "keyboard")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.75))
            }
            .help("Keyboard Shortcuts (?)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.08, green: 0.11, blue: 0.16).opacity(0.94))
                .shadow(color: Color.black.opacity(0.35), radius: 8, x: 0, y: 3)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        .onChange(of: currentPageIndex) { _, newIndex in
            if !isScrubbing {
                scrubbedPageIndex = Double(newIndex)
            }
        }
        .sheet(isPresented: $isShortcutsPresented) {
            KeyboardShortcutsSheet()
        }
    }
    
    private func performJump() {
        if let targetNum = Int(jumpTargetPageString.trimmingCharacters(in: .whitespacesAndNewlines)) {
            let zeroBased = max(0, min(targetNum - 1, totalPages - 1))
            currentPageIndex = zeroBased
            NotificationCenter.default.post(
                name: .readerJumpToPage,
                object: nil,
                userInfo: ["pageIndex": zeroBased]
            )
        }
        isJumpPopoverPresented = false
    }
}
