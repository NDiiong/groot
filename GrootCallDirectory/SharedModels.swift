//
//  SharedModels.swift
//  GrootCallDirectory
//
//  Shared models and utilities for the Call Directory Extension
//  This file duplicates the models from the main app for extension compilation
//  IMPORTANT: Schema must match the main app exactly to avoid migration issues
//

import Foundation
import SwiftData

// MARK: - App Group Container

/// Provides access to the shared App Group container
enum AppGroupContainer {
    static let identifier = "group.com.reelsynth.Groot"
    
    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }
    
    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: identifier)
    }
    
    static var storeURL: URL? {
        containerURL?.appendingPathComponent("Groot.store")
    }
    
    enum DefaultsKey {
        static let lastSyncDate = "lastCallDirectorySyncDate"
        static let needsReload = "callDirectoryNeedsReload"
    }
    
    static func updateLastSyncDate() {
        sharedDefaults?.set(Date(), forKey: DefaultsKey.lastSyncDate)
    }
    
    static func clearNeedsReload() {
        sharedDefaults?.set(false, forKey: DefaultsKey.needsReload)
    }
}

// MARK: - App Settings Model (must match main app schema)

@Model
final class AppSettings {
    var hasCompletedOnboarding: Bool
    var onboardingCompletedAt: Date?
    var hasCompletedPermissions: Bool
    var permissionsCompletedAt: Date?
    var blockUnknownCallers: Bool
    var silentMode: Bool
    var hapticsEnabled: Bool
    var notificationsEnabled: Bool
    var totalBlockedCalls: Int
    var appLaunchCount: Int
    var firstLaunchDate: Date
    
    init(
        hasCompletedOnboarding: Bool = false,
        onboardingCompletedAt: Date? = nil,
        hasCompletedPermissions: Bool = false,
        permissionsCompletedAt: Date? = nil,
        blockUnknownCallers: Bool = true,
        silentMode: Bool = false,
        hapticsEnabled: Bool = true,
        notificationsEnabled: Bool = true,
        totalBlockedCalls: Int = 0,
        appLaunchCount: Int = 0,
        firstLaunchDate: Date = Date()
    ) {
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.onboardingCompletedAt = onboardingCompletedAt
        self.hasCompletedPermissions = hasCompletedPermissions
        self.permissionsCompletedAt = permissionsCompletedAt
        self.blockUnknownCallers = blockUnknownCallers
        self.silentMode = silentMode
        self.hapticsEnabled = hapticsEnabled
        self.notificationsEnabled = notificationsEnabled
        self.totalBlockedCalls = totalBlockedCalls
        self.appLaunchCount = appLaunchCount
        self.firstLaunchDate = firstLaunchDate
    }
}

// MARK: - Blocked Number Model

@Model
final class BlockedNumber {
    @Attribute(.unique) var phoneNumber: String
    var rawNumber: String
    var reasonRawValue: String
    var label: String?
    var blockedAt: Date
    var callCount: Int
    var lastCallAt: Date?
    
    var reason: BlockReason {
        get { BlockReason(rawValue: reasonRawValue) ?? .manual }
        set { reasonRawValue = newValue.rawValue }
    }
    
    init(
        phoneNumber: String,
        rawNumber: String? = nil,
        reason: BlockReason = .manual,
        label: String? = nil,
        blockedAt: Date = Date(),
        callCount: Int = 0,
        lastCallAt: Date? = nil
    ) {
        self.phoneNumber = phoneNumber
        self.rawNumber = rawNumber ?? phoneNumber
        self.reasonRawValue = reason.rawValue
        self.label = label
        self.blockedAt = blockedAt
        self.callCount = callCount
        self.lastCallAt = lastCallAt
    }
    
    var numericPhoneNumber: Int64? {
        let digitsOnly = phoneNumber.replacingOccurrences(of: "+", with: "")
            .filter { $0.isNumber }
        return Int64(digitsOnly)
    }
}

enum BlockReason: String, Codable, CaseIterable {
    case manual
    case pattern
    case country
    case spam
    
    var displayName: String {
        switch self {
        case .manual: return "Manually blocked"
        case .pattern: return "Pattern match"
        case .country: return "Country blocked"
        case .spam: return "Spam detected"
        }
    }
}

// MARK: - Whitelist Contact Model

@Model
final class WhitelistContact {
    @Attribute(.unique) var phoneNumber: String
    var name: String
    var contactIdentifier: String?
    var addedAt: Date
    var callsAllowed: Int
    var thumbnailData: Data?
    
    init(
        phoneNumber: String,
        name: String,
        contactIdentifier: String? = nil,
        addedAt: Date = Date(),
        callsAllowed: Int = 0,
        thumbnailData: Data? = nil
    ) {
        self.phoneNumber = phoneNumber
        self.name = name
        self.contactIdentifier = contactIdentifier
        self.addedAt = addedAt
        self.callsAllowed = callsAllowed
        self.thumbnailData = thumbnailData
    }
    
    var numericPhoneNumber: Int64? {
        let digitsOnly = phoneNumber.replacingOccurrences(of: "+", with: "")
            .filter { $0.isNumber }
        return Int64(digitsOnly)
    }
}

// MARK: - Blocked Country Model

@Model
final class BlockedCountry {
    @Attribute(.unique) var countryCode: String
    var countryName: String
    var isoCode: String
    var blockedAt: Date
    var callsBlocked: Int
    
    init(
        countryCode: String,
        countryName: String,
        isoCode: String,
        blockedAt: Date = Date(),
        callsBlocked: Int = 0
    ) {
        self.countryCode = countryCode
        self.countryName = countryName
        self.isoCode = isoCode
        self.blockedAt = blockedAt
        self.callsBlocked = callsBlocked
    }
    
    var numericPrefix: Int64? {
        let digitsOnly = countryCode.replacingOccurrences(of: "+", with: "")
            .filter { $0.isNumber }
        return Int64(digitsOnly)
    }
}

// MARK: - Block Pattern Model

@Model
final class BlockPattern {
    @Attribute(.unique) var pattern: String
    var patternDescription: String
    var createdAt: Date
    var matchCount: Int
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
}

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
