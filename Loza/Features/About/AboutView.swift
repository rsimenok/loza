//
//  AboutView.swift
//  Loza
//
//  Created by Roman Simenok on 30.10.2026.
//

import SwiftUI

/// Screen presenting application metadata, open-source repository link, and third-party acknowledgements.
@MainActor
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var environment: AppEnvironment?

    @State private var isPresentingTipJar = false

    private let gitHubURL = URL(string: "https://github.com/rsimenok/loza")!
    private let alamofireURL = URL(string: "https://github.com/Alamofire/Alamofire")!

    private var isSupporter: Bool {
        environment?.purchaseManager.isSupporter ?? false
    }

    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return String(format: String(localized: "Version %@ (%@)"), version, build)
    }

    var body: some View {
        Form {
            headerSection
            supportSection
            projectSection
            thirdPartySection
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $isPresentingTipJar) {
            NavigationStack {
                TipJarView()
            }
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        Section {
            VStack(spacing: 12) {
                appIconView

                Text("Loza")
                    .font(.title3.bold())
                    .foregroundStyle(.primary)

                Text(appVersionString)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if isSupporter {
                    HStack(spacing: 5) {
                        Image(systemName: "star.fill")
                            .font(.caption2.bold())
                            .foregroundStyle(.yellow)
                        Text("Supporter")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.yellow.opacity(0.18))
                    .clipShape(Capsule())
                }

                Text("Free and open-source utility for remote management of your Transmission daemon.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
    }

    private var appIconView: some View {
        Group {
            if let icon = loadAppIcon() {
                Image(uiImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.accentColor.gradient)
                        .frame(width: 64, height: 64)

                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)
    }

    private var supportSection: some View {
        Section("Support") {
            Button {
                isPresentingTipJar = true
            } label: {
                HStack {
                    Label("Tip Jar", systemImage: "heart.fill")
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var projectSection: some View {
        Section("Project") {
            Link(destination: gitHubURL) {
                HStack {
                    Label("Source Code on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var thirdPartySection: some View {
        Section("Third-Party Software") {
            Link(destination: alamofireURL) {
                HStack {
                    Label("Alamofire", systemImage: "shippingbox")
                    Spacer()
                    Text("MIT")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Image(systemName: "arrow.up.right")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func loadAppIcon() -> UIImage? {
        if let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
           let lastIcon = iconFiles.last {
            return UIImage(named: lastIcon)
        }
        return UIImage(named: "AppIcon")
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
