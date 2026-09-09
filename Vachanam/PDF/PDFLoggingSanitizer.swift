//
//  PDFLoggingSanitizer.swift
//  Vachanam
//
//  High-performance stderr filter and suppressor for Apple CoreGraphics, CoreText,
//  and PDFKit font-mapping and subsampling diagnostics (.notdef: no mapping, CGPDFImage, CTLD).
//

import Foundation
import Darwin

public final class PDFLoggingSanitizer: @unchecked Sendable {
    public static let shared = PDFLoggingSanitizer()
    
    private let lock = NSLock()
    private var isInstalled = false
    private var originalStderrFd: Int32 = -1
    private var readPipeFd: Int32 = -1
    private var readSource: DispatchSourceRead?
    private let queue = DispatchQueue(label: "com.vachanam.pdfloggingsanitizer", qos: .utility)
    private var lineBuffer = Data()
    
    private init() {}
    
    deinit {
        uninstall()
    }
    
    /// Determines whether a given console line is benign CoreGraphics/CoreText PDF engine noise.
    public static func shouldSuppress(line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        
        // 1. Font glyph unmapped warnings (e.g. .notdef: no mapping., mapsto: no mapping., parenleftbig: no mapping.)
        if trimmed.hasSuffix(": no mapping.") {
            return true
        }
        
        // 2. CoreGraphics PDF raster image subsample caching diagnostics
        if trimmed.hasPrefix("CGPDFImage(") || trimmed.contains("subsample_factor") {
            return true
        }
        
        // 3. CoreText line layout/display micro-benchmarks
        if trimmed.hasPrefix("CTLD took ") {
            return true
        }
        
        return false
    }
    
    /// Installs a continuous background filter on `STDERR_FILENO`.
    /// Benign CoreGraphics/CoreText PDF logs are silently dropped, while all genuine
    /// errors, assertions, crashes, and logs continue flowing to the original stderr.
    public func install() {
        lock.lock()
        defer { lock.unlock() }
        
        guard !isInstalled else { return }
        
        fflush(stderr)
        
        let origFd = dup(STDERR_FILENO)
        guard origFd >= 0 else { return }
        _ = fcntl(origFd, F_SETFD, FD_CLOEXEC)
        self.originalStderrFd = origFd
        
        var pipeFDs: [Int32] = [0, 0]
        guard pipe(&pipeFDs) == 0 else {
            close(origFd)
            self.originalStderrFd = -1
            return
        }
        
        let readFd = pipeFDs[0]
        let writeFd = pipeFDs[1]
        self.readPipeFd = readFd
        
        let flags = fcntl(readFd, F_GETFL)
        _ = fcntl(readFd, F_SETFL, flags | O_NONBLOCK)
        _ = fcntl(readFd, F_SETFD, FD_CLOEXEC)
        _ = fcntl(writeFd, F_SETFD, FD_CLOEXEC)
        
        // Redirect STDERR_FILENO (fd 2) to the pipe write end
        dup2(writeFd, STDERR_FILENO)
        close(writeFd)
        
        let source = DispatchSource.makeReadSource(fileDescriptor: readFd, queue: queue)
        source.setEventHandler { [weak self] in
            self?.processIncomingBytes()
        }
        
        source.setCancelHandler { [weak self] in
            guard let self = self else { return }
            self.lock.lock()
            if self.readPipeFd >= 0 {
                close(self.readPipeFd)
                self.readPipeFd = -1
            }
            self.lock.unlock()
        }
        
        self.readSource = source
        source.resume()
        self.isInstalled = true
    }
    
    /// Uninstalls the background filter and restores original stderr.
    public func uninstall() {
        lock.lock()
        defer { lock.unlock() }
        
        guard isInstalled else { return }
        
        fflush(stderr)
        
        if let source = readSource {
            source.cancel()
            self.readSource = nil
        }
        
        if originalStderrFd >= 0 {
            dup2(originalStderrFd, STDERR_FILENO)
            close(originalStderrFd)
            self.originalStderrFd = -1
        }
        
        self.isInstalled = false
        self.lineBuffer.removeAll()
    }
    
    private func processIncomingBytes() {
        var buffer = [UInt8](repeating: 0, count: 4096)
        
        while true {
            let bytesRead = Darwin.read(readPipeFd, &buffer, buffer.count)
            if bytesRead <= 0 {
                break
            }
            lineBuffer.append(buffer, count: bytesRead)
        }
        
        // Process complete newline-terminated lines
        while let newlineIndex = lineBuffer.firstIndex(of: UInt8(ascii: "\n")) {
            let lineData = lineBuffer.prefix(through: newlineIndex)
            lineBuffer.removeSubrange(..<lineBuffer.index(after: newlineIndex))
            
            if let lineStr = String(data: lineData, encoding: .utf8),
               Self.shouldSuppress(line: lineStr) {
                // Drop benign PDF engine log
                continue
            }
            
            // Forward legitimate stderr output to original stderr
            if originalStderrFd >= 0 {
                lineData.withUnsafeBytes { rawBuffer in
                    guard let ptr = rawBuffer.baseAddress else { return }
                    var written = 0
                    while written < rawBuffer.count {
                        let res = Darwin.write(originalStderrFd, ptr + written, rawBuffer.count - written)
                        if res <= 0 { break }
                        written += res
                    }
                }
            }
        }
    }
    
    /// Executes a closure with `STDERR_FILENO` temporarily redirected to `/dev/null`.
    /// Ideal for wrapping high-throughput batch operations like whole-document text extraction.
    @discardableResult
    public static func suppressingStderr<T>(_ body: () throws -> T) rethrows -> T {
        shared.lock.lock()
        defer { shared.lock.unlock() }
        
        fflush(stderr)
        let savedStderr = dup(STDERR_FILENO)
        guard savedStderr >= 0 else {
            return try body()
        }
        
        let devNull = open("/dev/null", O_WRONLY)
        if devNull >= 0 {
            dup2(devNull, STDERR_FILENO)
            close(devNull)
        }
        
        defer {
            fflush(stderr)
            dup2(savedStderr, STDERR_FILENO)
            close(savedStderr)
        }
        
        return try body()
    }
}
