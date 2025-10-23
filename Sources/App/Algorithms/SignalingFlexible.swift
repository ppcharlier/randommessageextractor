import Foundation
import Vapor

struct ExtractionStatistics: Codable {
    let count: Int
    let duration: Double
    let bitsProcessed: Int
    let avgMessageLength: Double
    let minMessageLength: Int
    let maxMessageLength: Int
}

struct ExtractionResult: Content {
    let id: String
    let sequences: [String]
    let statistics: ExtractionStatistics
    let timestamp: String
    let delimiter: DelimiterInfo
}

struct DelimiterInfo: Codable {
    let id: String
    let name: String
    let startChar: Int
    let endChar: Int
}

class SignalingFlexible {
    /// Extract variable-length messages between start and end delimiters
    static func extract(
        data: Data,
        startDelimiter: UInt8,
        endDelimiter: UInt8
    ) -> ExtractionResult {
        let startTime = Date()

        let bytes = [UInt8](data)
        var sequences: [String] = []
        var currentMessage: [UInt8] = []
        var isInsideMessage = false
        var lengths: [Int] = []

        for byte in bytes {
            if byte == startDelimiter && !isInsideMessage {
                // Start of new message
                isInsideMessage = true
                currentMessage = []
            } else if byte == endDelimiter && isInsideMessage {
                // End of message
                isInsideMessage = false
                let messageStr = bytesToString(currentMessage)
                if !messageStr.isEmpty {
                    sequences.append(messageStr)
                    lengths.append(currentMessage.count)
                }
                currentMessage = []
            } else if isInsideMessage {
                // Inside message - collect bytes
                currentMessage.append(byte)
            }
        }

        // Handle incomplete message (no end delimiter)
        if isInsideMessage && !currentMessage.isEmpty {
            let messageStr = bytesToString(currentMessage)
            sequences.append(messageStr)
            lengths.append(currentMessage.count)
        }

        let duration = Date().timeIntervalSince(startTime) * 1000 // ms
        let bitsProcessed = bytes.count * 8
        let avgLength = lengths.isEmpty ? 0 : Double(lengths.reduce(0, +)) / Double(lengths.count)
        let minLength = lengths.isEmpty ? 0 : lengths.min() ?? 0
        let maxLength = lengths.isEmpty ? 0 : lengths.max() ?? 0

        let stats = ExtractionStatistics(
            count: sequences.count,
            duration: duration,
            bitsProcessed: bitsProcessed,
            avgMessageLength: avgLength,
            minMessageLength: minLength,
            maxMessageLength: maxLength
        )

        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.string(from: Date())

        return ExtractionResult(
            id: UUID().uuidString,
            sequences: sequences,
            statistics: stats,
            timestamp: timestamp,
            delimiter: DelimiterInfo(
                id: String(format: "%02X", startDelimiter),
                name: getDelimiterName(startDelimiter, endDelimiter),
                startChar: Int(startDelimiter),
                endChar: Int(endDelimiter)
            )
        )
    }

    /// Convert bytes to string with UTF-8 fallback to Latin1
    private static func bytesToString(_ bytes: [UInt8]) -> String {
        if let utf8String = String(bytes: bytes, encoding: .utf8) {
            return utf8String
        }
        // Fallback to Latin1
        return String(bytes: bytes, encoding: .isoLatin1) ?? ""
    }

    /// Get human-readable name for delimiter pair
    private static func getDelimiterName(_ start: UInt8, _ end: UInt8) -> String {
        switch (start, end) {
        case (0x01, 0x03): return "SOH/ETX"
        case (0x02, 0x03): return "STX/ETX"
        case (0x02, 0x17): return "STX/ETB"
        case (0x01, 0x04): return "SOH/EOT"
        case (0x1C, 0x1D): return "FS/GS"
        case (0x1E, 0x1F): return "RS/US"
        case (0x1B, 0x1B): return "ESC/ESC"
        case (0x10, 0x10): return "DLE/DLE"
        default: return String(format: "0x%02X/0x%02X", start, end)
        }
    }
}
