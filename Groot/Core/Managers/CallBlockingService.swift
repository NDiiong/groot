//
//  CallBlockingService.swift
//  Groot
//
//  Created by Abdulbasit Ajaga on 31/01/2026.
//

import Foundation
import CallKit
import SwiftData
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Main service for managing call blocking functionality
/// Coordinates between SwiftData models and CallKit Call Directory Extension
@Observable
@MainActor
final class CallBlockingService {
    
    // MARK: - Properties
    
    private var modelContext: ModelContext?
    
    /// Current status of the Call Directory Extension
    var extensionStatus: ExtensionStatus = .unknown
    
    /// Whether the service is currently syncing
    var isSyncing: Bool = false
    
    /// Last error that occurred
    var lastError: Error?
    
    /// Statistics
    var blockedNumbersCount: Int = 0
    var whitelistCount: Int = 0
    var blockedCountriesCount: Int = 0
    var patternsCount: Int = 0
    
    // MARK: - Initialization
    
    init() {}
    
    /// Configure the service with a model context
    func configure(with modelContext: ModelContext) {
        self.modelContext = modelContext
        Task {
            await refreshStats()
            await checkExtensionStatus()
        }
    }
    
    // MARK: - Extension Status
    
    enum ExtensionStatus: Equatable {
        case unknown
        case enabled
        case disabled
        case error(String)
        
        var isEnabled: Bool {
            self == .enabled
        }
        
        var statusMessage: String {
            switch self {
            case .unknown: return "Checking status..."
            case .enabled: return "Call blocking is active"
            case .disabled: return "Call blocking is disabled"
            case .error(let message): return message
            }
        }
    }
    
    /// Check if the Call Directory Extension is enabled
    func checkExtensionStatus() async {
        do {
            let status = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CXCallDirectoryManager.EnabledStatus, Error>) in
                CXCallDirectoryManager.sharedInstance.getEnabledStatusForExtension(
                    withIdentifier: "com.reelsynth.Groot.CallDirectory"
                ) { status, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: status)
                    }
                }
            }
            
            switch status {
            case .enabled:
                extensionStatus = .enabled
            case .disabled:
                extensionStatus = .disabled
            case .unknown:
                extensionStatus = .unknown
            @unknown default:
                extensionStatus = .unknown
            }
        } catch {
            extensionStatus = .error(error.localizedDescription)
        }
    }
    
    /// Request the system to reload the Call Directory Extension
    func reloadCallDirectory() async throws {
        isSyncing = true
        defer { isSyncing = false }
        
        // Mark that data has changed
        AppGroupContainer.markNeedsReload()
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            CXCallDirectoryManager.sharedInstance.reloadExtension(
                withIdentifier: "com.reelsynth.Groot.CallDirectory"
            ) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
        
        await checkExtensionStatus()
    }
    
    /// Open iOS Settings to the Call Blocking & Identification page
    func openCallBlockingSettings() {
        if let url = URL(string: "App-prefs:Phone&path=Blocked") {
            UIApplication.shared.open(url)
        } else if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    // MARK: - Blocked Numbers
    
    /// Add a phone number to the block list
    func blockNumber(_ rawNumber: String, reason: BlockReason = .manual, label: String? = nil) throws {
        guard let context = modelContext else {
            throw CallBlockingServiceError.notConfigured
        }
        
        guard let e164 = PhoneNumberService.shared.parseToE164(rawNumber) else {
            throw CallBlockingServiceError.invalidPhoneNumber
        }
        
        // Check if already blocked - fetch all and filter
        let descriptor = FetchDescriptor<BlockedNumber>()
        let allBlocked = try context.fetch(descriptor)
        
        if let existing = allBlocked.first(where: { $0.phoneNumber == e164 }) {
            // Update existing entry
            existing.callCount += 1
            existing.lastCallAt = Date()
        } else {
            // Create new entry
            let blocked = BlockedNumber(
                phoneNumber: e164,
                rawNumber: rawNumber,
                reason: reason,
                label: label
            )
            context.insert(blocked)
        }
        
        try context.save()
        AppGroupContainer.markNeedsReload()
        
        Task {
            await refreshStats()
        }
    }
    
    /// Remove a phone number from the block list
    func unblockNumber(_ phoneNumber: String) throws {
        guard let context = modelContext else {
            throw CallBlockingServiceError.notConfigured
        }
        
        let e164 = phoneNumber.hasPrefix("+") ? phoneNumber : PhoneNumberService.shared.parseToE164(phoneNumber)
        guard let targetNumber = e164 else {
            throw CallBlockingServiceError.invalidPhoneNumber
        }
        
        let descriptor = FetchDescriptor<BlockedNumber>()
        let allBlocked = try context.fetch(descriptor)
        
        if let blocked = allBlocked.first(where: { $0.phoneNumber == targetNumber }) {
            context.delete(blocked)
            try context.save()
            AppGroupContainer.markNeedsReload()
        }
        
        Task {
            await refreshStats()
        }
    }
    
    /// Check if a number is blocked
    func isBlocked(_ phoneNumber: String) -> Bool {
        guard let context = modelContext,
              let e164 = PhoneNumberService.shared.parseToE164(phoneNumber) else {
            return false
        }
        
        let descriptor = FetchDescriptor<BlockedNumber>()
        guard let allBlocked = try? context.fetch(descriptor) else { return false }
        
        return allBlocked.contains { $0.phoneNumber == e164 }
    }
    
    // MARK: - Whitelist
    
    /// Add a contact to the whitelist
    func addToWhitelist(name: String, phoneNumber: String, contactIdentifier: String? = nil) throws {
        guard let context = modelContext else {
            throw CallBlockingServiceError.notConfigured
        }
        
        guard let e164 = PhoneNumberService.shared.parseToE164(phoneNumber) else {
            throw CallBlockingServiceError.invalidPhoneNumber
        }
        
        // Check if already whitelisted
        let whitelistDescriptor = FetchDescriptor<WhitelistContact>()
        let allWhitelisted = try context.fetch(whitelistDescriptor)
        
        guard !allWhitelisted.contains(where: { $0.phoneNumber == e164 }) else {
            throw CallBlockingServiceError.alreadyExists
        }
        
        let contact = WhitelistContact(
            phoneNumber: e164,
            name: name,
            contactIdentifier: contactIdentifier
        )
        context.insert(contact)
        
        // If this number was blocked, remove from block list
        let blockedDescriptor = FetchDescriptor<BlockedNumber>()
        let allBlocked = try context.fetch(blockedDescriptor)
        if let blocked = allBlocked.first(where: { $0.phoneNumber == e164 }) {
            context.delete(blocked)
        }
        
        try context.save()
        AppGroupContainer.markNeedsReload()
        
        Task {
            await refreshStats()
        }
    }
    
    /// Remove a contact from the whitelist
    func removeFromWhitelist(_ phoneNumber: String) throws {
        guard let context = modelContext else {
            throw CallBlockingServiceError.notConfigured
        }
        
        let e164 = phoneNumber.hasPrefix("+") ? phoneNumber : PhoneNumberService.shared.parseToE164(phoneNumber)
        guard let targetNumber = e164 else {
            throw CallBlockingServiceError.invalidPhoneNumber
        }
        
        let descriptor = FetchDescriptor<WhitelistContact>()
        let allContacts = try context.fetch(descriptor)
        
        if let contact = allContacts.first(where: { $0.phoneNumber == targetNumber }) {
            context.delete(contact)
            try context.save()
            AppGroupContainer.markNeedsReload()
        }
        
        Task {
            await refreshStats()
        }
    }
    
    /// Check if a number is whitelisted
    func isWhitelisted(_ phoneNumber: String) -> Bool {
        guard let context = modelContext,
              let e164 = PhoneNumberService.shared.parseToE164(phoneNumber) else {
            return false
        }
        
        let descriptor = FetchDescriptor<WhitelistContact>()
        guard let allContacts = try? context.fetch(descriptor) else { return false }
        
        return allContacts.contains { $0.phoneNumber == e164 }
    }
    
    // MARK: - Country Blocking
    
    /// Block all calls from a country
    func blockCountry(_ country: Country) throws {
        guard let context = modelContext else {
            throw CallBlockingServiceError.notConfigured
        }
        
        // Check if already blocked
        let descriptor = FetchDescriptor<BlockedCountry>()
        let allCountries = try context.fetch(descriptor)
        
        guard !allCountries.contains(where: { $0.countryCode == country.callingCode }) else {
            throw CallBlockingServiceError.alreadyExists
        }
        
        let blockedCountry = BlockedCountry(
            countryCode: country.callingCode,
            countryName: country.name,
            isoCode: country.isoCode
        )
        context.insert(blockedCountry)
        try context.save()
        AppGroupContainer.markNeedsReload()
        
        Task {
            await refreshStats()
        }
    }
    
    /// Unblock a country
    func unblockCountry(_ countryCode: String) throws {
        guard let context = modelContext else {
            throw CallBlockingServiceError.notConfigured
        }
        
        let descriptor = FetchDescriptor<BlockedCountry>()
        let allCountries = try context.fetch(descriptor)
        
        if let blocked = allCountries.first(where: { $0.countryCode == countryCode }) {
            context.delete(blocked)
            try context.save()
            AppGroupContainer.markNeedsReload()
        }
        
        Task {
            await refreshStats()
        }
    }
    
    /// Check if a country is blocked
    func isCountryBlocked(_ countryCode: String) -> Bool {
        guard let context = modelContext else { return false }
        
        let descriptor = FetchDescriptor<BlockedCountry>()
        guard let allCountries = try? context.fetch(descriptor) else { return false }
        
        return allCountries.contains { $0.countryCode == countryCode }
    }
    
    // MARK: - Patterns
    
    func addPattern(_ pattern: String, description: String, blocksCalls: Bool = false) throws {
        guard let context = modelContext else {
            throw CallBlockingServiceError.notConfigured
        }
        
        if BlockPattern.wildcardCount(in: pattern) > BlockPattern.maxWildcards {
            throw CallBlockingServiceError.patternTooBroad
        }
        guard let normalized = BlockPattern.normalize(pattern) else {
            throw CallBlockingServiceError.invalidPattern
        }
        let storedPattern = "+" + normalized
        
        let descriptor = FetchDescriptor<BlockPattern>()
        let allPatterns = try context.fetch(descriptor)
        
        guard !allPatterns.contains(where: { $0.pattern == storedPattern }) else {
            throw CallBlockingServiceError.alreadyExists
        }
        
        let enabledTotal = allPatterns.filter { $0.isEnabled }.reduce(Int64(0)) { $0 + $1.expandedCount }
        guard enabledTotal + BlockPattern.expandedCount(of: normalized) <= BlockPattern.maxTotalNumbers else {
            throw CallBlockingServiceError.patternCapacityExceeded
        }
        
        let blockPattern = BlockPattern(
            pattern: storedPattern,
            description: description,
            blocksCalls: blocksCalls
        )
        context.insert(blockPattern)
        try context.save()
        AppGroupContainer.markNeedsReload()
        
        Task {
            await refreshStats()
        }
    }
    
    /// Remove a pattern
    func removePattern(_ pattern: String) throws {
        guard let context = modelContext else {
            throw CallBlockingServiceError.notConfigured
        }
        
        let descriptor = FetchDescriptor<BlockPattern>()
        let allPatterns = try context.fetch(descriptor)
        
        if let blocked = allPatterns.first(where: { $0.pattern == pattern }) {
            context.delete(blocked)
            try context.save()
            AppGroupContainer.markNeedsReload()
        }
        
        Task {
            await refreshStats()
        }
    }
    
    /// Toggle a pattern's enabled state
    func togglePattern(_ pattern: String) throws {
        guard let context = modelContext else {
            throw CallBlockingServiceError.notConfigured
        }
        
        let descriptor = FetchDescriptor<BlockPattern>()
        let allPatterns = try context.fetch(descriptor)
        
        if let blockPattern = allPatterns.first(where: { $0.pattern == pattern }) {
            if !blockPattern.isEnabled {
                let enabledTotal = allPatterns.filter { $0.isEnabled }.reduce(Int64(0)) { $0 + $1.expandedCount }
                guard enabledTotal + blockPattern.expandedCount <= BlockPattern.maxTotalNumbers else {
                    throw CallBlockingServiceError.patternCapacityExceeded
                }
            }
            blockPattern.isEnabled.toggle()
            try context.save()
            AppGroupContainer.markNeedsReload()
        }
    }
    
    // MARK: - Stats
    
    /// Refresh statistics
    func refreshStats() async {
        guard let context = modelContext else { return }
        
        do {
            blockedNumbersCount = try context.fetchCount(FetchDescriptor<BlockedNumber>())
            whitelistCount = try context.fetchCount(FetchDescriptor<WhitelistContact>())
            blockedCountriesCount = try context.fetchCount(FetchDescriptor<BlockedCountry>())
            patternsCount = try context.fetchCount(FetchDescriptor<BlockPattern>())
        } catch {
            print("Failed to refresh stats: \(error)")
        }
    }
}

// MARK: - Errors

enum CallBlockingServiceError: LocalizedError {
    case notConfigured
    case invalidPhoneNumber
    case invalidPattern
    case patternTooBroad
    case patternCapacityExceeded
    case alreadyExists
    case notFound
    case extensionDisabled
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Call blocking service is not configured."
        case .invalidPhoneNumber:
            return "Invalid phone number format."
        case .invalidPattern:
            return "Invalid pattern. Use digits and # (one # per unknown digit), 7-15 digits total, e.g. +37529123####."
        case .patternTooBroad:
            return "Too many # in one pattern. Maximum is \(BlockPattern.maxWildcards)."
        case .patternCapacityExceeded:
            return "Active patterns would exceed \(BlockPattern.maxTotalNumbers.formatted()) numbers. Disable or remove a pattern first."
        case .alreadyExists:
            return "This entry already exists."
        case .notFound:
            return "Entry not found."
        case .extensionDisabled:
            return "Call blocking extension is disabled. Enable it in Settings > Phone > Call Blocking & Identification."
        }
    }
}

// MARK: - Environment Key

struct CallBlockingServiceKey: EnvironmentKey {
    static let defaultValue = CallBlockingService()
}

extension EnvironmentValues {
    var callBlockingService: CallBlockingService {
        get { self[CallBlockingServiceKey.self] }
        set { self[CallBlockingServiceKey.self] = newValue }
    }
}
