import Foundation

/// Generates test data with embedded delimiters for extraction testing
struct ByteGenerator {
    /// Generate random bytes with embedded messages between delimiters
    static func generateWithDelimiters(
        messageCount: Int,
        minMessageLength: Int,
        maxMessageLength: Int,
        startDelimiter: UInt8,
        endDelimiter: UInt8,
        noisePercentage: Int = 0  // 0-100: percentage of random noise bytes
    ) -> Data {
        var result = Data()
        var random = SystemRandomNumberGenerator()

        for _ in 0..<messageCount {
            // Add optional noise before message
            if noisePercentage > 0 && Int.random(in: 0..<100, using: &random) < noisePercentage {
                let noiseBytes = Int.random(in: 1...5, using: &random)
                for _ in 0..<noiseBytes {
                    result.append(UInt8.random(in: 0...255, using: &random))
                }
            }

            // Add delimiter + message + delimiter
            result.append(startDelimiter)

            let messageLength = Int.random(
                in: minMessageLength...maxMessageLength,
                using: &random
            )
            let message = generateRandomASCII(length: messageLength, using: &random)
            result.append(contentsOf: message)

            result.append(endDelimiter)
        }

        return result
    }

    /// Generate messages with specific content patterns
    static func generatePattern(
        pattern: String,  // "hello", "numbers", "mixed"
        repetitions: Int,
        startDelimiter: UInt8,
        endDelimiter: UInt8
    ) -> Data {
        var result = Data()

        for i in 0..<repetitions {
            result.append(startDelimiter)

            let message: String
            switch pattern {
            case "hello":
                message = "Hello World \(i)"
            case "numbers":
                message = String(format: "%010d", i)
            case "mixed":
                message = "MSG-\(i):DATA[\(UUID().uuidString.prefix(8))]"
            default:
                message = "Test Message \(i)"
            }

            if let messageData = message.data(using: .utf8) {
                result.append(contentsOf: messageData)
            }

            result.append(endDelimiter)
        }

        return result
    }

    /// Generate hex string representation
    static func toHexString(_ data: Data) -> String {
        return data.map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    /// Generate base64 representation
    static func toBase64(_ data: Data) -> String {
        return data.base64EncodedString()
    }

    // MARK: - Helpers

    private static func generateRandomASCII(
        length: Int,
        using generator: inout SystemRandomNumberGenerator
    ) -> Data {
        var result = Data()
        for _ in 0..<length {
            // Generate printable ASCII (32-126)
            let byte = UInt8.random(in: 32...126, using: &generator)
            result.append(byte)
        }
        return result
    }

    // MARK: - Preset Generators

    /// Generate a typical payload similar to ANSI messaging
    static func generateANSIPayload() -> Data {
        var result = Data()

        // Simulate an ANSI messages stream (SOH=0x01, ETX=0x03)
        let messages = [
            "TERMINAL_LOGIN:user@host",
            "COMMAND:ls -la /",
            "STATUS:OK",
            "DATA:100bytes received",
            "CLOSE:session terminated"
        ]

        for message in messages {
            result.append(0x01)  // SOH
            if let data = message.data(using: .utf8) {
                result.append(contentsOf: data)
            }
            result.append(0x03)  // ETX
        }

        return result
    }

    /// Generate protocol buffer-like delimited stream
    static func generateProtobufStyle() -> Data {
        var result = Data()

        // Simulate protobuf delimited format (varint length + data)
        let messages = ["Hello", "Protocol", "Buffers", "Demo", "12345"]

        for message in messages {
            if let msgData = message.data(using: .utf8) {
                // Add length as varint (simplified - just the byte count)
                result.append(UInt8(msgData.count))
                result.append(contentsOf: msgData)
            }
        }

        return result
    }

    /// Generate CSV-like delimited data
    static func generateCSVStyle(rowCount: Int = 10) -> Data {
        var result = Data()

        for i in 0..<rowCount {
            let row = "ID,Name,Value,Status\n\(i),User\(i),\(i * 100),Active\n"
            if let data = row.data(using: .utf8) {
                result.append(contentsOf: data)
            }
        }

        return result
    }
}
