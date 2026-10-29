//
//  AddTorrentView.swift
//  TransmissionRemote-iOS
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

    private let client: TransmissionClientProtocol?
    private let onSuccess: (() -> Void)?

    public init(
        initialMagnetOrUrl: String? = nil,
        client: TransmissionClientProtocol? = nil,
        onSuccess: (() -> Void)? = nil
    ) {
        self._viewModel = State(wrappedValue: AddTorrentViewModel(initialMagnetOrUrl: initialMagnetOrUrl))
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
                                    Text(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))
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

                // Options
                Section("Parameters") {
                    Toggle("Start Immediately", isOn: $viewModel.startImmediately)
                }
            }
            .navigationTitle("New Torrent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(viewModel.isSubmitting)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        submitTorrent()
                    } label: {
                        if viewModel.isSubmitting {
                            ProgressView()
                        } else {
                            Text("Add")
                                .bold()
                        }
                    }
                    .disabled(!viewModel.isValid || viewModel.isSubmitting || activeClient == nil)
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
        }
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

        Task {
            let success = await viewModel.submit(client: client)
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
