import Vapor
import Foundation

struct ExtractRequest: Content, Codable {
    let data: String
    let encoding: String // "hex" or "base64"
    let delimiter: String // "SOH/ETX" etc
    let customStart: String? // optional custom hex like "0x01"
    let customEnd: String? // optional custom hex like "0x03"
}

struct DelimitersResponse: Content, Codable {
    let delimiters: [DelimiterPair]
}

struct FileUploadRequest: Content {
    var file: File
}

struct FileExtractRequest: Content {
    let delimiter: String?
    let customStart: String?
    let customEnd: String?
}

func extractionRoutes(_ app: Application) throws {
    // GET /api/health - Health check
    app.get("api", "health") { req -> String in
        "OK"
    }

    // GET /api/delimiters - List all delimiter pairs
    app.get("api", "delimiters") { req -> DelimitersResponse in
        return DelimitersResponse(delimiters: STANDARD_DELIMITERS)
    }

    // POST /api/extract - Extract from hex/base64 data
    app.post("api", "extract") { req -> LegacyExtractionResult in
        let extractRequest = try req.content.decode(ExtractRequest.self)

        // Decode data based on encoding type
        let data: Data
        if extractRequest.encoding == "hex" {
            guard let hexData = hexStringToData(extractRequest.data) else {
                throw Abort(.badRequest, reason: "Invalid hex encoding")
            }
            data = hexData
        } else if extractRequest.encoding == "base64" {
            guard let base64Data = Data(base64Encoded: extractRequest.data) else {
                throw Abort(.badRequest, reason: "Invalid base64 encoding")
            }
            data = base64Data
        } else {
            throw Abort(.badRequest, reason: "Invalid encoding type. Use 'hex' or 'base64'")
        }

        // Determine delimiters
        var startDelimiter: UInt8
        var endDelimiter: UInt8

        if let customStart = extractRequest.customStart, let customEnd = extractRequest.customEnd {
            guard let start = parseHexValue(customStart), let end = parseHexValue(customEnd) else {
                throw Abort(.badRequest, reason: "Invalid custom hex delimiters")
            }
            startDelimiter = start
            endDelimiter = end
        } else {
            guard let delimiter = getDelimiterByName(extractRequest.delimiter) else {
                throw Abort(.badRequest, reason: "Unknown delimiter")
            }
            startDelimiter = delimiter.startChar
            endDelimiter = delimiter.endChar
        }

        // Extract
        let result = SignalingFlexible.extract(data: data, startDelimiter: startDelimiter, endDelimiter: endDelimiter)
        return result
    }

    // POST /api/extract-file - Extract from uploaded file (raw bytes)
    app.on(.POST, "api", "extract-file") { req -> LegacyExtractionResult in
        // Read raw body bytes - for now, return a simple error message
        // This endpoint expects raw binary data
        let bodyData = Data()  // Empty for now - will be populated from request

        // Extract delimiter from query
        let delimiterName = (try? req.query.get(String.self, at: "delimiter")) ?? "SOH/ETX"
        let customStart = try? req.query.get(String.self, at: "customStart")
        let customEnd = try? req.query.get(String.self, at: "customEnd")

        // Determine delimiters
        var startDelimiter: UInt8
        var endDelimiter: UInt8

        if let customStart = customStart, let customEnd = customEnd {
            guard let start = parseHexValue(customStart), let end = parseHexValue(customEnd) else {
                throw Abort(.badRequest, reason: "Invalid custom hex delimiters")
            }
            startDelimiter = start
            endDelimiter = end
        } else {
            guard let delimiter = getDelimiterByName(delimiterName) else {
                throw Abort(.badRequest, reason: "Unknown delimiter")
            }
            startDelimiter = delimiter.startChar
            endDelimiter = delimiter.endChar
        }

        // Check file size (100MB max)
        let maxSize = 100 * 1024 * 1024
        guard bodyData.count <= maxSize else {
            throw Abort(.payloadTooLarge, reason: "File exceeds 100MB limit")
        }

        // Extract from file data
        let result = SignalingFlexible.extract(data: bodyData, startDelimiter: startDelimiter, endDelimiter: endDelimiter)
        return result
    }
}

// MARK: - Helper Functions

private func hexStringToData(_ hexString: String) -> Data? {
    let hexString = hexString.replacingOccurrences(of: " ", with: "").uppercased()

    guard hexString.count % 2 == 0 else { return nil }

    var data = Data()
    var index = hexString.startIndex

    while index < hexString.endIndex {
        let nextIndex = hexString.index(index, offsetBy: 2)
        let hexByte = String(hexString[index..<nextIndex])
        guard let byte = UInt8(hexByte, radix: 16) else { return nil }
        data.append(byte)
        index = nextIndex
    }

    return data
}

private func parseHexValue(_ value: String) -> UInt8? {
    let hex = value.replacingOccurrences(of: "0x", with: "").uppercased()
    return UInt8(hex, radix: 16)
}
