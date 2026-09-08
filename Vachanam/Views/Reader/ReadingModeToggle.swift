//
//  ReadingModeToggle.swift
//  Vachanam
//
//  Switch between Original PDF layout and Re-rendered Accessibility Reader View.
//

import SwiftUI

public enum ReadingMode: String, CaseIterable, Identifiable {
    case pdfLayout = "Original PDF"
    case readerView = "Reader View"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .pdfLayout: return "doc.text"
        case .readerView: return "text.viewfinder"
        }
    }
}

public struct ReadingModeToggle: View {
    @Binding public var selectedMode: ReadingMode
    
    public init(selectedMode: Binding<ReadingMode>) {
        self._selectedMode = selectedMode
    }
    
    public var body: some View {
        HStack(spacing: 4) {
            ForEach(ReadingMode.allCases) { mode in
                Button {
                    withAnimation(.spring(response: 0.25)) {
                        selectedMode = mode
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: mode.iconName)
                            .font(.system(size: 13, weight: .semibold))
                        Text(mode.rawValue)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(selectedMode == mode ? Color.amberAccent : Color.clear)
                    .foregroundColor(selectedMode == mode ? Color.black : Color.white.opacity(0.8))
                    .cornerRadius(16)
                }
            }
        }
        .padding(3)
        .background(Color(red: 0.12, green: 0.16, blue: 0.23))
        .cornerRadius(20)
    }
}
