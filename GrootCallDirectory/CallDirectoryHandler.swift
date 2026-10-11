//
//  CallDirectoryHandler.swift
//  GrootCallDirectory
//
//  Created by Abdulbasit Ajaga on 31/01/2026.
//

import Foundation
import CallKit
import SwiftData

/// Call Directory Extension handler that provides blocking and identification
/// data to iOS's call blocking system
class CallDirectoryHandler: CXCallDirectoryProvider {
    
    // MARK: - Properties
    
    private var modelContainer: ModelContainer?
    private var modelContext: ModelContext?
    
    // MARK: - CXCallDirectoryProvider
    
    override func beginRequest(with context: CXCallDirectoryExtensionContext) {
        context.delegate = self
        
        // Initialize the model container for reading blocking data
        do {
            modelContainer = try createModelContainer()
            modelContext = ModelContext(modelContainer!)
            
            // Check if this is an incremental update request
            if context.isIncremental {
                addOrRemoveIncrementalBlockingPhoneNumbers(to: context)
                addOrRemoveIncrementalIdentificationPhoneNumbers(to: context)
            } else {
                addAllBlockingPhoneNumbers(to: context)
                addAllIdentificationPhoneNumbers(to: context)
            }
            
            // Update sync timestamp
            AppGroupContainer.updateLastSyncDate()
            AppGroupContainer.clearNeedsReload()
        } catch {
            // Log the error but don't fail - just complete with no entries
            // This happens when:
            // - The main app hasn't created the store yet
            // - There's a schema mismatch (user needs to delete and reinstall app)
            // - The store is corrupted
            print("GrootCallDirectory: Failed to create model container: \(error)")
            print("GrootCallDirectory: Extension will complete with no blocking entries")
        }
        
        // Always complete successfully - never cancel the request
        context.completeRequest()
    }
    
    // MARK: - Model Container Setup
    
    private func createModelContainer() throws -> ModelContainer {
        // Schema must match the main app EXACTLY to avoid migration
        let schema = Schema([
            AppSettings.self,
            BlockedNumber.self,
            WhitelistContact.self,
            BlockedCountry.self,
            BlockPattern.self
        ])
        
        // Try to use the shared App Group container
        guard let storeURL = AppGroupContainer.storeURL else {
            throw CallDirectoryError.containerNotAvailable
        }
        
        // Check if the store file exists - if not, the main app hasn't created it yet
        guard FileManager.default.fileExists(atPath: storeURL.path) else {
            throw CallDirectoryError.storeNotCreated
        }
        
        // Create a read-only configuration that won't attempt migration
        let configuration = ModelConfiguration(
            schema: schema,
            url: storeURL,
            allowsSave: false
        )
        
        return try ModelContainer(for: schema, configurations: [configuration])
    }
    
    // MARK: - Blocking Phone Numbers
    
    private func addAllBlockingPhoneNumbers(to context: CXCallDirectoryExtensionContext) {
        guard modelContext != nil else { return }
        let whitelisted = fetchWhitelistedPhoneNumbers()
        let explicit = fetchAllBlockedNumbers().compactMap { blocked -> PhoneEntry? in
            guard let numeric = blocked.numericPhoneNumber else { return nil }
            return PhoneEntry(number: numeric, label: "")
        }
        let patterns = cappedPatterns(fetchActivePatterns()).filter { $0.blocksCalls }
        var merged = SortedPhoneEntryMerge(sources: [explicitSource(explicit)] + patterns.compactMap { patternSource($0) })
        while let entry = merged.next() {
            if whitelisted.contains(entry.number) { continue }
            context.addBlockingEntry(withNextSequentialPhoneNumber: entry.number)
        }
    }
    
    /// Add or remove blocking phone numbers incrementally
    private func addOrRemoveIncrementalBlockingPhoneNumbers(to context: CXCallDirectoryExtensionContext) {
        // For incremental updates, we would track changes since last sync
        // For now, fall back to full reload
        // TODO: Implement incremental updates by tracking changes in UserDefaults
        addAllBlockingPhoneNumbers(to: context)
    }
    
    // MARK: - Identification Phone Numbers
    
    private func addAllIdentificationPhoneNumbers(to context: CXCallDirectoryExtensionContext) {
        guard modelContext != nil else { return }
        let whitelisted = fetchWhitelistedPhoneNumbers()
        let explicit = fetchAllBlockedNumbers().compactMap { blocked -> PhoneEntry? in
            guard let numeric = blocked.numericPhoneNumber else { return nil }
            return PhoneEntry(number: numeric, label: blocked.label ?? blocked.reason.displayName)
        }
        let patterns = cappedPatterns(fetchActivePatterns()).filter { !$0.blocksCalls }
        var merged = SortedPhoneEntryMerge(sources: [explicitSource(explicit)] + patterns.compactMap { patternSource($0) })
        while let entry = merged.next() {
            if whitelisted.contains(entry.number) { continue }
            context.addIdentificationEntry(withNextSequentialPhoneNumber: entry.number, label: entry.label)
        }
    }
    
    private func cappedPatterns(_ patterns: [BlockPattern]) -> [BlockPattern] {
        var total: Int64 = 0
        var result: [BlockPattern] = []
        for pattern in patterns.sorted(by: { $0.createdAt < $1.createdAt }) {
            guard BlockPattern.normalize(pattern.pattern) != nil else { continue }
            let count = pattern.expandedCount
            if total + count > BlockPattern.maxTotalNumbers { continue }
            total += count
            result.append(pattern)
        }
        return result
    }
    
    private func explicitSource(_ entries: [PhoneEntry]) -> () -> PhoneEntry? {
        let sorted = entries.sorted { $0.number < $1.number }
        var index = 0
        return {
            guard index < sorted.count else { return nil }
            defer { index += 1 }
            return sorted[index]
        }
    }
    
    private func patternSource(_ pattern: BlockPattern) -> (() -> PhoneEntry?)? {
        guard let normalized = BlockPattern.normalize(pattern.pattern),
              var sequence = PatternNumberSequence(template: normalized) else { return nil }
        let label = pattern.patternDescription.isEmpty ? BlockReason.pattern.displayName : pattern.patternDescription
        return {
            guard let number = sequence.next() else { return nil }
            return PhoneEntry(number: number, label: label)
        }
    }
    
    /// Add or remove identification phone numbers incrementally
    private func addOrRemoveIncrementalIdentificationPhoneNumbers(to context: CXCallDirectoryExtensionContext) {
        // Fall back to full reload for now
        addAllIdentificationPhoneNumbers(to: context)
    }
    
    // MARK: - Data Fetching
    
    private func fetchAllBlockedNumbers() -> [BlockedNumber] {
        guard let modelContext = modelContext else { return [] }
        
        let descriptor = FetchDescriptor<BlockedNumber>(
            sortBy: [SortDescriptor(\.phoneNumber)]
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch blocked numbers: \(error)")
            return []
        }
    }
    
    private func fetchWhitelistedPhoneNumbers() -> Set<Int64> {
        guard let modelContext = modelContext else { return [] }
        
        let descriptor = FetchDescriptor<WhitelistContact>()
        
        do {
            let contacts = try modelContext.fetch(descriptor)
            return Set(contacts.compactMap { $0.numericPhoneNumber })
        } catch {
            print("Failed to fetch whitelisted contacts: \(error)")
            return []
        }
    }
    
    private func fetchBlockedCountries() -> [BlockedCountry] {
        guard let modelContext = modelContext else { return [] }
        
        let descriptor = FetchDescriptor<BlockedCountry>()
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch blocked countries: \(error)")
            return []
        }
    }
    
    private func fetchActivePatterns() -> [BlockPattern] {
        guard let modelContext = modelContext else { return [] }
        
        let descriptor = FetchDescriptor<BlockPattern>(
            predicate: #Predicate { $0.isEnabled }
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch patterns: \(error)")
            return []
        }
    }
}

// MARK: - Pattern Expansion

struct PhoneEntry {
    let number: Int64
    let label: String
}

struct PatternNumberSequence {
    private let base: Int64
    private let weights: [Int64]
    private let total: Int64
    private var counter: Int64 = 0
    
    init?(template: String) {
        var base: Int64 = 0
        var weights: [Int64] = []
        var place: Int64 = 1
        for character in template.reversed() {
            if character == "#" {
                weights.append(place)
            } else if let digit = character.wholeNumberValue {
                base += Int64(digit) * place
            } else {
                return nil
            }
            place *= 10
        }
        guard !weights.isEmpty else { return nil }
        var total: Int64 = 1
        for _ in weights { total *= 10 }
        self.base = base
        self.weights = weights
        self.total = total
    }
    
    mutating func next() -> Int64? {
        guard counter < total else { return nil }
        var remaining = counter
        var value = base
        for weight in weights {
            value += (remaining % 10) * weight
            remaining /= 10
        }
        counter += 1
        return value
    }
}

struct SortedPhoneEntryMerge {
    private let sources: [() -> PhoneEntry?]
    private var heads: [PhoneEntry?]
    private var lastNumber: Int64?
    
    init(sources: [() -> PhoneEntry?]) {
        self.sources = sources
        self.heads = sources.map { $0() }
    }
    
    mutating func next() -> PhoneEntry? {
        while true {
            var selected: Int?
            for index in heads.indices {
                guard let head = heads[index] else { continue }
                if let current = selected, let currentHead = heads[current], currentHead.number <= head.number { continue }
                selected = index
            }
            guard let index = selected, let entry = heads[index] else { return nil }
            heads[index] = sources[index]()
            if entry.number == lastNumber { continue }
            lastNumber = entry.number
            return entry
        }
    }
}

// MARK: - CXCallDirectoryExtensionContextDelegate

extension CallDirectoryHandler: CXCallDirectoryExtensionContextDelegate {
    func requestFailed(for extensionContext: CXCallDirectoryExtensionContext, withError error: Error) {
        // Log the error for debugging
        print("Call Directory request failed: \(error.localizedDescription)")
        
        // An error occurred while adding blocking or identification entries
        // This could be due to:
        // - Entries added out of order
        // - Duplicate entries
        // - Memory limit exceeded
    }
}

// MARK: - Errors

enum CallDirectoryError: LocalizedError {
    case dataLoadFailed
    case containerNotAvailable
    case storeNotCreated
    case invalidPhoneNumber
    
    var errorDescription: String? {
        switch self {
        case .dataLoadFailed:
            return "Failed to load blocking data."
        case .containerNotAvailable:
            return "Shared container is not available."
        case .storeNotCreated:
            return "Data store has not been created by the main app yet."
        case .invalidPhoneNumber:
            return "Invalid phone number format."
        }
    }
}
