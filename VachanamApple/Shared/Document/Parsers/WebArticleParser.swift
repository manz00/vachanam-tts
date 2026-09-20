//
//  WebArticleParser.swift
//  Vachanam
//
//  Fetches web pages and extracts reader-friendly article content into ParsedDocument models.
//

import Foundation

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

// MARK: - URL Security Validator

public struct URLSecurityValidator: Sendable {
    public static let maxResponseSizeBytes: Int = 5 * 1024 * 1024 // 5 MB
    public static let maxRedirects: Int = 3
    
    public enum ValidationError: LocalizedError, Equatable, Sendable {
        case invalidScheme(String)
        case missingHost
        case privateOrReservedAddress(String)
        case redirectLimitExceeded
        case insecureDowngrade
        case responseSizeExceeded(Int)
        case resolutionFailed(String)
        
        public var errorDescription: String? {
            switch self {
            case .invalidScheme(let s):
                return "Insecure scheme '\(s)'. Only HTTPS is permitted."
            case .missingHost:
                return "URL is missing a valid host."
            case .privateOrReservedAddress(let ip):
                return "Requests to private, loopback, or cloud metadata address '\(ip)' are prohibited."
            case .redirectLimitExceeded:
                return "Exceeded maximum redirect limit (\(URLSecurityValidator.maxRedirects))."
            case .insecureDowngrade:
                return "Redirect downgraded from HTTPS to insecure scheme."
            case .responseSizeExceeded(let maxBytes):
                return "Response size exceeded maximum allowed limit of \(maxBytes / (1024 * 1024)) MB."
            case .resolutionFailed(let host):
                return "Failed to resolve host '\(host)'."
            }
        }
    }
    
    public static func validate(url: URL) throws {
        guard let scheme = url.scheme?.lowercased() else {
            throw ValidationError.invalidScheme("none")
        }
        guard scheme == "https" else {
            throw ValidationError.invalidScheme(scheme)
        }
        guard let host = url.host, !host.isEmpty else {
            throw ValidationError.missingHost
        }
        
        let lowerHost = host.lowercased()
        if lowerHost == "localhost" || lowerHost.hasSuffix(".localhost") || lowerHost == "127.0.0.1" || lowerHost == "::1" {
            throw ValidationError.privateOrReservedAddress(host)
        }
        
        try validateHostResolution(host: host)
    }
    
    private static func validateHostResolution(host: String) throws {
        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        hints.ai_socktype = SOCK_STREAM
        
        var res: UnsafeMutablePointer<addrinfo>?
        let status = getaddrinfo(host, nil, &hints, &res)
        guard status == 0, let first = res else {
            throw ValidationError.resolutionFailed(host)
        }
        defer { freeaddrinfo(res) }
        
        var ptr: UnsafeMutablePointer<addrinfo>? = first
        while let current = ptr {
            if let addr = current.pointee.ai_addr {
                if addr.pointee.sa_family == sa_family_t(AF_INET) {
                    let sockAddrIn = addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
                    let ip = sockAddrIn.sin_addr.s_addr.bigEndian
                    if isPrivateOrReservedIPv4(ip) {
                        var ipBuf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                        var sinAddr = sockAddrIn.sin_addr
                        inet_ntop(AF_INET, &sinAddr, &ipBuf, socklen_t(INET_ADDRSTRLEN))
                        let ipString = String(cString: ipBuf)
                        throw ValidationError.privateOrReservedAddress(ipString)
                    }
                } else if addr.pointee.sa_family == sa_family_t(AF_INET6) {
                    let sockAddrIn6 = addr.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { $0.pointee }
                    let bytes = sockAddrIn6.sin6_addr.__u6_addr.__u6_addr8
                    if isPrivateOrReservedIPv6(bytes) {
                        var ipBuf = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
                        var sin6Addr = sockAddrIn6.sin6_addr
                        inet_ntop(AF_INET6, &sin6Addr, &ipBuf, socklen_t(INET6_ADDRSTRLEN))
                        let ipString = String(cString: ipBuf)
                        throw ValidationError.privateOrReservedAddress(ipString)
                    }
                }
            }
            ptr = current.pointee.ai_next
        }
    }
    
    public static func isPrivateOrReservedIPv4(_ ip: UInt32) -> Bool {
        let b0 = UInt8((ip >> 24) & 0xFF)
        let b1 = UInt8((ip >> 16) & 0xFF)
        
        if b0 == 0 { return true }
        if b0 == 127 { return true }
        if b0 == 10 { return true }
        if b0 == 172 && (b1 >= 16 && b1 <= 31) { return true }
        if b0 == 192 && b1 == 168 { return true }
        if b0 == 169 && b1 == 254 { return true }
        if b0 == 100 && (b1 >= 64 && b1 <= 127) { return true }
        if b0 == 192 && b1 == 0 { return true }
        if b0 == 198 && (b1 == 18 || b1 == 19) { return true }
        if b0 >= 224 { return true }
        return false
    }
    
    public static func isPrivateOrReservedIPv6(_ b: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)) -> Bool {
        if b.0 == 0 && b.1 == 0 && b.2 == 0 && b.3 == 0 && b.4 == 0 && b.5 == 0 && b.6 == 0 && b.7 == 0 &&
           b.8 == 0 && b.9 == 0 && b.10 == 0 && b.11 == 0 && b.12 == 0 && b.13 == 0 && b.14 == 0 && b.15 == 1 {
            return true
        }
        if b.0 == 0 && b.1 == 0 && b.2 == 0 && b.3 == 0 && b.4 == 0 && b.5 == 0 && b.6 == 0 && b.7 == 0 &&
           b.8 == 0 && b.9 == 0 && b.10 == 0 && b.11 == 0 && b.12 == 0 && b.13 == 0 && b.14 == 0 && b.15 == 0 {
            return true
        }
        if b.0 == 0 && b.1 == 0 && b.2 == 0 && b.3 == 0 && b.4 == 0 && b.5 == 0 && b.6 == 0 && b.7 == 0 &&
           b.8 == 0 && b.9 == 0 && b.10 == 0xFF && b.11 == 0xFF {
            let ip4 = (UInt32(b.12) << 24) | (UInt32(b.13) << 16) | (UInt32(b.14) << 8) | UInt32(b.15)
            return isPrivateOrReservedIPv4(ip4)
        }
        if b.0 == 0xFE && (b.1 & 0xC0) == 0x80 {
            return true
        }
        if (b.0 & 0xFE) == 0xFC {
            return true
        }
        if b.0 == 0xFF {
            return true
        }
        return false
    }
}

// MARK: - Secure Fetch Delegate

private final class SecureWebFetchDelegate: NSObject, URLSessionTaskDelegate, URLSessionDataDelegate {
    private var redirectCount = 0
    var accumulatedData = Data()
    var securityError: Error?
    
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        redirectCount += 1
        if redirectCount > URLSecurityValidator.maxRedirects {
            securityError = URLSecurityValidator.ValidationError.redirectLimitExceeded
            completionHandler(nil)
            return
        }
        guard let targetURL = request.url else {
            completionHandler(nil)
            return
        }
        do {
            try URLSecurityValidator.validate(url: targetURL)
            completionHandler(request)
        } catch {
            securityError = error
            completionHandler(nil)
        }
    }
    
    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        if response.expectedContentLength > Int64(URLSecurityValidator.maxResponseSizeBytes) {
            securityError = URLSecurityValidator.ValidationError.responseSizeExceeded(URLSecurityValidator.maxResponseSizeBytes)
            completionHandler(.cancel)
            return
        }
        completionHandler(.allow)
    }
    
    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive data: Data
    ) {
        if accumulatedData.count + data.count > URLSecurityValidator.maxResponseSizeBytes {
            securityError = URLSecurityValidator.ValidationError.responseSizeExceeded(URLSecurityValidator.maxResponseSizeBytes)
            dataTask.cancel()
            return
        }
        accumulatedData.append(data)
    }
}

public struct WebArticleParser: DocumentParser {
    public init() {}
    
    public func parse(from source: DocumentSource) async throws -> ParsedDocument {
        let html: String
        let defaultTitle: String
        
        switch source {
        case .webURL(let url):
            let fetchResult = try await Self.secureFetchHTML(url: url)
            html = fetchResult.html
            defaultTitle = fetchResult.responseURL.host ?? url.host ?? "Web Article"
            
        case .rawText(let rawHTML, let rawTitle):
            html = rawHTML
            defaultTitle = rawTitle
            
        case .fileURL(let url):
            guard let data = try? Data(contentsOf: url) else {
                throw DocumentParserError.fileNotFound(url)
            }
            html = PlainTextParser.decodeString(from: data)
            defaultTitle = url.deletingPathExtension().lastPathComponent
        }
        
        return parseHTMLArticle(html, defaultTitle: defaultTitle)
    }
    
    public static func secureFetchHTML(url: URL) async throws -> (html: String, responseURL: URL) {
        try URLSecurityValidator.validate(url: url)
        
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15.0
        config.timeoutIntervalForResource = 30.0
        
        let delegate = SecureWebFetchDelegate()
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        
        return try await withCheckedThrowingContinuation { continuation in
            let task = session.dataTask(with: request) { _, response, taskError in
                if let secErr = delegate.securityError {
                    continuation.resume(throwing: secErr)
                    return
                }
                if let taskError = taskError {
                    continuation.resume(throwing: DocumentParserError.networkError(taskError.localizedDescription))
                    return
                }
                guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                    continuation.resume(throwing: DocumentParserError.networkError("Invalid HTTP response"))
                    return
                }
                let data = delegate.accumulatedData
                let finalURL = response?.url ?? url
                let decoded = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) ?? ""
                continuation.resume(returning: (decoded, finalURL))
            }
            task.resume()
        }
    }
    
    public func parseHTMLArticle(_ html: String, defaultTitle: String) -> ParsedDocument {
        // 1. Extract metadata
        let extractedTitle = extractTagContent(from: html, tag: "title")
        let cleanTitle: String = {
            if let t = extractedTitle, !t.isEmpty {
                // Often titles are "Article Name | Site Name", strip site name
                return t.components(separatedBy: " | ").first ?? t.components(separatedBy: " - ").first ?? t
            }
            return defaultTitle
        }()
        
        let author = extractMetaContent(from: html, name: "author")
            ?? extractMetaContent(from: html, property: "article:author")
        
        // 2. Remove scripts, styles, navigation, headers, footers
        var sanitized = html
        let tagsToRemove = ["script", "style", "nav", "header", "footer", "aside", "svg", "noscript", "iframe"]
        for tag in tagsToRemove {
            let pattern = "(?is)<" + tag + ".*?</" + tag + ">"
            sanitized = sanitized.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        
        // 3. Extract article or main content if available
        let mainContent: String = {
            if let articleMatch = extractTagHTML(from: sanitized, tag: "article") {
                return articleMatch
            }
            if let mainMatch = extractTagHTML(from: sanitized, tag: "main") {
                return mainMatch
            }
            return sanitized
        }()
        
        // 4. Extract blocks
        let epubParser = EPUBParser()
        let blocks = epubParser.parseHTMLBlocks(from: mainContent)
        
        let chapter = ParsedChapter(title: cleanTitle, blocks: blocks.isEmpty ? [
            ParsedBlock(type: .paragraph, text: cleanHTMLText(sanitized))
        ] : blocks)
        
        return ParsedDocument(
            title: cleanTitle,
            author: author,
            format: .webArticle,
            chapters: [chapter]
        )
    }
    
    // MARK: - Helpers
    
    private func extractTagContent(from html: String, tag: String) -> String? {
        let pattern = "<" + tag + "[^>]*>(.*?)</" + tag + ">"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return nil
        }
        let ns = html as NSString
        if let match = regex.firstMatch(in: html, range: NSRange(location: 0, length: ns.length)), match.numberOfRanges >= 2 {
            return cleanHTMLText(ns.substring(with: match.range(at: 1)))
        }
        return nil
    }
    
    private func extractTagHTML(from html: String, tag: String) -> String? {
        let pattern = "(?is)<" + tag + "[^>]*>.*?</" + tag + ">"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let ns = html as NSString
        if let match = regex.firstMatch(in: html, range: NSRange(location: 0, length: ns.length)) {
            return ns.substring(with: match.range)
        }
        return nil
    }
    
    private func extractMetaContent(from html: String, name: String? = nil, property: String? = nil) -> String? {
        let attr = name != nil ? "name=['\"]\(name!)['\"]" : "property=['\"]\(property!)['\"]"
        let pattern = "<meta\\s+[^>]*" + attr + "[^>]*content=['\"]([^'\"]+)['\"][^>]*>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let ns = html as NSString
        if let match = regex.firstMatch(in: html, range: NSRange(location: 0, length: ns.length)), match.numberOfRanges >= 2 {
            return cleanHTMLText(ns.substring(with: match.range(at: 1)))
        }
        return nil
    }
    
    private func cleanHTMLText(_ html: String) -> String {
        return EPUBParser().cleanHTMLText(html)
    }
}
