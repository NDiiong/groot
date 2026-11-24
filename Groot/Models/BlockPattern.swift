//
//  BlockPattern.swift
//  Groot
//
//  Created by Abdulbasit Ajaga on 31/01/2026.
//

import Foundation
import SwiftData

/// Represents a pattern for blocking phone numbers
/// Patterns use wildcards to match multiple numbers
@Model
final class BlockPattern {
    @Attribute(.unique) var pattern: String
    
    /// Human-readable description of what this pattern blocks
    var patternDescription: String
    
    /// When this pattern was created
    var createdAt: Date
    
    /// Number of calls this pattern has matched and blocked
    var matchCount: Int
    
    /// Whether this pattern is currently active
    var isEnabled: Bool
    var blocksCalls: Bool = false
    
    init(
        pattern: String,
        description: String,
        createdAt: Date = Date(),
        matchCount: Int = 0,
        isEnabled: Bool = true,
        blocksCalls: Bool = false
    ) {
        self.pattern = pattern
        self.patternDescription = description
        self.createdAt = createdAt
        self.matchCount = matchCount
        self.isEnabled = isEnabled
        self.blocksCalls = blocksCalls
    }
    
    /// Record that this pattern matched a call
    func recordMatch() {
        matchCount += 1
    }
}

// MARK: - Pattern Matching

extension BlockPattern {
    static let maxWildcards = 6
    static let maxTotalNumbers: Int64 = 2_000_000

    static func normalize(_ raw: String) -> String? {
        let allowed: Set<Character> = ["+", " ", "-", "(", ")", "#"]
        guard raw.allSatisfy({ ($0.isASCII && $0.isNumber) || allowed.contains($0) }) else { return nil }
        let cleaned = raw.filter { ($0.isASCII && $0.isNumber) || $0 == "#" }
        guard let first = cleaned.first, first != "#", (7...15).contains(cleaned.count) else { return nil }
        let wildcards = cleaned.filter { $0 == "#" }.count
        guard (1...maxWildcards).contains(wildcards) else { return nil }
        return cleaned
    }

    static func wildcardCount(in raw: String) -> Int {
        raw.filter { $0 == "#" }.count
    }

    static func expandedCount(of raw: String) -> Int64 {
        var total: Int64 = 1
        for _ in 0..<wildcardCount(in: raw) {
            total *= 10
        }
        return total
    }

    var expandedCount: Int64 {
        BlockPattern.expandedCount(of: pattern)
    }

    func matches(_ phoneNumber: String) -> Bool {
        guard isEnabled else { return false }
        let number = phoneNumber.filter { $0.isASCII && $0.isNumber }
        let template = pattern.filter { ($0.isASCII && $0.isNumber) || $0 == "#" }
        guard number.count == template.count else { return false }
        return zip(number, template).allSatisfy { $1 == "#" || $0 == $1 }
    }
}

// MARK: - Predefined Patterns

extension BlockPattern {
    /// Common patterns that users might want to use
    static let commonPatterns: [(pattern: String, description: String)] = []
}
