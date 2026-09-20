//
//  ZipArchive.swift
//  Vachanam
//
//  Lightweight, dependency-free ZIP/EPUB archive reader using Apple's built-in zlib.
//

import Foundation
import zlib

public struct ZipEntry: Sendable {
    public let name: String
    public let compressionMethod: UInt16
    public let compressedSize: Int
    public let uncompressedSize: Int
    public let offset: Int
}

public class ZipArchive: @unchecked Sendable {
    // MARK: - Security Limits
    public static let maxEntryDecompressedBytes: Int = 100 * 1024 * 1024 // 100 MB per entry
    public static let maxTotalDecompressedBytes: Int = 500 * 1024 * 1024 // 500 MB total per archive
    public static let maxCompressionRatio: Double = 1000.0 // Zip bomb threshold
    
    private let data: Data
    public private(set) var entries: [String: ZipEntry] = [:]
    private var lookupMap: [String: ZipEntry] = [:]
    public private(set) var totalDecompressedBytes: Int = 0
    
    public init?(data: Data) {
        self.data = data
        guard parseCentralDirectory() || parseLocalHeaders() else {
            return nil
        }
    }
    
    public convenience init?(url: URL) {
        guard let data = try? Data(contentsOf: url) else { return nil }
        self.init(data: data)
    }
    
    // MARK: - Path Normalization
    
    public func normalizeEntryPath(_ path: String) -> String {
        var clean = path.replacingOccurrences(of: "\0", with: "").replacingOccurrences(of: "\\", with: "/")
        clean = clean.removingPercentEncoding ?? clean
        while clean.hasPrefix("./") {
            clean = String(clean.dropFirst(2))
        }
        while clean.hasPrefix("/") {
            clean = String(clean.dropFirst(1))
        }
        let components = clean.split(separator: "/")
        var resolved: [Substring] = []
        for c in components {
            if c == "." { continue }
            if c == ".." {
                if !resolved.isEmpty {
                    resolved.removeLast()
                }
            } else {
                resolved.append(c)
            }
        }
        return resolved.joined(separator: "/")
    }
    
    // MARK: - Central Directory Parsing
    
    private func registerEntry(_ entry: ZipEntry, cleanName: String, rawName: String) {
        entries[cleanName] = entry
        lookupMap[cleanName] = entry
        lookupMap[cleanName.lowercased()] = entry
        if cleanName != rawName {
            entries[rawName] = entry
            lookupMap[rawName] = entry
            lookupMap[rawName.lowercased()] = entry
        }
    }
    
    private func parseCentralDirectory() -> Bool {
        let count = data.count
        guard count >= 22 else { return false }
        
        // Find End of Central Directory Record (signature 0x06054b50)
        var eocdOffset = -1
        let searchMin = max(0, count - 65557) // Max comment length 65535 + 22
        
        data.withUnsafeBytes { raw in
            let bytes = raw.bindMemory(to: UInt8.self)
            for i in stride(from: count - 22, through: searchMin, by: -1) {
                if bytes[i] == 0x50 && bytes[i + 1] == 0x4b && bytes[i + 2] == 0x05 && bytes[i + 3] == 0x06 {
                    eocdOffset = i
                    break
                }
            }
        }
        
        guard eocdOffset >= 0 else { return false }
        
        let cdOffset = Int(readUInt32(at: eocdOffset + 16))
        let cdTotalEntries = Int(readUInt16(at: eocdOffset + 10))
        
        var currentOffset = cdOffset
        for _ in 0..<cdTotalEntries {
            guard currentOffset + 46 <= count else { break }
            let sig = readUInt32(at: currentOffset)
            guard sig == 0x02014b50 else { break } // Central directory signature
            
            let method = readUInt16(at: currentOffset + 10)
            let compSize = Int(readUInt32(at: currentOffset + 20))
            let uncompSize = Int(readUInt32(at: currentOffset + 24))
            let nameLen = Int(readUInt16(at: currentOffset + 28))
            let extraLen = Int(readUInt16(at: currentOffset + 30))
            let commentLen = Int(readUInt16(at: currentOffset + 32))
            let localHeaderOffset = Int(readUInt32(at: currentOffset + 42))
            
            let nameStart = currentOffset + 46
            guard nameStart + nameLen <= count else { break }
            let nameData = data.subdata(in: nameStart..<(nameStart + nameLen))
            let rawName = String(data: nameData, encoding: .utf8) ?? String(data: nameData, encoding: .ascii) ?? ""
            let cleanName = normalizeEntryPath(rawName)
            
            if !cleanName.isEmpty && !cleanName.hasSuffix("/") {
                let entry = ZipEntry(
                    name: cleanName,
                    compressionMethod: method,
                    compressedSize: compSize,
                    uncompressedSize: uncompSize,
                    offset: localHeaderOffset
                )
                registerEntry(entry, cleanName: cleanName, rawName: rawName)
            }
            
            currentOffset += 46 + nameLen + extraLen + commentLen
        }
        
        return !entries.isEmpty
    }
    
    // Fallback: Scan local headers directly
    private func parseLocalHeaders() -> Bool {
        var currentOffset = 0
        let count = data.count
        
        while currentOffset + 30 <= count {
            let sig = readUInt32(at: currentOffset)
            guard sig == 0x04034b50 else { break }
            
            let method = readUInt16(at: currentOffset + 8)
            let compSize = Int(readUInt32(at: currentOffset + 18))
            let uncompSize = Int(readUInt32(at: currentOffset + 22))
            let nameLen = Int(readUInt16(at: currentOffset + 26))
            let extraLen = Int(readUInt16(at: currentOffset + 28))
            
            let nameStart = currentOffset + 30
            guard nameStart + nameLen <= count else { break }
            let nameData = data.subdata(in: nameStart..<(nameStart + nameLen))
            let rawName = String(data: nameData, encoding: .utf8) ?? String(data: nameData, encoding: .ascii) ?? ""
            let cleanName = normalizeEntryPath(rawName)
            
            let dataStart = nameStart + nameLen + extraLen
            if !cleanName.isEmpty && !cleanName.hasSuffix("/") && compSize > 0 {
                let entry = ZipEntry(
                    name: cleanName,
                    compressionMethod: method,
                    compressedSize: compSize,
                    uncompressedSize: uncompSize,
                    offset: currentOffset
                )
                registerEntry(entry, cleanName: cleanName, rawName: rawName)
            }
            
            currentOffset = dataStart + compSize
        }
        
        return !entries.isEmpty
    }
    
    // MARK: - Entry Data Extraction
    
    public func data(for entryName: String) -> Data? {
        let normalized = normalizeEntryPath(entryName)
        guard let entry = lookupMap[normalized]
                ?? lookupMap[entryName]
                ?? lookupMap[normalized.lowercased()]
                ?? lookupMap[entryName.lowercased()] else {
            return nil
        }
        
        // Security checks: Single entry cap, total expansion cap, and zip-bomb ratio cap
        guard entry.uncompressedSize <= Self.maxEntryDecompressedBytes else {
            return nil
        }
        guard totalDecompressedBytes + entry.uncompressedSize <= Self.maxTotalDecompressedBytes else {
            return nil
        }
        if entry.compressedSize > 1024 && Double(entry.uncompressedSize) / Double(entry.compressedSize) > Self.maxCompressionRatio {
            return nil
        }
        
        let localOffset = entry.offset
        guard localOffset + 30 <= data.count else { return nil }
        guard readUInt32(at: localOffset) == 0x04034b50 else { return nil }
        
        let localNameLen = Int(readUInt16(at: localOffset + 26))
        let localExtraLen = Int(readUInt16(at: localOffset + 28))
        let dataStart = localOffset + 30 + localNameLen + localExtraLen
        let dataEnd = dataStart + entry.compressedSize
        
        guard dataEnd <= data.count else { return nil }
        let compressedData = data.subdata(in: dataStart..<dataEnd)
        
        var resultData: Data?
        if entry.compressionMethod == 0 {
            // Stored (no compression)
            resultData = compressedData
        } else if entry.compressionMethod == 8 {
            // Deflate
            resultData = inflateRaw(data: compressedData, uncompressedSize: entry.uncompressedSize)
        }
        
        if let result = resultData {
            totalDecompressedBytes += result.count
        }
        return resultData
    }
    
    public func string(for entryName: String) -> String? {
        guard let entryData = data(for: entryName) else { return nil }
        if let utf8 = String(data: entryData, encoding: .utf8) {
            return utf8
        }
        if let latin1 = String(data: entryData, encoding: .isoLatin1) {
            return latin1
        }
        if let win1252 = String(data: entryData, encoding: .windowsCP1252) {
            return win1252
        }
        return String(data: entryData, encoding: .ascii)
    }
    
    // MARK: - Raw Deflate Decompression
    
    private func inflateRaw(data: Data, uncompressedSize: Int) -> Data? {
        guard uncompressedSize <= Self.maxEntryDecompressedBytes else { return nil }
        
        var stream = z_stream()
        let initStatus = inflateInit2_(&stream, -MAX_WBITS, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
        guard initStatus == Z_OK else { return nil }
        defer { inflateEnd(&stream) }
        
        // Fast path: Exact destination size known (standard for ZIP archives)
        if uncompressedSize > 0 {
            var decompressed = Data(count: uncompressedSize)
            let success = decompressed.withUnsafeMutableBytes { dstRaw -> Bool in
                guard let dstBase = dstRaw.bindMemory(to: Bytef.self).baseAddress else { return false }
                return data.withUnsafeBytes { srcRaw -> Bool in
                    guard let srcBase = srcRaw.bindMemory(to: Bytef.self).baseAddress else { return false }
                    stream.next_in = UnsafeMutablePointer<Bytef>(mutating: srcBase)
                    stream.avail_in = uInt(data.count)
                    stream.next_out = dstBase
                    stream.avail_out = uInt(uncompressedSize)
                    
                    let status = inflate(&stream, Z_FINISH)
                    return status == Z_STREAM_END || status == Z_OK
                }
            }
            if success && stream.total_out == uLong(uncompressedSize) {
                return decompressed
            }
            // If fast path didn't complete (e.g. uncompressedSize mismatch), re-init and use streaming loop
            inflateReset(&stream)
        }
        
        let chunkSize = 65536
        var decompressed = Data()
        if uncompressedSize > 0 {
            decompressed.reserveCapacity(min(uncompressedSize, Self.maxEntryDecompressedBytes))
        }
        
        return data.withUnsafeBytes { rawIn -> Data? in
            guard let inBase = rawIn.bindMemory(to: Bytef.self).baseAddress else { return nil }
            stream.next_in = UnsafeMutablePointer<Bytef>(mutating: inBase)
            stream.avail_in = uInt(data.count)
            
            var buffer = [UInt8](repeating: 0, count: chunkSize)
            
            while true {
                let status: Int32 = buffer.withUnsafeMutableBytes { rawOut in
                    guard let outBase = rawOut.bindMemory(to: Bytef.self).baseAddress else { return Z_MEM_ERROR }
                    stream.next_out = outBase
                    stream.avail_out = uInt(chunkSize)
                    return inflate(&stream, Z_NO_FLUSH)
                }
                
                let produced = chunkSize - Int(stream.avail_out)
                if produced > 0 {
                    if decompressed.count + produced > Self.maxEntryDecompressedBytes {
                        return nil
                    }
                    decompressed.append(buffer, count: produced)
                }
                
                if status == Z_STREAM_END {
                    return decompressed
                }
                
                if status != Z_OK {
                    if stream.avail_in == 0 && produced == 0 {
                        return decompressed.isEmpty ? nil : decompressed
                    }
                    return nil
                }
            }
        }
    }
    
    // MARK: - Binary Read Helpers
    
    private func readUInt16(at offset: Int) -> UInt16 {
        guard offset + 2 <= data.count else { return 0 }
        let b0 = UInt16(data[offset])
        let b1 = UInt16(data[offset + 1])
        return b0 | (b1 << 8)
    }
    
    private func readUInt32(at offset: Int) -> UInt32 {
        guard offset + 4 <= data.count else { return 0 }
        let b0 = UInt32(data[offset])
        let b1 = UInt32(data[offset + 1])
        let b2 = UInt32(data[offset + 2])
        let b3 = UInt32(data[offset + 3])
        return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
    }
}
