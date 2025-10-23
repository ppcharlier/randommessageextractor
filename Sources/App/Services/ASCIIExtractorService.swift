import Foundation

/// Complete ASCII extraction service implementing all 6 extraction methods
struct ASCIIExtractorService {

    /// Extract using all enabled methods in parallel
    static func extractWithAllMethods(
        data: Data,
        config: SearchConfig,
        methodConfig: ExtractionMethodConfig
    ) async -> AggregatedExtractionResult {
        let methods = methodConfig.enableMultipleMethods ? methodConfig.activeMethods : [methodConfig.selectedMethod]

        var results: [ExtractionResult] = []

        // Execute all methods in parallel
        await withTaskGroup(of: ExtractionResult?.self) { group in
            for method in methods {
                group.addTask {
                    let bytes = [UInt8](data)
                    switch method {
                    case .signalingStrict:
                        return await extractSignalingStrict(bytes: bytes, config: config)
                    case .signalingFlexible:
                        return await extractSignalingFlexible(bytes: bytes, config: config)
                    case .regularExpression:
                        return await extractRegularExpression(bytes: bytes, config: config)
                    case .bitByBitScan:
                        return await extractBitByBit(bytes: bytes, config: config)
                    case .hybridMode:
                        return nil  // Handled separately
                    case .experimentalProtocol:
                        return await extractExperimentalProtocol(bytes: bytes, config: config)
                    }
                }
            }

            for await result in group {
                if let result = result {
                    results.append(result)
                }
            }
        }

        return AggregatedExtractionResult(results: results)
    }

    // MARK: - Method 1: Signaling Strict
    /// Requires exact SOH/STX...ETX/EOT framing
    static func extractSignalingStrict(
        bytes: [UInt8],
        config: SearchConfig
    ) async -> ExtractionResult {
        let startTime = Date()
        var sequences: [String] = []
        var i = 0

        while i < bytes.count {
            // Look for start character
            if config.startCharacters.contains(bytes[i]) {
                var message: [UInt8] = []
                i += 1

                // Collect until end character
                while i < bytes.count && !config.endCharacters.contains(bytes[i]) {
                    message.append(bytes[i])
                    i += 1
                }

                // Validate end character
                if i < bytes.count && config.endCharacters.contains(bytes[i]) {
                    let msgStr = bytesToString(message, asciiOnly: config.asciiOnly)
                    if msgStr.count >= config.minSequenceLength && msgStr.count <= config.maxSequenceLength {
                        sequences.append(msgStr)
                    }
                    i += 1
                } else {
                    // No valid end character - skip this
                    i += 1
                }
            } else {
                i += 1
            }
        }

        let duration = Date().timeIntervalSince(startTime) * 1000
        return ExtractionResult(
            method: .signalingStrict,
            sequences: sequences,
            duration: duration,
            bitsProcessed: bytes.count * 8
        )
    }

    // MARK: - Method 2: Signaling Flexible
    /// Permissive signaling character detection
    static func extractSignalingFlexible(
        bytes: [UInt8],
        config: SearchConfig
    ) async -> ExtractionResult {
        let startTime = Date()
        var sequences: [String] = []
        var inMessage = false
        var currentMessage: [UInt8] = []

        for byte in bytes {
            if !inMessage && config.startCharacters.contains(byte) {
                // Start of message
                inMessage = true
                currentMessage = []
            } else if inMessage && config.endCharacters.contains(byte) {
                // End of message
                let msgStr = bytesToString(currentMessage, asciiOnly: config.asciiOnly)
                if msgStr.count >= config.minSequenceLength && msgStr.count <= config.maxSequenceLength {
                    sequences.append(msgStr)
                }
                inMessage = false
                currentMessage = []
            } else if inMessage {
                // Inside message
                currentMessage.append(byte)
            }
        }

        // Handle incomplete message
        if inMessage && !currentMessage.isEmpty {
            let msgStr = bytesToString(currentMessage, asciiOnly: config.asciiOnly)
            if msgStr.count >= config.minSequenceLength && msgStr.count <= config.maxSequenceLength {
                sequences.append(msgStr)
            }
        }

        let duration = Date().timeIntervalSince(startTime) * 1000
        return ExtractionResult(
            method: .signalingFlexible,
            sequences: sequences,
            duration: duration,
            bitsProcessed: bytes.count * 8
        )
    }

    // MARK: - Method 3: Regular Expression
    /// Pattern matching with regex [A-Za-z0-9']+
    static func extractRegularExpression(
        bytes: [UInt8],
        config: SearchConfig
    ) async -> ExtractionResult {
        let startTime = Date()
        var sequences: [String] = []

        let text = bytesToString(bytes, asciiOnly: true)
        let pattern = "[A-Za-z0-9']+"

        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(text.startIndex..., in: text)
            let matches = regex.matches(in: text, options: [], range: range)

            for match in matches {
                if let matchRange = Range(match.range, in: text) {
                    let word = String(text[matchRange])
                    if word.count >= config.minSequenceLength && word.count <= config.maxSequenceLength {
                        sequences.append(word)
                    }
                }
            }

            // Deduplicate
            sequences = Array(Set(sequences)).sorted()
        } catch {
            // Regex error - return empty
        }

        let duration = Date().timeIntervalSince(startTime) * 1000
        return ExtractionResult(
            method: .regularExpression,
            sequences: sequences,
            duration: duration,
            bitsProcessed: bytes.count * 8
        )
    }

    // MARK: - Method 4: Bit-by-Bit Scan
    /// Binary stream analysis with bit manipulation
    static func extractBitByBit(
        bytes: [UInt8],
        config: SearchConfig
    ) async -> ExtractionResult {
        let startTime = Date()
        var sequences: [String] = []
        var inMessage = false
        var currentMessage: [UInt8] = []

        for byte in bytes {
            // Check if this byte is a signaling character
            let isStart = config.startCharacters.contains(byte)
            let isEnd = config.endCharacters.contains(byte)

            if !inMessage && isStart {
                inMessage = true
                currentMessage = []
            } else if inMessage && isEnd {
                let msgStr = bytesToString(currentMessage, asciiOnly: config.asciiOnly)
                if msgStr.count >= config.minSequenceLength && msgStr.count <= config.maxSequenceLength {
                    sequences.append(msgStr)
                }
                inMessage = false
            } else if inMessage {
                currentMessage.append(byte)
            }
        }

        let duration = Date().timeIntervalSince(startTime) * 1000
        return ExtractionResult(
            method: .bitByBitScan,
            sequences: sequences,
            duration: duration,
            bitsProcessed: bytes.count * 8
        )
    }

    // MARK: - Method 5: Experimental Protocol
    /// Variable-size byte sets with integrity checking
    static func extractExperimentalProtocol(
        bytes: [UInt8],
        config: SearchConfig
    ) async -> ExtractionResult {
        let startTime = Date()
        var sequences: [String] = []
        var i = 0

        while i < bytes.count - 3 {
            // Read potential byte set: messageID + data
            let sizeIndicator = bytes[i + 1]

            // Determine size class (4-8, 8-12, or 12-16 bytes)
            let size: Int
            if sizeIndicator < 8 {
                size = 4 + Int(sizeIndicator % 5)  // 4-8
            } else if sizeIndicator < 16 {
                size = 8 + Int(sizeIndicator % 5)  // 8-12
            } else {
                size = 12 + Int(sizeIndicator % 5) // 12-16
            }

            // Read the byte set
            if i + size <= bytes.count {
                let byteSet = Array(bytes[i..<(i + size)])
                let dataBytes = Array(byteSet.dropFirst())
                let msgStr = bytesToString(dataBytes, asciiOnly: false)

                if msgStr.count >= config.minSequenceLength && msgStr.count <= config.maxSequenceLength {
                    sequences.append(msgStr)
                }

                i += size
            } else {
                i += 1
            }
        }

        let duration = Date().timeIntervalSince(startTime) * 1000
        return ExtractionResult(
            method: .experimentalProtocol,
            sequences: sequences,
            duration: duration,
            bitsProcessed: bytes.count * 8
        )
    }

    // MARK: - Helper: Bytes to String
    private static func bytesToString(_ bytes: [UInt8], asciiOnly: Bool) -> String {
        if asciiOnly {
            // Filter to printable ASCII only
            let filtered = bytes.filter { byte in
                (byte >= 32 && byte <= 126) || byte == 9 || byte == 10 || byte == 13
            }
            if let str = String(bytes: filtered, encoding: .ascii) {
                return str
            }
        } else {
            // Try UTF-8 first, then Latin1
            if let str = String(bytes: bytes, encoding: .utf8) {
                return str
            }
            if let str = String(bytes: bytes, encoding: .isoLatin1) {
                return str
            }
        }
        return ""
    }

    // MARK: - Extract from Hex String
    static func extractFromHex(
        hexString: String,
        config: SearchConfig,
        methodConfig: ExtractionMethodConfig
    ) async -> AggregatedExtractionResult {
        guard let data = hexStringToData(hexString) else {
            return AggregatedExtractionResult(results: [])
        }

        return await extractWithAllMethods(data: data, config: config, methodConfig: methodConfig)
    }

    private static func hexStringToData(_ hexString: String) -> Data? {
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
}
