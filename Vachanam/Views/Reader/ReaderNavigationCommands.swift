//
//  ReaderNavigationCommands.swift
//  Vachanam
//
//  Notification names and helper extensions for PDF reader navigation, scrolling, and zoom commands.
//

import Foundation

extension Notification.Name {
    public static let readerGoToNextPage = Notification.Name("readerGoToNextPage")
    public static let readerGoToPreviousPage = Notification.Name("readerGoToPreviousPage")
    public static let readerGoToFirstPage = Notification.Name("readerGoToFirstPage")
    public static let readerGoToLastPage = Notification.Name("readerGoToLastPage")
    public static let readerScrollDown = Notification.Name("readerScrollDown")
    public static let readerScrollUp = Notification.Name("readerScrollUp")
    public static let readerPageDown = Notification.Name("readerPageDown")
    public static let readerPageUp = Notification.Name("readerPageUp")
    public static let readerZoomIn = Notification.Name("readerZoomIn")
    public static let readerZoomOut = Notification.Name("readerZoomOut")
    public static let readerResetZoom = Notification.Name("readerResetZoom")
    public static let readerJumpToPage = Notification.Name("readerJumpToPage")
}
