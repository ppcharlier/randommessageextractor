import Foundation
import Vapor

/// Advanced content filtering with ban list and repetition detection
struct FilterEngine {
    private var bannedPhrases: [String] = []

    init() {}

    // MARK: - Ban List Management

    mutating func addToBanList(_ phrase: String) {
        let normalized = phrase.lowercased()
        if !bannedPhrases.contains(normalized) {
            bannedPhrases.append(normalized)
        }
    }

    mutating func removeFromBanList(_ phrase: String) {
        let normalized = phrase.lowercased()
        bannedPhrases.removeAll { $0 == normalized }
    }

    func getBannedPhrases() -> [String] {
        return bannedPhrases
    }

    func isBanned(_ text: String, enabled: Bool = true) -> Bool {
        guard enabled && !bannedPhrases.isEmpty else { return false }

        let lowerText = text.lowercased()
        for phrase in bannedPhrases {
            if lowerText.contains(phrase) {
                return true
            }
        }
        return false
    }

    // MARK: - Repetition Scoring

    /// Calculate repetition score (0.0-1.0)
    /// Based on:
    /// - Word frequency analysis (weight: 0.5)
    /// - Bigram repetition (weight: 0.3)
    /// - Long loop detection (weight: 0.2)
    func repetitionScore(for text: String) -> Double {
        guard !text.isEmpty else { return 0.0 }

        let tokens = tokenize(text)
        guard tokens.count > 2 else { return 0.0 }

        // Component 1: Word Frequency (weight 0.5)
        let wordFrequencyScore = calculateWordFrequency(tokens: tokens)

        // Component 2: Bigram Repetition (weight 0.3)
        let bigramScore = calculateBigramRepetition(tokens: tokens)

        // Component 3: Long Loop Detection (weight 0.2)
        let loopScore = detectLongLoops(text: text)

        // Combine scores
        let totalScore = 0.5 * wordFrequencyScore + 0.3 * bigramScore + 0.2 * loopScore

        return min(1.0, max(0.0, totalScore))
    }

    /// Determine if text should be hidden based on repetition
    func shouldHideForRepetition(
        _ text: String,
        threshold: Double = 0.6,
        enabled: Bool = true
    ) -> (hide: Bool, score: Double) {
        guard enabled else { return (false, 0.0) }

        let score = repetitionScore(for: text)
        return (score >= threshold, score)
    }

    /// Combined filter result
    struct FilterResult: Codable, Content {
        let isBanned: Bool
        let isRepetitive: Bool
        let repetitionScore: Double
        let shouldHide: Bool
        let reason: String?

        init(
            isBanned: Bool,
            isRepetitive: Bool,
            repetitionScore: Double
        ) {
            self.isBanned = isBanned
            self.isRepetitive = isRepetitive
            self.repetitionScore = repetitionScore
            self.shouldHide = isBanned || isRepetitive

            if isBanned {
                self.reason = "Contains banned phrase"
            } else if isRepetitive {
                self.reason = "Excessive repetition (score: \(String(format: "%.2f", repetitionScore)))"
            } else {
                self.reason = nil
            }
        }
    }

    func filter(
        _ text: String,
        banEnabled: Bool,
        repetitionEnabled: Bool,
        repetitionThreshold: Double = 0.6
    ) -> FilterResult {
        let isBanned = self.isBanned(text, enabled: banEnabled)
        let (isRepetitive, score) = self.shouldHideForRepetition(text, threshold: repetitionThreshold, enabled: repetitionEnabled)

        return FilterResult(
            isBanned: isBanned,
            isRepetitive: isRepetitive,
            repetitionScore: score
        )
    }

    // MARK: - Private Scoring Components

    /// Word frequency analysis
    /// Returns: ratio of most frequent word / total unique words
    private func calculateWordFrequency(tokens: [String]) -> Double {
        guard !tokens.isEmpty else { return 0.0 }

        // Count word frequencies
        var frequency: [String: Int] = [:]
        for token in tokens {
            frequency[token, default: 0] += 1
        }

        guard let maxCount = frequency.values.max() else { return 0.0 }

        // Score: most frequent word ratio
        let maxShare = Double(maxCount) / Double(tokens.count)
        return min(1.0, maxShare * 1.5)  // Amplify for clarity
    }

    /// Bigram (consecutive token pairs) repetition
    private func calculateBigramRepetition(tokens: [String]) -> Double {
        guard tokens.count > 2 else { return 0.0 }

        // Create bigrams
        var bigrams: [String: Int] = [:]
        for i in 0..<(tokens.count - 1) {
            let bigram = tokens[i] + "-" + tokens[i + 1]
            bigrams[bigram, default: 0] += 1
        }

        guard !bigrams.isEmpty else { return 0.0 }

        // Calculate max bigram frequency
        if let maxBigramCount = bigrams.values.max() {
            let bigramShare = Double(maxBigramCount) / Double(tokens.count - 1)
            return min(1.0, bigramShare * 1.5)
        }

        return 0.0
    }

    /// Detect repeated substrings (long loops)
    /// Sampled scan for performance: checks every n characters
    private func detectLongLoops(text: String) -> Double {
        let minLoopLength = 3
        let maxLoopLength = min(12, text.count / 2)

        guard text.count > minLoopLength * 2 else { return 0.0 }

        var maxLoopCount = 0
        let step = max(1, text.count / 20)  // Sample every nth position

        var searchPosition = text.startIndex
        while searchPosition < text.endIndex {
            for loopLength in minLoopLength...maxLoopLength {
                let endPos = text.index(searchPosition, offsetBy: loopLength, limitedBy: text.endIndex) ?? text.endIndex
                guard endPos <= text.endIndex else { break }

                let substring = String(text[searchPosition..<endPos])

                // Count occurrences of this substring
                var count = 0
                var searchRange = text.startIndex..<text.endIndex
                while let range = text.range(of: substring, range: searchRange) {
                    count += 1
                    let nextStart = text.index(range.lowerBound, offsetBy: 1, limitedBy: text.endIndex) ?? text.endIndex
                    searchRange = nextStart..<text.endIndex
                    if nextStart >= text.endIndex { break }
                }

                if count > maxLoopCount {
                    maxLoopCount = count
                }
            }

            // Move to next sample position
            searchPosition = text.index(searchPosition, offsetBy: step, limitedBy: text.endIndex) ?? text.endIndex
        }

        // Score based on loop count
        let loopScore = Double(maxLoopCount) / 5.0  // 5+ loops = high score
        return min(1.0, max(0.0, loopScore))
    }

    // MARK: - Tokenization

    /// Tokenize text into words
    /// Minimum token length: 2 characters
    private func tokenize(_ text: String) -> [String] {
        let words = text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 }  // Min 3 chars

        return words
    }
}

// MARK: - Chat Message Model

struct ChatMessage: Codable, Identifiable, Content {
    let id: String
    let role: String  // "user" or "assistant"
    let text: String
    let timestamp: String
    let isHidden: Bool
    let repetitionScore: Double?

    init(
        role: String,
        text: String,
        isHidden: Bool = false,
        repetitionScore: Double? = nil
    ) {
        self.id = UUID().uuidString
        self.role = role
        self.text = text
        self.timestamp = ISO8601DateFormatter().string(from: Date())
        self.isHidden = isHidden
        self.repetitionScore = repetitionScore
    }
}

struct ChatSession: Codable, Identifiable {
    let id: String
    var messages: [ChatMessage]
    let createdAt: String
    let updatedAt: String

    init() {
        self.id = UUID().uuidString
        self.messages = []
        let now = ISO8601DateFormatter().string(from: Date())
        self.createdAt = now
        self.updatedAt = now
    }

    mutating func addMessage(_ message: ChatMessage) {
        self.messages.append(message)
    }
}
