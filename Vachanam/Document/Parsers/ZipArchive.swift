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
    private let data: Data
    public private(set) var entries: [String: ZipEntry] = [:]
    
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
    
    // MARK: - Central Directory Parsing
    
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
            let name = String(data: nameData, encoding: .utf8) ?? String(data: nameData, encoding: .ascii) ?? ""
            
            if !name.isEmpty && !name.hasSuffix("/") {
                let entry = ZipEntry(
                    name: name,
                    compressionMethod: method,
                    compressedSize: compSize,
                    uncompressedSize: uncompSize,
                    offset: localHeaderOffset
                )
                entries[name] = entry
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
            let name = String(data: nameData, encoding: .utf8) ?? String(data: nameData, encoding: .ascii) ?? ""
            
            let dataStart = nameStart + nameLen + extraLen
            if !name.isEmpty && !name.hasSuffix("/") && compSize > 0 {
                let entry = ZipEntry(
                    name: name,
                    compressionMethod: method,
                    compressedSize: compSize,
                    uncompressedSize: uncompSize,
                    offset: currentOffset
                )
                entries[name] = entry
            }
            
            currentOffset = dataStart + compSize
        }
        
        return !entries.isEmpty
    }
    
    // MARK: - Entry Data Extraction
    
    public func data(for entryName: String) -> Data? {
        guard let entry = entries[entryName] ?? entries.first(where: { $0.key.lowercased() == entryName.lowercased() })?.value else {
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
        
        if entry.compressionMethod == 0 {
            // Stored (no compression)
            return compressedData
        } else if entry.compressionMethod == 8 {
            // Deflate
            return inflateRaw(data: compressedData, uncompressedSize: entry.uncompressedSize)
        }
        
        return nil
    }
    
    public func string(for entryName: String) -> String? {
        guard let entryData = data(for: entryName) else { return nil }
        return String(data: entryData, encoding: .utf8) ?? String(data: entryData, encoding: .ascii)
    }
    
    // MARK: - Raw Deflate Decompression
    
    private func inflateRaw(data: Data, uncompressedSize: Int) -> Data? {
        var stream = z_stream()
        // -MAX_WBITS signifies raw deflate stream (no zlib or gzip header)
        let initStatus = inflateInit2_(&stream, -MAX_WBITS, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
        guard initStatus == Z_OK else { return nil }
        defer { inflateEnd(&stream) }
        
        let outputCapacity = max(uncompressedSize, 1024)
        var outputData = Data(count: outputCapacity)
        
        let status: Int32 = data.withUnsafeBytes { rawIn in
            outputData.withUnsafeMutableBytes { rawOut in
                guard let inPtr = rawIn.bindMemory(to: Bytef.self).baseAddress,
                      let outPtr = rawOut.bindMemory(to: Bytef.self).baseAddress else {
                    return Z_DATA_ERROR
                }
                stream.next_in = UnsafeMutablePointer<Bytef>(mutating: inPtr)
                stream.avail_in = uInt(data.count)
                stream.next_out = outPtr
                stream.avail_out = uInt(outputCapacity)
                
                return inflate(&stream, Z_FINISH)
            }
        }
        
        if status == Z_STREAM_END || status == Z_OK {
            let actualCount = Int(stream.total_out)
            return outputData.prefix(actualCount)
        }
        
        return nil
    }
    
    // MARK: - Binary Read Helpers
    
    private func readUInt16(at offset: Int) -> UInt16 {
        data.withUnsafeBytes { raw in
            raw.load(fromByteOffset: offset, as: UInt16.self).littleEndian
        }
    }
    
    private func readUInt32(at offset: Int) -> UInt32 {
        data.withUnsafeBytes { raw in
            raw.load(fromByteOffset: offset, as: UInt32.self).littleEndian
        }
    }
}
