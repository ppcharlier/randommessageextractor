import Vapor
import Foundation

struct GenerateRequest: Content {
    let type: String          // "random", "pattern", "ansi", "protobuf", "csv"
    let delimiter: String?    // "SOH/ETX" etc
    let customStart: String?  // "0x01"
    let customEnd: String?    // "0x03"
    let messageCount: Int?    // For random/pattern generators
    let minLength: Int?       // Min message length
    let maxLength: Int?       // Max message length
    let pattern: String?      // "hello", "numbers", "mixed"
    let encoding: String?     // "hex" or "base64" - default hex
}

struct GenerateResponse: Content {
    let data: String          // Hex or base64 encoded
    let encoding: String      // "hex" or "base64"
    let length: Int           // Bytes count
    let delimiter: String
}

struct GeneratorPreset: Content {
    let name: String
    let description: String
    let encoding: String  // "hex" or "base64"
    let data: String
}

func generatorRoutes(_ app: Application) throws {
    // POST /api/generator/generate - Generate test data
    app.post("api", "generator", "generate") { req -> GenerateResponse in
        let genReq = try req.content.decode(GenerateRequest.self)

        // Get delimiters
        var startDelimiter: UInt8 = 0x01
        var endDelimiter: UInt8 = 0x03
        var delimiterName = "SOH/ETX"

        if let customStart = genReq.customStart, let customEnd = genReq.customEnd {
            if let start = parseHexValue(customStart), let end = parseHexValue(customEnd) {
                startDelimiter = start
                endDelimiter = end
                delimiterName = "\(customStart)/\(customEnd)"
            }
        } else if let delimName = genReq.delimiter {
            if let delim = getDelimiterByName(delimName) {
                startDelimiter = delim.startChar
                endDelimiter = delim.endChar
                delimiterName = delim.name
            }
        }

        // Generate data based on type
        let data: Data
        switch genReq.type.lowercased() {
        case "random":
            let msgCount = genReq.messageCount ?? 5
            let minLen = genReq.minLength ?? 10
            let maxLen = genReq.maxLength ?? 50
            data = ByteGenerator.generateWithDelimiters(
                messageCount: msgCount,
                minMessageLength: minLen,
                maxMessageLength: maxLen,
                startDelimiter: startDelimiter,
                endDelimiter: endDelimiter,
                noisePercentage: 0
            )

        case "pattern":
            let msgCount = genReq.messageCount ?? 5
            let pattern = genReq.pattern ?? "hello"
            data = ByteGenerator.generatePattern(
                pattern: pattern,
                repetitions: msgCount,
                startDelimiter: startDelimiter,
                endDelimiter: endDelimiter
            )

        case "ansi":
            data = ByteGenerator.generateANSIPayload()

        case "protobuf":
            data = ByteGenerator.generateProtobufStyle()

        case "csv":
            let rowCount = genReq.messageCount ?? 10
            data = ByteGenerator.generateCSVStyle(rowCount: rowCount)

        default:
            throw Abort(.badRequest, reason: "Unknown generator type: \(genReq.type)")
        }

        // Encode output
        let encoding = genReq.encoding ?? "hex"
        let encodedData: String
        if encoding.lowercased() == "base64" {
            encodedData = ByteGenerator.toBase64(data)
        } else {
            encodedData = ByteGenerator.toHexString(data)
        }

        return GenerateResponse(
            data: encodedData,
            encoding: encoding.lowercased(),
            length: data.count,
            delimiter: delimiterName
        )
    }

    // GET /api/generator/presets - Get available presets
    app.get("api", "generator", "presets") { req -> [GeneratorPreset] in
        // Generate samples for display
        let ansiData = ByteGenerator.generateANSIPayload()
        let protobufData = ByteGenerator.generateProtobufStyle()
        let csvData = ByteGenerator.generateCSVStyle(rowCount: 3)

        return [
            GeneratorPreset(
                name: "ANSI Payload",
                description: "Typical ANSI terminal messages (SOH/ETX delimiters)",
                encoding: "hex",
                data: ByteGenerator.toHexString(ansiData)
            ),
            GeneratorPreset(
                name: "Protobuf Style",
                description: "Protocol buffer delimited format with length prefixes",
                encoding: "hex",
                data: ByteGenerator.toHexString(protobufData)
            ),
            GeneratorPreset(
                name: "CSV Data",
                description: "CSV-like delimited records",
                encoding: "hex",
                data: ByteGenerator.toHexString(csvData)
            )
        ]
    }

    // POST /api/generator/quick - Quick generate with defaults
    app.post("api", "generator", "quick") { req -> GenerateResponse in
        let type = (try? req.query.get(String.self, at: "type")) ?? "random"

        let genReq = GenerateRequest(
            type: type,
            delimiter: "SOH/ETX",
            customStart: nil,
            customEnd: nil,
            messageCount: 5,
            minLength: 10,
            maxLength: 50,
            pattern: "hello",
            encoding: "hex"
        )

        // Re-use main generator logic
        var startDelimiter: UInt8 = 0x01
        var endDelimiter: UInt8 = 0x03

        let data: Data
        switch type.lowercased() {
        case "random":
            data = ByteGenerator.generateWithDelimiters(
                messageCount: 5,
                minMessageLength: 10,
                maxMessageLength: 50,
                startDelimiter: startDelimiter,
                endDelimiter: endDelimiter
            )
        case "pattern":
            data = ByteGenerator.generatePattern(
                pattern: "hello",
                repetitions: 5,
                startDelimiter: startDelimiter,
                endDelimiter: endDelimiter
            )
        case "ansi":
            data = ByteGenerator.generateANSIPayload()
        case "protobuf":
            data = ByteGenerator.generateProtobufStyle()
        case "csv":
            data = ByteGenerator.generateCSVStyle(rowCount: 5)
        default:
            data = ByteGenerator.generateWithDelimiters(
                messageCount: 5,
                minMessageLength: 10,
                maxMessageLength: 50,
                startDelimiter: startDelimiter,
                endDelimiter: endDelimiter
            )
        }

        let encodedData = ByteGenerator.toHexString(data)

        return GenerateResponse(
            data: encodedData,
            encoding: "hex",
            length: data.count,
            delimiter: "SOH/ETX"
        )
    }
}

// MARK: - Helpers (copied from ExtractionRoutes)
private func parseHexValue(_ value: String) -> UInt8? {
    let hex = value.replacingOccurrences(of: "0x", with: "").uppercased()
    return UInt8(hex, radix: 16)
}
