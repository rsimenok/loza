//
//  AddTorrentView.swift
//  Loza
//
//  Created by Roman Simenok on 29.10.2026.
//

import SwiftUI
import UniformTypeIdentifiers

/// Modal sheet for adding a new torrent via magnet URL or local .torrent file.
public struct AddTorrentView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var environment: AppEnvironment?

    @State private var viewModel: AddTorrentViewModel
    @State private var isFileImporterPresented: Bool = false
    @FocusState private var isLocationFocused: Bool

    private let client: TransmissionClientProtocol?
    private let onSuccess: (() -> Void)?

    public init(
        initialMagnetOrUrl: String? = nil,
        availableServerTags: [String] = [],
        client: TransmissionClientProtocol? = nil,
        onSuccess: (() -> Void)? = nil
    ) {
        self._viewModel = State(wrappedValue: AddTorrentViewModel(initialMagnetOrUrl: initialMagnetOrUrl, availableServerTags: availableServerTags))
        self.client = client
        self.onSuccess = onSuccess
    }

    public init(
        viewModel: AddTorrentViewModel,
        client: TransmissionClientProtocol? = nil,
        onSuccess: (() -> Void)? = nil
    ) {
        self._viewModel = State(wrappedValue: viewModel)
        self.client = client
        self.onSuccess = onSuccess
    }

    private var activeClient: TransmissionClientProtocol? {
        client ?? environment?.currentClient
    }

    public var body: some View {
        NavigationStack {
            Form {
                // Connection Warning
                if activeClient == nil {
                    Section {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("No active Transmission server selected. Check connection in settings.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Error Banner
                if let error = viewModel.errorMessage {
                    Section {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.red)
                            Text(error)
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }
                    }
                }

                // Magnet or URL Link
                Section("Magnet or URL Link") {
                    HStack {
                        TextField("magnet:?xt=... or https://...", text: $viewModel.magnetOrUrl, axis: .vertical)
                            .lineLimit(2...5)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)

                        if !viewModel.magnetOrUrl.isEmpty {
                            Button {
                                viewModel.magnetOrUrl = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.borderless)
                        }
                    }

                    Button {
                        HapticManager.shared.impact(.light)
                        viewModel.pasteFromClipboard()
                    } label: {
                        Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
                    }
                }

                // .torrent File
                Section("Torrent File (.torrent)") {
                    if let fileName = viewModel.selectedFileName {
                        HStack(spacing: 12) {
                            Image(systemName: "doc.fill")
                                .font(.title2)
                                .foregroundStyle(.blue)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(fileName)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)

                                if let data = viewModel.selectedFileData {
                                    Text(Torrent.formatBytes(Int64(data.count)))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Button(role: .destructive) {
                                viewModel.clearSelectedFile()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Delete File")
                        }
                    } else {
                        Button {
                            isFileImporterPresented = true
                        } label: {
                            Label("Choose .torrent File", systemImage: "doc.badge.plus")
                        }
                    }
                }

                // Download Location
                Section("Download Location") {
                    TextField("Default (Server Settings)", text: $viewModel.downloadDir)
                        .focused($isLocationFocused)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    if isLocationFocused && !viewModel.recentPaths.isEmpty {
                        ForEach(viewModel.recentPaths, id: \.self) { path in
                            Button {
                                viewModel.downloadDir = path
                                isLocationFocused = false
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Text(path)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Tags
                Section("Tags") {
                    if !viewModel.tags.isEmpty {
                        tagCapsulesView
                    }

                    HStack {
                        TextField("Add tag...", text: $viewModel.tagInput)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .onSubmit {
                                viewModel.commitCurrentTagInput()
                            }
                            .onChange(of: viewModel.tagInput) { _, newValue in
                                if newValue.contains(",") {
                                    viewModel.commitCurrentTagInput()
                                }
                            }

                        if !viewModel.tagInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button {
                                HapticManager.shared.impact(.light)
                                viewModel.commitCurrentTagInput()
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(Color.accentColor)
                            }
                            .buttonStyle(.borderless)
                        }
                    }

                    let suggestions = viewModel.filteredSuggestions()
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
                                            viewModel.addTag(suggestion)
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

                // Options
                Section("Parameters") {
                    Toggle("Start Immediately", isOn: $viewModel.startImmediately)
                }
            }
            .navigationTitle("New Torrent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .disabled(viewModel.isSubmitting)
                    .accessibilityLabel("Cancel")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        submitTorrent()
                    } label: {
                        if viewModel.isSubmitting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "checkmark")
                                .font(.body.bold())
                        }
                    }
                    .disabled(!viewModel.isValid || viewModel.isSubmitting || activeClient == nil)
                    .accessibilityLabel("Add")
                }
            }
            .fileImporter(
                isPresented: $isFileImporterPresented,
                allowedContentTypes: torrentContentTypes,
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        viewModel.handleFileSelected(url: url)
                    }
                case .failure(let error):
                    viewModel.errorMessage = String(localized: "File selection error: \(error.localizedDescription)")
                }
            }
            .onAppear {
                viewModel.loadRecentPaths(serverId: environment?.activeServer?.id)
            }
        }
    }

    private var tagCapsulesView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(viewModel.tags, id: \.self) { tag in
                    HStack(spacing: 6) {
                        Text(tag)
                            .font(.subheadline)
                            .foregroundStyle(.primary)

                        Button {
                            HapticManager.shared.impact(.light)
                            viewModel.removeTag(tag)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Remove tag \(tag)")
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.accentColor.opacity(0.15), in: Capsule())
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var torrentContentTypes: [UTType] {
        var types: [UTType] = [.data, .item]
        if let torrentType = UTType(filenameExtension: "torrent") {
            types.insert(torrentType, at: 0)
        }
        return types
    }

    private func submitTorrent() {
        guard let client = activeClient else {
            viewModel.errorMessage = String(localized: "No active server selected")
            return
        }

        HapticManager.shared.impact(.medium)

        let activeServerId = environment?.activeServer?.id
        Task {
            let success = await viewModel.submit(client: client, serverId: activeServerId)
            if success {
                HapticManager.shared.torrentAdded()
                dismiss()
                onSuccess?()
            } else {
                HapticManager.shared.notification(.error)
            }
        }
    }
}

#Preview {
    AddTorrentView()
        .environment(AppEnvironment())
}
