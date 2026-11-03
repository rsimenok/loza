//
//  TagEditorView.swift
//  Loza
//
//  Created by Roman Simenok on 02.11.2026.
//

import SwiftUI

/// Reusable tag editor component featuring interactive capsule chips,
/// comma/Return auto-committing input, and single-tap server suggestions.
struct TagEditorView: View {
    @Binding var tags: [String]
    var availableServerTags: [String]
    var onTagAdded: ((String) -> Void)?
    var onTagRemoved: ((String) -> Void)?

    @State private var tagInput: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !tags.isEmpty {
                tagCapsulesView
            }

            HStack {
                TextField("Add tag...", text: $tagInput)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit {
                        commitInput()
                    }
                    .onChange(of: tagInput) { _, newValue in
                        if newValue.contains(",") {
                            commitInput()
                        }
                    }

                if !tagInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {
                        HapticManager.shared.impact(.light)
                        commitInput()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.borderless)
                }
            }

            let suggestions = filteredSuggestions
            if !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Suggested Tags")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(suggestions, id: \.self) { suggestion in
                                Button {
                                    HapticManager.shared.impact(.light)
                                    addTag(suggestion)
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus")
                                            .font(.caption2)
                                        Text(suggestion)
                                            .font(.subheadline)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color(.secondarySystemFill), in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var tagCapsulesView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(tags, id: \.self) { tag in
                    HStack(spacing: 4) {
                        Text(tag)
                            .font(.subheadline)
                            .foregroundStyle(.primary)

                        Button {
                            HapticManager.shared.impact(.light)
                            removeTag(tag)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(Text("Remove tag \(tag)"))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.accentColor.opacity(0.15), in: Capsule())
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var filteredSuggestions: [String] {
        let currentLower = Set(tags.map { $0.lowercased() })
        let unselected = availableServerTags.filter { !currentLower.contains($0.lowercased()) }
        let query = tagInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty {
            return unselected
        }
        return unselected.filter { $0.lowercased().contains(query) }
    }

    private func commitInput() {
        let raw = tagInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            tagInput = ""
            return
        }
        let parts = raw.components(separatedBy: ",")
        for part in parts {
            addTag(part)
        }
        tagInput = ""
    }

    private func addTag(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !tags.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else { return }
        if let onTagAdded {
            onTagAdded(trimmed)
        } else {
            tags.append(trimmed)
        }
    }

    private func removeTag(_ tag: String) {
        if let onTagRemoved {
            onTagRemoved(tag)
        } else {
            tags.removeAll { $0 == tag }
        }
    }
}
