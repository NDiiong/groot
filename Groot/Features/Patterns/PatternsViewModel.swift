//
//  PatternsViewModel.swift
//  Groot
//
//  Created by Abdulbasit Ajaga on 31/01/2026.
//

import SwiftUI
import SwiftData
import Observation

// MARK: - Patterns ViewModel

@MainActor
@Observable
final class PatternsViewModel {
    
    // MARK: - Dependencies
    
    private let callBlockingService: CallBlockingService
    
    // MARK: - UI State
    
    var showAddSheet = false
    var showToast = false
    var toastMessage = ""
    var searchText = ""
    var hideSuggestedPatterns: Bool {
        get { UserDefaults.standard.bool(forKey: "hideSuggestedPatterns") }
        set { UserDefaults.standard.set(newValue, forKey: "hideSuggestedPatterns") }
    }
    
    // MARK: - Initialization
    
    init(callBlockingService: CallBlockingService) {
        self.callBlockingService = callBlockingService
    }
    
    // MARK: - Computed Properties
    
    func filteredPatterns(from patterns: [BlockPattern]) -> [BlockPattern] {
        if searchText.isEmpty {
            return patterns
        }
        return patterns.filter {
            $0.pattern.localizedCaseInsensitiveContains(searchText) ||
            $0.patternDescription.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    func enabledCount(from patterns: [BlockPattern]) -> Int {
        patterns.filter { $0.isEnabled }.count
    }
    
    func totalMatches(from patterns: [BlockPattern]) -> Int {
        patterns.reduce(0) { $0 + $1.matchCount }
    }
    
    func availableSuggestions(from patterns: [BlockPattern]) -> [(pattern: String, description: String)] {
        BlockPattern.commonPatterns.filter { suggestion in
            !patterns.contains { $0.pattern == suggestion.pattern }
        }
    }
    
    func isPatternAdded(_ pattern: String, in patterns: [BlockPattern]) -> Bool {
        patterns.contains { $0.pattern == pattern }
    }
    
    // MARK: - Actions
    
    func openAddSheet() {
        showAddSheet = true
    }
    
    func toggleSuggestedPatterns() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            hideSuggestedPatterns.toggle()
        }
        GrootHaptics.selection()
    }
    
    func showSuggestions() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            hideSuggestedPatterns = false
        }
        GrootHaptics.selection()
    }
    
    func hideSuggestions() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            hideSuggestedPatterns = true
        }
        GrootHaptics.selection()
    }
    
    func togglePattern(_ pattern: BlockPattern) {
        do {
            try callBlockingService.togglePattern(pattern.pattern)
            GrootHaptics.selection()
            
            Task {
                try? await callBlockingService.reloadCallDirectory()
            }
        } catch {
            toastMessage = error.localizedDescription
            showToast = true
            GrootHaptics.error()
        }
    }
    
    func deletePattern(_ pattern: BlockPattern) {
        do {
            try callBlockingService.removePattern(pattern.pattern)
            toastMessage = "Pattern removed"
            showToast = true
            GrootHaptics.success()
            
            Task {
                try? await callBlockingService.reloadCallDirectory()
            }
        } catch {
            toastMessage = "Failed to remove pattern"
            showToast = true
            GrootHaptics.error()
        }
    }
    
    func addSuggestedPattern(_ suggestion: (pattern: String, description: String)) {
        do {
            try callBlockingService.addPattern(suggestion.pattern, description: suggestion.description)
            toastMessage = "Pattern added!"
            showToast = true
            GrootHaptics.success()
            
            Task {
                try? await callBlockingService.reloadCallDirectory()
            }
        } catch {
            toastMessage = "Failed to add pattern"
            showToast = true
            GrootHaptics.error()
        }
    }
}
