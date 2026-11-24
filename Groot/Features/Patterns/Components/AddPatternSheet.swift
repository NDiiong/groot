//
//  AddPatternSheet.swift
//  Groot
//
//  Created by Abdulbasit Ajaga on 31/01/2026.
//

import SwiftUI

// MARK: - Add Pattern Sheet

struct AddPatternSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.callBlockingService) private var callBlockingService
    
    @State private var pattern = ""
    @State private var patternDescription = ""
    @State private var blocksCalls = false
    @State private var isAdding = false
    @State private var errorMessage: String?
    
    @FocusState private var focusedField: Field?
    
    enum Field {
        case pattern
        case description
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                headerSection
                formSection
                examplesSection
                Spacer()
            }
            .padding(20)
            .background(Color.grootCloud)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    GrootCloseButton {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.grootViolet.opacity(0.15))
                    .frame(width: 72, height: 72)
                
                Image(systemName: "number")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Color.grootViolet)
            }
            
            GrootText("create pattern", style: .title)
            
            Text("use # for each unknown digit")
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(Color.grootStone)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }
    
    private var formSection: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("pattern")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.grootStone)
                
                PatternTextField(
                    text: $pattern,
                    placeholder: "+37529123####",
                    isFocused: focusedField == .pattern
                )
                .focused($focusedField, equals: .pattern)
                
                Text(estimateText)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.grootStone)
            }
            
            GrootTextField(
                "description",
                text: $patternDescription,
                icon: "text.alignleft"
            )
            
            Toggle(isOn: $blocksCalls) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("block calls")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.grootBark)
                    Text(blocksCalls ? "matching calls are rejected" : "matching calls ring with a scam warning label")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(Color.grootStone)
                }
            }
            .tint(Color.grootViolet)
            
            if let error = errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 14))
                    Text(error.lowercased())
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                }
                .foregroundStyle(Color.grootFlame)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            GrootButton(
                "create pattern",
                variant: .primary,
                icon: "plus.circle.fill",
                isDisabled: !isValidPattern,
                isLoading: isAdding
            ) {
                addPattern()
            }
        }
    }
    
    private var examplesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("pattern examples")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.grootStone)
            
            VStack(spacing: 8) {
                PatternExampleRow(
                    pattern: "+37529123####",
                    description: "4 unknown digits = 10,000 numbers",
                    onTap: {
                        pattern = "+37529123####"
                        patternDescription = "Suspected scam"
                    }
                )
                
                PatternExampleRow(
                    pattern: "+3816012#####",
                    description: "5 unknown digits = 100,000 numbers",
                    onTap: {
                        pattern = "+3816012#####"
                        patternDescription = "Suspected scam"
                    }
                )
            }
        }
        .padding(16)
        .background(Color.grootSnow)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Computed Properties
    
    private var isValidPattern: Bool {
        BlockPattern.normalize(pattern) != nil && !patternDescription.isEmpty
    }
    
    private var estimateText: String {
        if BlockPattern.wildcardCount(in: pattern) > BlockPattern.maxWildcards {
            return "maximum \(BlockPattern.maxWildcards) # per pattern"
        }
        guard let normalized = BlockPattern.normalize(pattern) else {
            return "digits and # only, 7-15 digits including country code"
        }
        return "≈ \(BlockPattern.expandedCount(of: normalized).formatted()) numbers"
    }
    
    // MARK: - Actions
    
    private func addPattern() {
        isAdding = true
        errorMessage = nil
        
        do {
            try callBlockingService.addPattern(pattern, description: patternDescription, blocksCalls: blocksCalls)
            
            GrootHaptics.success()
            
            Task {
                try? await callBlockingService.reloadCallDirectory()
            }
            
            dismiss()
        } catch {
            withAnimation(.grootSnappy) {
                errorMessage = error.localizedDescription
            }
            isAdding = false
            GrootHaptics.error()
        }
    }
}

// MARK: - Pattern Text Field

struct PatternTextField: View {
    @Binding var text: String
    let placeholder: String
    let isFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "number")
                .foregroundStyle(isFocused ? Color.grootViolet : Color.grootPebble)
                .font(.system(size: 18, weight: .medium))
            
            TextField(placeholder, text: $text)
                .font(.system(size: 18, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.grootBark)
                .keyboardType(.phonePad)
            
            if !text.isEmpty {
                Button {
                    withAnimation(.grootSnappy) {
                        text = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.grootPebble)
                        .font(.system(size: 18))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.grootCloud)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isFocused ? Color.grootViolet : Color.grootMist, lineWidth: 2)
        )
        .animation(.grootSnappy, value: isFocused)
    }
}

// MARK: - Pattern Example Row

struct PatternExampleRow: View {
    let pattern: String
    let description: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Text(pattern)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.grootViolet)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.grootViolet.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                
                Text(description.lowercased())
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.grootStone)
                    .lineLimit(1)
                
                Spacer()
                
                Image(systemName: "arrow.up.left.circle")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.grootPebble)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    AddPatternSheet()
}
