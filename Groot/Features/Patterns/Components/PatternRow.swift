//
//  PatternRow.swift
//  Groot
//
//  Created by Abdulbasit Ajaga on 31/01/2026.
//

import SwiftUI

// MARK: - Pattern Row

struct PatternRow: View {
    let pattern: BlockPattern
    let onToggle: () -> Void
    let onDelete: () -> Void
    
    @State private var showDeleteConfirm = false
    
    var body: some View {
        GrootSwipeableListItem(
            trailingActions: [
                .init(icon: "trash.fill", color: .grootFlame) {
                    showDeleteConfirm = true
                }
            ]
        ) {
            HStack(spacing: 14) {
                statusIcon
                contentStack
                Spacer()
                trailingContent
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .confirmationDialog(
            "Delete Pattern?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This pattern will no longer match any numbers.")
        }
    }
    
    // MARK: - View Components
    
    private var statusIcon: some View {
        ZStack {
            Circle()
                .fill(statusColor.opacity(0.15))
                .frame(width: 48, height: 48)
            
            Image(systemName: "number")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(statusColor)
        }
    }
    
    private var contentStack: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(pattern.pattern)
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.grootBark)
            
            Text(pattern.patternDescription.lowercased())
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(Color.grootStone)
                .lineLimit(1)
            
            HStack(spacing: 8) {
                StatusBadge(isEnabled: pattern.isEnabled)
                
                Text(pattern.blocksCalls ? "block" : "label")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(pattern.blocksCalls ? Color.grootFlame : Color.grootViolet)
                
                Text("≈\(pattern.expandedCount.formatted())")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.grootStone)
                
                if pattern.matchCount > 0 {
                    Text("•")
                        .foregroundStyle(Color.grootPebble)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "phone.down.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("\(pattern.matchCount)")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(Color.grootFlame)
                }
                
                Text("•")
                    .foregroundStyle(Color.grootPebble)
                
                Text(timeAgo)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.grootStone)
            }
        }
    }
    
    private var trailingContent: some View {
        GrootToggleSwitch(isOn: Binding(
            get: { pattern.isEnabled },
            set: { _ in onToggle() }
        ))
    }
    
    // MARK: - Computed Properties
    
    private var statusColor: Color {
        pattern.isEnabled ? .grootViolet : .grootPebble
    }
    
    private var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: pattern.createdAt, relativeTo: Date())
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let isEnabled: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isEnabled ? Color.grootShield : Color.grootPebble)
                .frame(width: 6, height: 6)
            
            Text(isEnabled ? "active" : "paused")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(isEnabled ? Color.grootShield : Color.grootPebble)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background((isEnabled ? Color.grootShield : Color.grootPebble).opacity(0.15))
        .clipShape(Capsule())
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        PatternRow(
            pattern: BlockPattern(
                pattern: "+37529123####",
                description: "Suspected scam",
                matchCount: 42,
                isEnabled: true
            ),
            onToggle: { },
            onDelete: { }
        )
        
        Divider().padding(.leading, 70)
        
        PatternRow(
            pattern: BlockPattern(
                pattern: "+3816012#####",
                description: "Suspected scam",
                matchCount: 0,
                isEnabled: false
            ),
            onToggle: { },
            onDelete: { }
        )
    }
    .background(Color.grootSnow)
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .padding()
    .background(Color.grootCloud)
}
