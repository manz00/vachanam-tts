//
//  ImageContentExtractor.swift
//  Vachanam
//
//  Foundation for extracting text annotations, equations, and labels embedded within
//  figures and raster diagrams using Apple's Vision framework.
//

import Foundation
import CoreGraphics
import Vision
#if canImport(PDFKit)
import PDFKit
#endif

public struct ImageContentExtractor: Sendable {
    public static let shared = ImageContentExtractor()
    
    public init() {}
    
    /// Asynchronously performs OCR on an image (e.g. cropped figure or rasterized PDF page)
    /// to recognize embedded labels, diagram texts, and annotations.
    public func recognizeText(in cgImage: CGImage) async -> [String] {
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { req, error in
                guard error == nil, let observations = req.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                let recognized = observations.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: recognized)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: [])
            }
        }
    }
    
    #if canImport(PDFKit)
    /// Renders a PDF page area into a CGImage and extracts visual text via OCR.
    public func recognizeText(on page: PDFPage, in rect: CGRect, scale: CGFloat = 2.0) async -> [String] {
        let size = CGSize(width: rect.width * scale, height: rect.height * scale)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return []
        }
        
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(origin: .zero, size: size))
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -rect.origin.x, y: -rect.origin.y)
        
        page.draw(with: .cropBox, to: context)
        
        guard let cgImage = context.makeImage() else { return [] }
        return await recognizeText(in: cgImage)
    }
    #endif
}
