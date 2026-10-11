//
//  PatternsView.swift
//  Groot
//
//  Created by Abdulbasit Ajaga on 31/01/2026.
//

import SwiftUI
import SwiftData

// MARK: - Patterns View

struct PatternsView: View {
    
    // MARK: - Environment
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.callBlockingService) private var callBlockingService
    
    // MARK: - Data
    
    @Query(sort: \BlockPattern.createdAt, order: .reverse)
    private var patterns: [BlockPattern]
    
    // MARK: - ViewModel
    
    @State private var viewModel: PatternsViewModel?
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    if !patterns.isEmpty {
                        statsSection
                        searchSection
                    }
                    
                    if patterns.isEmpty {
                        GrootEmptyState.noPatterns {
                            viewModel?.openAddSheet()
                        }
                        .grootAppear(delay: 0)
                    } else if filteredPatterns.isEmpty {
                        GrootEmptyState.searchNoResults(query: viewModel?.searchText ?? "")
                            .grootAppear(delay: 0)
                    } else {
                        patternsListSection
                    }
                    
                    if !availableSuggestions.isEmpty {
                        suggestedPatternsSection
                    }
                    
                    infoCallout
                }
                .padding(20)
            }
            .background(Color.grootCloud)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    GrootBackButton {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Text("pattern blocking")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.grootBark)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    GrootIconButton("plus", variant: .primary, size: .small) {
                        viewModel?.openAddSheet()
                    }
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { viewModel?.showAddSheet ?? false },
            set: { viewModel?.showAddSheet = $0 }
        )) {
            AddPatternSheet()
                .presentationDetents([.medium, .large])
        }
        .grootToast(
            isPresented: Binding(
                get: { viewModel?.showToast ?? false },
                set: { viewModel?.showToast = $0 }
            ),
            message: viewModel?.toastMessage ?? ""
        )
        .onAppear {
            if viewModel == nil {
                viewModel = PatternsViewModel(callBlockingService: callBlockingService)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredPatterns: [BlockPattern] {
        viewModel?.filteredPatterns(from: patterns) ?? patterns
    }
    
    private var availableSuggestions: [(pattern: String, description: String)] {
        viewModel?.availableSuggestions(from: patterns) ?? []
    }
    
    // MARK: - View Components
    
    private var statsSection: some View {
        HStack(spacing: 12) {
            PatternStatCard(
                icon: "number",
                value: "\(patterns.count)",
                label: "patterns",
                color: .grootViolet
            )
            
            PatternStatCard(
                icon: "checkmark.circle.fill",
                value: "\(viewModel?.enabledCount(from: patterns) ?? 0)",
                label: "active",
                color: .grootShield
            )
            
            PatternStatCard(
                icon: "phone.down.fill",
                value: "\(viewModel?.totalMatches(from: patterns) ?? 0)",
                label: "blocked",
                color: .grootFlame
            )
        }
        .grootAppear(delay: 0)
    }
    
    private var searchSection: some View {
        GrootSearchField(
            "search patterns",
            text: Binding(
                get: { viewModel?.searchText ?? "" },
                set: { viewModel?.searchText = $0 }
            )
        )
        .grootAppear(delay: 0.1)
    }
    
    private var patternsListSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                GrootText("your patterns", style: .heading)
                Spacer()
                Text("\(filteredPatterns.count) pattern\(filteredPatterns.count == 1 ? "" : "s")")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.grootStone)
            }
            .grootAppear(delay: 0.1)
            
            VStack(spacing: 0) {
                ForEach(filteredPatterns) { pattern in
                    PatternRow(
                        pattern: pattern,
                        onToggle: { viewModel?.togglePattern(pattern) },
                        onDelete: { viewModel?.deletePattern(pattern) }
                    )
                    
                    if pattern.id != filteredPatterns.last?.id {
                        Divider().padding(.leading, 70)
                    }
                }
            }
            .background(Color.grootSnow)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .grootAppear(delay: 0.2)
        }
    }
    
    private var suggestedPatternsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            GrootText("suggested patterns", style: .heading)
                .grootAppear(delay: 0.3)
            
            VStack(spacing: 0) {
                let suggestions = availableSuggestions
                ForEach(suggestions.indices, id: \.self) { index in
                    let suggestion = suggestions[index]
                    SuggestedPatternRow(
                        pattern: suggestion.pattern,
                        description: suggestion.description,
                        isAdded: viewModel?.isPatternAdded(suggestion.pattern, in: patterns) ?? false,
                        onAdd: { viewModel?.addSuggestedPattern(suggestion) }
                    )
                    
                    if index < suggestions.count - 1 {
                        Divider().padding(.leading, 70)
                    }
                }
            }
            .background(Color.grootSnow)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .grootAppear(delay: 0.4)
        }
    }
    
    private var infoCallout: some View {
        GrootCallout(
            title: "how patterns work",
            message: "Use # for each unknown digit. For example, +37529123#### matches 10,000 numbers. Maximum 6 # per pattern and 2,000,000 numbers across active patterns.",
            icon: "lightbulb.fill",
            color: .grootSun
        )
        .grootAppear(delay: 0.5)
    }
}

// MARK: - Pattern Stat Card

struct PatternStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(color)
            }
            
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Color.grootBark)
            
            Text(label.lowercased())
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color.grootStone)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.grootSnow)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Suggested Pattern Row

struct SuggestedPatternRow: View {
    let pattern: String
    let description: String
    let isAdded: Bool
    let onAdd: () -> Void
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.grootSky.opacity(0.15))
                    .frame(width: 48, height: 48)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.grootSky)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(pattern)
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.grootBark)
                
                Text(description.lowercased())
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.grootStone)
            }
            
            Spacer()
            
            if isAdded {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(Color.grootShield)
            } else {
                Button(action: onAdd) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(Color.grootSky)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Patterns Tab View (For Main Tab Bar)

struct PatternsTabView: View {
    
    // MARK: - Environment
    
    @Environment(\.callBlockingService) private var callBlockingService
    
    // MARK: - Data
    
    @Query(sort: \BlockPattern.createdAt, order: .reverse)
    private var patterns: [BlockPattern]
    
    // MARK: - ViewModel
    
    @State private var viewModel: PatternsViewModel?
    
    // MARK: - Computed Properties
    
    private var filteredPatterns: [BlockPattern] {
        viewModel?.filteredPatterns(from: patterns) ?? patterns
    }
    
    private var availableSuggestions: [(pattern: String, description: String)] {
        viewModel?.availableSuggestions(from: patterns) ?? []
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    if !patterns.isEmpty {
                        statsSection
                        searchSection
                    }
                    
                    if patterns.isEmpty {
                        GrootEmptyState.noPatterns {
                            viewModel?.openAddSheet()
                        }
                        .grootAppear(delay: 0)
                    } else if filteredPatterns.isEmpty {
                        GrootEmptyState.searchNoResults(query: viewModel?.searchText ?? "")
                            .grootAppear(delay: 0)
                    } else {
                        patternsListSection
                    }
                    
                    if viewModel?.hideSuggestedPatterns != true && !availableSuggestions.isEmpty {
                        suggestedPatternsSection
                    }
                    
                    if viewModel?.hideSuggestedPatterns == true && !availableSuggestions.isEmpty {
                        showSuggestionsButton
                    }
                    
                    infoCallout
                }
                .padding(20)
            }
            .background(Color.grootCloud)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text("patterns")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.grootBark)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    GrootIconButton("plus", variant: .primary, size: .small) {
                        viewModel?.openAddSheet()
                    }
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { viewModel?.showAddSheet ?? false },
            set: { viewModel?.showAddSheet = $0 }
        )) {
            AddPatternSheet()
                .presentationDetents([.medium, .large])
        }
        .grootToast(
            isPresented: Binding(
                get: { viewModel?.showToast ?? false },
                set: { viewModel?.showToast = $0 }
            ),
            message: viewModel?.toastMessage ?? ""
        )
        .onAppear {
            if viewModel == nil {
                viewModel = PatternsViewModel(callBlockingService: callBlockingService)
            }
        }
    }
    
    // MARK: - View Components
    
    private var statsSection: some View {
        HStack(spacing: 12) {
            PatternStatCard(
                icon: "number",
                value: "\(patterns.count)",
                label: "patterns",
                color: .grootViolet
            )
            
            PatternStatCard(
                icon: "checkmark.circle.fill",
                value: "\(viewModel?.enabledCount(from: patterns) ?? 0)",
                label: "active",
                color: .grootShield
            )
            
            PatternStatCard(
                icon: "phone.down.fill",
                value: "\(viewModel?.totalMatches(from: patterns) ?? 0)",
                label: "blocked",
                color: .grootFlame
            )
        }
        .grootAppear(delay: 0)
    }
    
    private var searchSection: some View {
        GrootSearchField(
            "search patterns",
            text: Binding(
                get: { viewModel?.searchText ?? "" },
                set: { viewModel?.searchText = $0 }
            )
        )
        .grootAppear(delay: 0.1)
    }
    
    private var patternsListSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                GrootText("your patterns", style: .heading)
                Spacer()
                Text("\(filteredPatterns.count) pattern\(filteredPatterns.count == 1 ? "" : "s")")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.grootStone)
            }
            .grootAppear(delay: 0.1)
            
            VStack(spacing: 0) {
                ForEach(filteredPatterns) { pattern in
                    PatternRow(
                        pattern: pattern,
                        onToggle: { viewModel?.togglePattern(pattern) },
                        onDelete: { viewModel?.deletePattern(pattern) }
                    )
                    
                    if pattern.id != filteredPatterns.last?.id {
                        Divider().padding(.leading, 70)
                    }
                }
            }
            .background(Color.grootSnow)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .grootAppear(delay: 0.2)
        }
    }
    
    private var suggestedPatternsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                GrootText("suggested patterns", style: .heading)
                Spacer()
                Button {
                    viewModel?.hideSuggestions()
                } label: {
                    Text("hide")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.grootStone)
                }
            }
            .grootAppear(delay: 0.3)
            
            VStack(spacing: 0) {
                let suggestions = availableSuggestions
                ForEach(suggestions.indices, id: \.self) { index in
                    let suggestion = suggestions[index]
                    SuggestedPatternRow(
                        pattern: suggestion.pattern,
                        description: suggestion.description,
                        isAdded: viewModel?.isPatternAdded(suggestion.pattern, in: patterns) ?? false,
                        onAdd: { viewModel?.addSuggestedPattern(suggestion) }
                    )
                    
                    if index < suggestions.count - 1 {
                        Divider().padding(.leading, 70)
                    }
                }
            }
            .background(Color.grootSnow)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .grootAppear(delay: 0.4)
        }
    }
    
    private var showSuggestionsButton: some View {
        Button {
            viewModel?.showSuggestions()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                Text("show suggested patterns")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(Color.grootSky)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.grootSky.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .grootAppear(delay: 0.3)
    }
    
    private var infoCallout: some View {
        GrootCallout(
            title: "how patterns work",
            message: "Use # for each unknown digit. For example, +37529123#### matches 10,000 numbers. Maximum 6 # per pattern and 2,000,000 numbers across active patterns.",
            icon: "lightbulb.fill",
            color: .grootSun
        )
        .grootAppear(delay: 0.5)
    }
}

// MARK: - Preview

#Preview("PatternsView") {
    PatternsView()
        .modelContainer(for: BlockPattern.self, inMemory: true)
}

#Preview("PatternsTabView") {
    PatternsTabView()
        .modelContainer(for: BlockPattern.self, inMemory: true)
}
