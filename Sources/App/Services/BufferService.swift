import Foundation

/// Simulates a circular buffer of 64-bit words with pattern generation
class BufferService {
    /// Circular buffer: max 1000 UInt64 words
    private(set) var buffer: [UInt64] = []
    private let maxBufferSize = 1000
    private var isRunning: Bool = false
    private var generationTask: Task<Void, Never>?

    var bufferSize: Int {
        buffer.count
    }

    var isGenerating: Bool {
        isRunning
    }

    func startWorker(frequency: TimeInterval = 0.1) {
        guard !isRunning else { return }
        isRunning = true

        generationTask = Task {
            while isRunning {
                // Add random 64-bit word to buffer
                let word = UInt64.random(in: 0...UInt64.max)
                addToBuffer(word)

                try? await Task.sleep(nanoseconds: UInt64(frequency * 1_000_000_000))
            }
        }
    }

    func stopWorker() {
        isRunning = false
        generationTask?.cancel()
        generationTask = nil
    }

    func clearBuffer() {
        buffer.removeAll()
    }

    // MARK: - Pattern Generation

    /// Generate pattern: SOH + text + ETX
    func generateSOHETXPattern(_ text: String) {
        let pattern = generatePattern(startChar: 0x01, endChar: 0x03, text: text)
        addWordsToBuffer(pattern)
    }

    /// Generate pattern: STX + text + ETX
    func generateSTXETXPattern(_ text: String) {
        let pattern = generatePattern(startChar: 0x02, endChar: 0x03, text: text)
        addWordsToBuffer(pattern)
    }

    /// Generate pattern: text + CR + LF
    func generateCRLFPattern(_ text: String) {
        let pattern = generatePattern(startChar: UInt8.max, endChar: UInt8.max, text: text, useCRLF: true)
        addWordsToBuffer(pattern)
    }

    /// Generate random ASCII printable characters
    func generateRandomASCII(count: Int) {
        var bytes: [UInt8] = []
        for _ in 0..<count {
            let ascii = UInt8.random(in: 32...126)  // Printable ASCII range
            bytes.append(ascii)
        }
        addBytesToBuffer(bytes)
    }

    /// Generate ANSI control character sequences
    func generateControlSequences(count: Int) {
        var bytes: [UInt8] = []

        let controlChars: [UInt8] = [
            0x01, 0x02, 0x03, 0x04,  // SOH, STX, ETX, EOT
            0x1B, 0x1C, 0x1D, 0x1E,  // ESC, FS, GS, RS
            0x0A, 0x0D                // LF, CR
        ]

        for _ in 0..<count {
            // Add control char
            bytes.append(controlChars.randomElement() ?? 0x01)

            // Add some data
            for _ in 0..<Int.random(in: 3...10) {
                bytes.append(UInt8.random(in: 32...126))
            }

            // Add end char
            bytes.append(controlChars.randomElement() ?? 0x03)
        }

        addBytesToBuffer(bytes)
    }

    // MARK: - Buffer Management

    private func addToBuffer(_ word: UInt64) {
        buffer.append(word)
        if buffer.count > maxBufferSize {
            buffer.removeFirst()
        }
    }

    private func addWordsToBuffer(_ words: [UInt64]) {
        for word in words {
            addToBuffer(word)
        }
    }

    private func addBytesToBuffer(_ bytes: [UInt8]) {
        // Convert bytes to 64-bit words
        var currentWord: UInt64 = 0
        var byteCount = 0

        for byte in bytes {
            currentWord = (currentWord << 8) | UInt64(byte)
            byteCount += 1

            if byteCount == 8 {
                addToBuffer(currentWord)
                currentWord = 0
                byteCount = 0
            }
        }

        // Handle remaining bytes
        if byteCount > 0 {
            currentWord <<= (8 * (8 - byteCount))
            addToBuffer(currentWord)
        }
    }

    // MARK: - Conversion

    func getBufferAsBytes() -> [UInt8] {
        var bytes: [UInt8] = []

        for word in buffer {
            // Extract 8 bytes from 64-bit word (big-endian)
            for i in stride(from: 56, through: 0, by: -8) {
                let byte = UInt8((word >> i) & 0xFF)
                bytes.append(byte)
            }
        }

        return bytes
    }

    // MARK: - Private Helpers

    private func generatePattern(
        startChar: UInt8,
        endChar: UInt8,
        text: String,
        useCRLF: Bool = false
    ) -> [UInt64] {
        var bytes: [UInt8] = []

        if !useCRLF {
            bytes.append(startChar)
        }

        // Add text
        if let textData = text.data(using: .utf8) {
            bytes.append(contentsOf: textData)
        }

        if useCRLF {
            bytes.append(0x0D)  // CR
            bytes.append(0x0A)  // LF
        } else {
            bytes.append(endChar)
        }

        // Convert bytes to words
        var words: [UInt64] = []
        var currentWord: UInt64 = 0
        var byteCount = 0

        for byte in bytes {
            currentWord = (currentWord << 8) | UInt64(byte)
            byteCount += 1

            if byteCount == 8 {
                words.append(currentWord)
                currentWord = 0
                byteCount = 0
            }
        }

        // Handle remaining bytes
        if byteCount > 0 {
            currentWord <<= (8 * (8 - byteCount))
            words.append(currentWord)
        }

        return words
    }
}

// MARK: - MoulinetteService: Bit-by-Bit Analysis

/// Advanced bit-by-bit stream analysis
struct MoulinetteService {
    private var bitStream: [Bool] = []
    private var byteBuffer: [UInt8] = []
    private var currentBytePosition = 0

    private(set) var totalBitsProcessed: Int = 0
    private(set) var sequencesFound: Int = 0
    private(set) var lastFoundSequence: String = ""

    mutating func feedData(from words: [UInt64]) {
        // Convert 64-bit words to bits
        for word in words {
            for i in stride(from: 63, through: 0, by: -1) {
                let bit = (word >> i) & 1 == 1
                bitStream.append(bit)
                totalBitsProcessed += 1
            }
        }
    }

    mutating func searchBitByBit(config: SearchConfig) -> [String] {
        var sequences: [String] = []
        var inMessage = false
        var currentMessage: [UInt8] = []

        // Convert bits to bytes
        var byteBuffer: [UInt8] = []
        for i in stride(from: 0, to: bitStream.count, by: 8) {
            var byte: UInt8 = 0
            for j in 0..<8 {
                if i + j < bitStream.count && bitStream[i + j] {
                    byte |= (1 << (7 - j))
                }
            }
            byteBuffer.append(byte)
        }

        // Extract messages
        for byte in byteBuffer {
            if !inMessage && config.startCharacters.contains(byte) {
                inMessage = true
                currentMessage = []
            } else if inMessage && config.endCharacters.contains(byte) {
                let msgStr = String(bytes: currentMessage, encoding: .utf8) ?? ""
                if msgStr.count >= config.minSequenceLength && msgStr.count <= config.maxSequenceLength {
                    sequences.append(msgStr)
                    sequencesFound += 1
                    lastFoundSequence = msgStr
                }
                inMessage = false
            } else if inMessage {
                currentMessage.append(byte)
            }
        }

        return sequences
    }

    mutating func resetState() {
        bitStream.removeAll()
        byteBuffer.removeAll()
        currentBytePosition = 0
        totalBitsProcessed = 0
        sequencesFound = 0
        lastFoundSequence = ""
    }
}
