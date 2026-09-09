//
//  PDFLoggingSanitizer.swift
//  Vachanam
//
//  High-performance stdio filter and suppressor for Apple CoreGraphics, CoreText,
//  and PDFKit font-mapping, page analysis, and subsampling diagnostics
//  (.notdef: no mapping, CGPDFImage, CTLD, "New text range needs to be within the original node's text range").
//

import Foundation
import Darwin

public final class PDFLoggingSanitizer: @unchecked Sendable {
    public static let shared = PDFLoggingSanitizer()
    
    private let lock = NSLock()
    private var isInstalled = false
    private var stderrInterceptor: StreamInterceptor?
    private var stdoutInterceptor: StreamInterceptor?
    private let queue = DispatchQueue(label: "com.vachanam.pdfloggingsanitizer", qos: .utility)
    
    private init() {}
    
    deinit {
        uninstall()
    }
    
    /// Determines whether a given console line is benign CoreGraphics/CoreText/PDFKit engine noise.
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
        
        // 4. PDFKit PageLayout / PDFPageAnalyzer text range warnings
        if trimmed.contains("New text range needs to be within the original node's text range") {
            return true
        }
        
        return false
    }
    
    /// Installs a continuous background filter on `STDERR_FILENO` and `STDOUT_FILENO`.
    /// Benign CoreGraphics/CoreText/PDFKit diagnostics are silently dropped, while all genuine
    /// logs, profiler timings, assertions, and crash reports continue flowing to the original output.
    public func install() {
        lock.lock()
        defer { lock.unlock() }
        
        // Remove any inherited CG_PDF_VERBOSE from environment to prevent PDFPageAnalyzer verbose warnings
        unsetenv("CG_PDF_VERBOSE")
        
        guard !isInstalled else { return }
        
        fflush(stderr)
        fflush(stdout)
        
        let errInterceptor = StreamInterceptor(targetFd: STDERR_FILENO, queue: queue)
        _ = errInterceptor.start()
        self.stderrInterceptor = errInterceptor
        
        let outInterceptor = StreamInterceptor(targetFd: STDOUT_FILENO, queue: queue)
        _ = outInterceptor.start()
        self.stdoutInterceptor = outInterceptor
        
        self.isInstalled = true
    }
    
    /// Uninstalls the background filter and restores original stdio descriptors.
    public func uninstall() {
        lock.lock()
        defer { lock.unlock() }
        
        guard isInstalled else { return }
        
        fflush(stderr)
        fflush(stdout)
        
        stderrInterceptor?.stop()
        stderrInterceptor = nil
        
        stdoutInterceptor?.stop()
        stdoutInterceptor = nil
        
        self.isInstalled = false
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

// MARK: - Private POSIX Stream Interceptor

private final class StreamInterceptor: @unchecked Sendable {
    let targetFd: Int32
    private(set) var originalFd: Int32 = -1
    private(set) var readPipeFd: Int32 = -1
    private var readSource: DispatchSourceRead?
    private var lineBuffer = Data()
    private let queue: DispatchQueue
    private let lock = NSLock()
    
    init(targetFd: Int32, queue: DispatchQueue) {
        self.targetFd = targetFd
        self.queue = queue
    }
    
    func start() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        let orig = dup(targetFd)
        guard orig >= 0 else { return false }
        _ = fcntl(orig, F_SETFD, FD_CLOEXEC)
        self.originalFd = orig
        
        var pipeFDs: [Int32] = [0, 0]
        guard pipe(&pipeFDs) == 0 else {
            close(orig)
            self.originalFd = -1
            return false
        }
        
        let readFd = pipeFDs[0]
        let writeFd = pipeFDs[1]
        self.readPipeFd = readFd
        
        let flags = fcntl(readFd, F_GETFL)
        _ = fcntl(readFd, F_SETFL, flags | O_NONBLOCK)
        _ = fcntl(readFd, F_SETFD, FD_CLOEXEC)
        _ = fcntl(writeFd, F_SETFD, FD_CLOEXEC)
        
        dup2(writeFd, targetFd)
        close(writeFd)
        
        let source = DispatchSource.makeReadSource(fileDescriptor: readFd, queue: queue)
        source.setEventHandler { [weak self] in
            self?.processBytes()
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
        return true
    }
    
    func stop() {
        lock.lock()
        defer { lock.unlock() }
        
        if let source = readSource {
            source.cancel()
            self.readSource = nil
        }
        if originalFd >= 0 {
            dup2(originalFd, targetFd)
            close(originalFd)
            self.originalFd = -1
        }
        lineBuffer.removeAll()
    }
    
    private func processBytes() {
        var buffer = [UInt8](repeating: 0, count: 4096)
        
        while true {
            let bytesRead = Darwin.read(readPipeFd, &buffer, buffer.count)
            if bytesRead <= 0 { break }
            lineBuffer.append(buffer, count: bytesRead)
        }
        
        while let newlineIndex = lineBuffer.firstIndex(of: UInt8(ascii: "\n")) {
            let lineData = lineBuffer.prefix(through: newlineIndex)
            lineBuffer.removeSubrange(..<lineBuffer.index(after: newlineIndex))
            
            if let lineStr = String(data: lineData, encoding: .utf8),
               PDFLoggingSanitizer.shouldSuppress(line: lineStr) {
                // Drop benign PDF engine log
                continue
            }
            
            if originalFd >= 0 {
                lineData.withUnsafeBytes { rawBuffer in
                    guard let ptr = rawBuffer.baseAddress else { return }
                    var written = 0
                    while written < rawBuffer.count {
                        let res = Darwin.write(originalFd, ptr + written, rawBuffer.count - written)
                        if res <= 0 { break }
                        written += res
                    }
                }
            }
        }
    }
}
