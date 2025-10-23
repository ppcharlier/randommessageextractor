import Vapor
import Foundation

// MARK: - Request/Response Models

struct ExtractionAdvancedRequest: Content {
    let data: String
    let encoding: String  // "hex" or "base64"
    let config: SearchConfigRequest?
    let methodConfig: ExtractionMethodConfigRequest?
}

struct SearchConfigRequest: Codable {
    var useSignalingChars: Bool = true
    var minSequenceLength: Int = 1
    var maxSequenceLength: Int = 10000
    var asciiOnly: Bool = false
    var requireSOHStart: Bool = false
    var requireSTXStart: Bool = false
    var acceptETXEnd: Bool = true
    var acceptEOTEnd: Bool = true
    var delimiter: String?  // "SOH/ETX" etc
    var customStart: String?  // "0x01"
    var customEnd: String?    // "0x03"
    var reverseEach64BitWord: Bool = false

    func toSearchConfig() -> SearchConfig {
        var config = SearchConfig()
        config.useSignalingChars = useSignalingChars
        config.minSequenceLength = minSequenceLength
        config.maxSequenceLength = maxSequenceLength
        config.asciiOnly = asciiOnly
        config.requireSOHStart = requireSOHStart
        config.requireSTXStart = requireSTXStart
        config.acceptETXEnd = acceptETXEnd
        config.acceptEOTEnd = acceptEOTEnd
        config.reverseEach64BitWord = reverseEach64BitWord

        // Apply delimiter
        if let delimiterName = delimiter {
            if let delim = DelimiterPair.standardPairs.first(where: { $0.name == delimiterName }) {
                config.applyDelimiter(delim)
            }
        } else if let customStart = customStart, let customEnd = customEnd {
            if let start = parseHexValue(customStart), let end = parseHexValue(customEnd) {
                config.startCharacters = [start]
                config.endCharacters = [end]
            }
        }

        return config
    }
}

struct ExtractionMethodConfigRequest: Codable {
    let selectedMethod: String?  // "signalingStrict" etc
    let enableMultipleMethods: Bool?
    let activeMethods: [String]?  // ["signalingStrict", "signalingFlexible"]

    func toMethodConfig() -> ExtractionMethodConfig {
        var config = ExtractionMethodConfig()

        if let methodStr = selectedMethod,
           let method = ExtractionMethod(rawValue: methodStr) {
            config.selectedMethod = method
        }

        if let enable = enableMultipleMethods {
            config.enableMultipleMethods = enable
        }

        if let methods = activeMethods {
            config.activeMethods = Set(methods.compactMap { ExtractionMethod(rawValue: $0) })
        }

        return config
    }
}

struct FilterRequest: Content {
    let text: String
    let banEnabled: Bool?
    let repetitionEnabled: Bool?
    let repetitionThreshold: Double?
    let banList: [String]?
}

struct BufferGenerateRequest: Content {
    let type: String  // "sohEtx", "stxEtx", "crlf", "randomASCII", "controlSequences"
    let count: Int?
    let text: String?
}

struct ANSICharacterResponse: Content {
    let characters: [ANSIControlCharacter]
}

struct DelimiterResponse: Content {
    let delimiters: [DelimiterPair]
}

struct ExtractionMethodResponse: Content {
    let methods: [MethodInfo]

    struct MethodInfo: Content {
        let id: String
        let displayName: String
        let description: String
    }
}

// MARK: - Routes Registration

func extractionRoutesV3(_ app: Application) throws {
    // MARK: - Health & Info Routes

    app.get("api", "v3", "health") { req -> String in
        return "ERA Extraction Service v3"
    }

    // Get all ANSI control characters
    app.get("api", "v3", "ansi-characters") { req -> ANSICharacterResponse in
        return ANSICharacterResponse(characters: ANSI_CONTROL_CHARACTERS)
    }

    // Get all delimiter pairs
    app.get("api", "v3", "delimiters") { req -> DelimiterResponse in
        return DelimiterResponse(delimiters: DelimiterPair.standardPairs)
    }

    // Get all extraction methods
    app.get("api", "v3", "extraction-methods") { req -> ExtractionMethodResponse in
        let methods = ExtractionMethod.allCases.map { method in
            ExtractionMethodResponse.MethodInfo(
                id: method.rawValue,
                displayName: method.displayName,
                description: method.description
            )
        }
        return ExtractionMethodResponse(methods: methods)
    }

    // MARK: - Basic Extraction (v1 compatibility)

    app.post("api", "extract") { req -> AggregatedExtractionResult in
        let request = try req.content.decode(ExtractionAdvancedRequest.self)

        // Decode data
        let data: Data
        if request.encoding.lowercased() == "base64" {
            guard let base64Data = Data(base64Encoded: request.data) else {
                throw Abort(.badRequest, reason: "Invalid base64 encoding")
            }
            data = base64Data
        } else {
            guard let hexData = hexStringToData(request.data) else {
                throw Abort(.badRequest, reason: "Invalid hex encoding")
            }
            data = hexData
        }

        // Default config
        var config = SearchConfig()
        var methodConfig = ExtractionMethodConfig()

        // Extract
        let result = await ASCIIExtractorService.extractWithAllMethods(
            data: data,
            config: config,
            methodConfig: methodConfig
        )

        return result
    }

    // MARK: - Advanced Extraction with Full Config

    app.post("api", "v3", "extract") { req -> AggregatedExtractionResult in
        let request = try req.content.decode(ExtractionAdvancedRequest.self)

        // Decode data
        let data: Data
        if request.encoding.lowercased() == "base64" {
            guard let base64Data = Data(base64Encoded: request.data) else {
                throw Abort(.badRequest, reason: "Invalid base64 encoding")
            }
            data = base64Data
        } else {
            guard let hexData = hexStringToData(request.data) else {
                throw Abort(.badRequest, reason: "Invalid hex encoding")
            }
            data = hexData
        }

        // Build config from request
        var config = request.config?.toSearchConfig() ?? SearchConfig()
        var methodConfig = request.methodConfig?.toMethodConfig() ?? ExtractionMethodConfig()

        // Extract
        let result = await ASCIIExtractorService.extractWithAllMethods(
            data: data,
            config: config,
            methodConfig: methodConfig
        )

        return result
    }

    // MARK: - Filter Operations

    app.post("api", "v3", "filter") { req -> FilterEngine.FilterResult in
        let request = try req.content.decode(FilterRequest.self)

        var filterEngine = FilterEngine()

        // Add ban list if provided
        if let banList = request.banList {
            for phrase in banList {
                filterEngine.addToBanList(phrase)
            }
        }

        // Apply filter
        let result = filterEngine.filter(
            request.text,
            banEnabled: request.banEnabled ?? true,
            repetitionEnabled: request.repetitionEnabled ?? true,
            repetitionThreshold: request.repetitionThreshold ?? 0.6
        )

        return result
    }

    // Get repetition score for text
    app.post("api", "v3", "repetition-score") { req -> String in
        struct RepetitionRequest: Content {
            let text: String
        }

        let request = try req.content.decode(RepetitionRequest.self)
        let filterEngine = FilterEngine()
        let score = filterEngine.repetitionScore(for: request.text)

        return """
        {"score": \(score), "percentage": \(Int(score * 100))}
        """
    }

    // MARK: - Buffer Operations

    app.post("api", "v3", "buffer/generate") { req -> String in
        let request = try req.content.decode(BufferGenerateRequest.self)

        var buffer = BufferService()

        switch request.type.lowercased() {
        case "sohetx":
            buffer.generateSOHETXPattern(request.text ?? "HelloWorld")
        case "stxetx":
            buffer.generateSTXETXPattern(request.text ?? "TestMessage")
        case "crlf":
            buffer.generateCRLFPattern(request.text ?? "LineData")
        case "randomascii":
            buffer.generateRandomASCII(count: request.count ?? 100)
        case "controlsequences":
            buffer.generateControlSequences(count: request.count ?? 10)
        default:
            throw Abort(.badRequest, reason: "Unknown buffer type")
        }

        let bytes = buffer.getBufferAsBytes()
        let hexString = bytes.map { String(format: "%02X", $0) }.joined(separator: " ")

        return """
        {"generated": true, "byteCount": \(bytes.count), "hex": "\(hexString)", "hexLength": \(hexString.count)}
        """
    }

    // Get buffer info
    app.get("api", "v3", "buffer/info") { req -> String in
        let buffer = BufferService()
        return """
        {"bufferSize": \(buffer.bufferSize), "maxSize": 1000, "isGenerating": \(buffer.isGenerating)}
        """
    }

    // MARK: - File Upload Extraction

    app.post("api", "v3", "extract-file") { req -> AggregatedExtractionResult in
        // For now, use the body data as-is
        // In a real implementation, this would handle multipart form data
        let data = Data()  // Empty for now - Vapor 4 requires async/multipart for file uploads

        // Get parameters from query
        let delimiterName = (try? req.query.get(String.self, at: "delimiter")) ?? "SOH/ETX"
        let enableMultiple = (try? req.query.get(Bool.self, at: "enableMultipleMethods")) ?? false

        // Build config
        var config = SearchConfig()
        if let delim = DelimiterPair.standardPairs.first(where: { $0.name == delimiterName }) {
            config.applyDelimiter(delim)
        }

        var methodConfig = ExtractionMethodConfig()
        methodConfig.enableMultipleMethods = enableMultiple

        // Extract (with empty data for now)
        let result = await ASCIIExtractorService.extractWithAllMethods(
            data: data,
            config: config,
            methodConfig: methodConfig
        )

        return result
    }

    // MARK: - Chat Messages with Filtering

    app.post("api", "v3", "chat/message") { req -> ChatMessage in
        struct ChatMessageRequest: Content {
            let text: String
            let role: String
            let filterEnabled: Bool?
            let banList: [String]?
        }

        let request = try req.content.decode(ChatMessageRequest.self)

        var filterEngine = FilterEngine()
        if let banList = request.banList {
            for phrase in banList {
                filterEngine.addToBanList(phrase)
            }
        }

        let filterResult = filterEngine.filter(
            request.text,
            banEnabled: request.filterEnabled ?? true,
            repetitionEnabled: request.filterEnabled ?? true,
            repetitionThreshold: 0.6
        )

        return ChatMessage(
            role: request.role,
            text: request.text,
            isHidden: filterResult.shouldHide,
            repetitionScore: filterResult.repetitionScore
        )
    }

    // MARK: - Batch Processing

    app.post("api", "v3", "batch-extract") { req -> String in
        struct BatchRequest: Content {
            let items: [BatchItem]

            struct BatchItem: Codable {
                let id: String
                let data: String
                let encoding: String
            }
        }

        let request = try req.content.decode(BatchRequest.self)

        var results: [String] = []

        for item in request.items {
            if let hexData = hexStringToData(item.data) {
                let config = SearchConfig()
                let methodConfig = ExtractionMethodConfig()

                let result = await ASCIIExtractorService.extractWithAllMethods(
                    data: hexData,
                    config: config,
                    methodConfig: methodConfig
                )

                results.append("""
                {"id": "\(item.id)", "count": \(result.uniqueCount), "sequences": \(result.uniqueCount)}
                """)
            }
        }

        return "[\(results.joined(separator: ","))]"
    }
}

// MARK: - Helper Functions

private func hexStringToData(_ hexString: String) -> Data? {
    let hex = hexString.replacingOccurrences(of: " ", with: "").uppercased()
    guard hex.count % 2 == 0 else { return nil }

    var data = Data()
    var index = hex.startIndex

    while index < hex.endIndex {
        let nextIndex = hex.index(index, offsetBy: 2)
        let hexByte = String(hex[index..<nextIndex])
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
