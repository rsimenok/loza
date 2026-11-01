//
//  ServerEditView.swift
//  Loza
//
//  Created by Roman Simenok on 29.10.2026.
//

import SwiftUI

public struct ServerEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var environment: AppEnvironment?

    @State private var viewModel: ServerEditViewModel
    private let customRepository: ServerRepositoryProtocol?
    private let onSave: ((ServerConfig) -> Void)?

    @State private var saveErrorMessage: String?
    @State private var isShowingErrorAlert: Bool = false
    @State private var isPasswordVisible: Bool = false
    @FocusState private var isPasswordFieldFocused: Bool

    public init(
        viewModel: ServerEditViewModel,
        repository: ServerRepositoryProtocol? = nil,
        onSave: ((ServerConfig) -> Void)? = nil
    ) {
        _viewModel = State(initialValue: viewModel)
        self.customRepository = repository
        self.onSave = onSave
    }

    public init(
        server: ServerConfig? = nil,
        password: String? = nil,
        repository: ServerRepositoryProtocol? = nil,
        onSave: ((ServerConfig) -> Void)? = nil
    ) {
        let vm = ServerEditViewModel(
            server: server,
            initialPassword: password,
            repository: repository
        )
        self.init(viewModel: vm, repository: repository, onSave: onSave)
    }

    private var activeRepository: ServerRepositoryProtocol {
        if let customRepository {
            return customRepository
        }
        if let environment {
            return environment.serverRepository
        }
        return ServerRepository()
    }

    public var body: some View {
        Form {
            serverSection
            securitySection
            authSection
            diagnosticsSection
        }
        .navigationTitle(viewModel.isEditing ? "Edit Server" : "New Server")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    saveServer()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.body.bold())
                }
                .disabled(!viewModel.isValid)
                .accessibilityLabel("Save")
            }
        }
        .alert("Save Error", isPresented: $isShowingErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(saveErrorMessage ?? String(localized: "Unknown Error"))
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var serverSection: some View {
        Section(header: Text("Server")) {
            TextField("Name", text: $viewModel.name)
                .autocorrectionDisabled()

            Picker("Scheme", selection: $viewModel.scheme) {
                Text("HTTP").tag(ServerScheme.http)
                Text("HTTPS").tag(ServerScheme.https)
            }
            .pickerStyle(.segmented)

            TextField("Host or IP", text: $viewModel.host)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            TextField("Port", text: $viewModel.portString)
                .keyboardType(.numberPad)

            TextField("RPC Path", text: $viewModel.rpcPath)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
    }

    @ViewBuilder
    private var securitySection: some View {
        Section(header: Text("Security"), footer: Text("Enable if the server uses a custom or self-signed SSL certificate.")) {
            Toggle("Trust Self-Signed Certificates", isOn: $viewModel.trustSelfSigned)
        }
    }

    @ViewBuilder
    private var authSection: some View {
        Section(header: Text("Authentication")) {
            TextField("Username", text: $viewModel.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.username)

            HStack {
                if isPasswordVisible {
                    TextField("Password", text: $viewModel.password)
                        .textContentType(.password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($isPasswordFieldFocused)
                } else {
                    SecureField("Password", text: $viewModel.password)
                        .textContentType(.password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($isPasswordFieldFocused)
                }

                Button {
                    isPasswordVisible.toggle()
                } label: {
                    Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(isPasswordVisible ? String(localized: "Hide Password") : String(localized: "Show Password"))
            }
        }
    }

    @ViewBuilder
    private var diagnosticsSection: some View {
        Section(header: Text("Diagnostics")) {
            Button {
                Task {
                    await viewModel.testConnection()
                    if case .success = viewModel.testResult {
                        HapticManager.shared.connectionTestSucceeded()
                    } else if case .failure = viewModel.testResult {
                        HapticManager.shared.connectionTestFailed()
                    }
                }
            } label: {
                HStack {
                    Text("Test Connection")
                    Spacer()
                    if viewModel.isTestingConnection {
                        ProgressView()
                    }
                }
            }
            .disabled(viewModel.isTestingConnection || !viewModel.isValid)

            if let result = viewModel.testResult {
                switch result {
                case .success(let stats):
                    successBadge(stats: stats)
                case .failure(let error):
                    failureBadge(error: error)
                }
            }
        }
    }

    @ViewBuilder
    private func successBadge(stats: SessionStats) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .imageScale(.large)
                Text("Connection Successful")
                    .font(.headline)
                    .foregroundColor(.green)
            }

            Text("Active Torrents: \(stats.activeTorrentCount) of \(stats.torrentCount)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func failureBadge(error: Error) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .imageScale(.large)
                Text("Connection Failed")
                    .font(.headline)
                    .foregroundColor(.red)
            }

            Text(error.localizedDescription)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Actions

    private func saveServer() {
        Task {
            do {
                let saved = try await viewModel.save(to: activeRepository)
                HapticManager.shared.notification(.success)
                environment?.syncActiveServer()
                onSave?(saved)
                dismiss()
            } catch {
                HapticManager.shared.notification(.error)
                saveErrorMessage = error.localizedDescription
                isShowingErrorAlert = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        ServerEditView(
            viewModel: ServerEditViewModel(
                server: ServerConfig(
                    name: "Home NAS",
                    scheme: .http,
                    host: "192.168.1.100",
                    port: 9091
                ),
                client: MockTransmissionClient()
            )
        )
    }
}
