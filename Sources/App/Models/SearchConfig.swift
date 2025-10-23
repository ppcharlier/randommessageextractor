import Foundation
import Vapor

/// Complete extraction configuration for fine-tuned binary analysis
struct SearchConfig: Codable {
    // Signaling behavior
    var useSignalingChars: Bool = true
    var requireSOHStart: Bool = false
    var requireSTXStart: Bool = false
    var acceptETXEnd: Bool = true
    var acceptEOTEnd: Bool = true
    var waitForStartSequence: Bool = false
    var asciiStartHeader: String?

    // Sequence constraints
    var minSequenceLength: Int = 1
    var maxSequenceLength: Int = 10000
    var asciiOnly: Bool = false

    // Delimiter configuration
    var delimiter: DelimiterPair?
    var startCharacters: Set<UInt8> = [0x01, 0x02] // SOH, STX
    var endCharacters: Set<UInt8> = [0x03, 0x04]   // ETX, EOT

    // Bit reversal for endianness
    var reverseEach64BitWord: Bool = false

    // Experimental protocol config
    var verifyExperimentalIntegrity: Bool = true
    var experimentalMessageIDExpected: UInt8?

    init() {}

    init(delimiter: DelimiterPair) {
        self.delimiter = delimiter
        self.startCharacters = [delimiter.startChar]
        self.endCharacters = [delimiter.endChar]
    }

    mutating func applyDelimiter(_ delimiter: DelimiterPair) {
        self.delimiter = delimiter
        self.startCharacters = [delimiter.startChar]
        self.endCharacters = [delimiter.endChar]
    }
}

/// Extraction method configuration
struct ExtractionMethodConfig: Codable {
    var selectedMethod: ExtractionMethod = .signalingFlexible
    var enableMultipleMethods: Bool = false
    var activeMethods: Set<ExtractionMethod> = [.signalingFlexible]

    mutating func toggleMethod(_ method: ExtractionMethod) {
        if activeMethods.contains(method) {
            activeMethods.remove(method)
        } else {
            activeMethods.insert(method)
        }
    }
}

/// Experimental protocol byte set configuration
struct ExperimentalProtocolConfig: Codable {
    enum SizeClass: String, Codable {
        case small = "4-8"      // 4-8 bytes
        case medium = "8-12"    // 8-12 bytes
        case large = "12-16"    // 12-16 bytes

        var range: ClosedRange<Int> {
            switch self {
            case .small: return 4...8
            case .medium: return 8...12
            case .large: return 12...16
            }
        }
    }

    var verifyIntegrity: Bool = true
    var expectedMessageID: UInt8?
    var allowIncompleteSegments: Bool = false
    var minDataBytesPerSet: Int = 3
    var maxDataBytesPerSet: Int = 15
    var autoDetectBoundaries: Bool = true
    var preferredSizeClass: SizeClass?
}

/// Single extraction result from one method
struct ExtractionResult: Codable, Identifiable, Content {
    let id: String
    let method: ExtractionMethod
    let sequences: [String]
    let count: Int
    let duration: Double  // milliseconds
    let bitsProcessed: Int
    let avgLength: Double
    let minLength: Int
    let maxLength: Int
    let timestamp: String

    init(
        method: ExtractionMethod,
        sequences: [String],
        duration: Double,
        bitsProcessed: Int
    ) {
        self.id = UUID().uuidString
        self.method = method
        self.sequences = sequences
        self.count = sequences.count
        self.duration = duration
        self.bitsProcessed = bitsProcessed

        if sequences.isEmpty {
            self.avgLength = 0
            self.minLength = 0
            self.maxLength = 0
        } else {
            let lengths = sequences.map { $0.count }
            self.avgLength = Double(lengths.reduce(0, +)) / Double(lengths.count)
            self.minLength = lengths.min() ?? 0
            self.maxLength = lengths.max() ?? 0
        }

        self.timestamp = ISO8601DateFormatter().string(from: Date())
    }
}

/// Aggregated results from multiple extraction methods
struct AggregatedExtractionResult: Codable, Identifiable, Content {
    let id: String
    let results: [ExtractionResult]
    let uniqueSequences: Set<String>  // Deduped across all methods
    let timestamp: String
    let totalDuration: Double
    let activeMethods: [ExtractionMethod]

    var totalCount: Int {
        results.reduce(0) { $0 + $1.count }
    }

    var uniqueCount: Int {
        uniqueSequences.count
    }

    var averageDuration: Double {
        guard !results.isEmpty else { return 0 }
        return results.reduce(0) { $0 + $1.duration } / Double(results.count)
    }

    init(results: [ExtractionResult]) {
        self.id = UUID().uuidString
        self.results = results
        self.uniqueSequences = Set(results.flatMap { $0.sequences })
        self.timestamp = ISO8601DateFormatter().string(from: Date())
        self.totalDuration = results.reduce(0) { $0 + $1.duration }
        self.activeMethods = results.map { $0.method }
    }
}

/// Byte set for experimental protocol
struct ByteSet: Codable, Identifiable {
    let id: String
    let messageID: UInt8
    let size: Int
    let bytes: [UInt8]
    let dataBytes: [UInt8]

    var sizeClass: ExperimentalProtocolConfig.SizeClass? {
        switch size {
        case 4...8: return .small
        case 8...12: return .medium
        case 12...16: return .large
        default: return nil
        }
    }

    init(messageID: UInt8, bytes: [UInt8]) {
        self.id = UUID().uuidString
        self.messageID = messageID
        self.size = bytes.count
        self.bytes = bytes
        self.dataBytes = Array(bytes.dropFirst())  // Skip message ID byte
    }
}

/// Integrity error for experimental protocol
struct IntegrityError: Codable, Identifiable {
    let id: String
    let index: Int
    let expectedID: UInt8
    let actualID: UInt8

    init(index: Int, expectedID: UInt8, actualID: UInt8) {
        self.id = UUID().uuidString
        self.index = index
        self.expectedID = expectedID
        self.actualID = actualID
    }
}

/// Result from experimental protocol extraction
struct ExperimentalProtocolResult: Codable, Identifiable {
    let id: String
    let byteSets: [ByteSet]
    let messages: [String]
    let integrityErrors: [IntegrityError]
    let decodeSuccess: Bool
    let timestamp: String

    init(
        byteSets: [ByteSet],
        messages: [String],
        integrityErrors: [IntegrityError] = []
    ) {
        self.id = UUID().uuidString
        self.byteSets = byteSets
        self.messages = messages
        self.integrityErrors = integrityErrors
        self.decodeSuccess = integrityErrors.isEmpty
        self.timestamp = ISO8601DateFormatter().string(from: Date())
    }
}
