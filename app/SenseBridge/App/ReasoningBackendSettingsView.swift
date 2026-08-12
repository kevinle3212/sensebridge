import SenseBridgeCore
import SwiftUI

/// The Cloud/Local/On-Device reasoning backend picker and its consent flow.
/// A separate `View` for the same reason `AwarenessSettingsSection` and
/// `DiagnosticsSettingsSection` are — see either's doc comment.
///
/// Per docs/superpowers/specs/2026-08-11-awareness-ai-tiers-design.md
/// "Consent UX": default off, one-time explicit disclosure before any
/// network backend can be turned on, a real `Toggle` (never a bare tap
/// target) for third-party ToS acknowledgment re-shown on every provider
/// switch, a write-only key field with a paste-from-clipboard primary path
/// (a blind user cannot proofread a `SecureField`), and a persistent
/// Remove-key control since switching away from `.cloud` must not silently
/// discard a saved key.
struct ReasoningBackendSettingsView: View {
    @Binding var reasoningBackend: ReasoningBackend
    @Binding var cloudProvider: CloudProvider?
    @Binding var localEndpointURL: String?
    @Binding var reasoningModelOverride: String?
    /// Clamps `narrationIntervalSeconds` while a network backend is active —
    /// read-only display here; the actual floor is enforced where the value
    /// is used (`AmbientAwarenessSession`/`AwarenessSettingsSection`'s
    /// slider `in:` range), not duplicated here.
    let narrationIntervalSeconds: Double

    private let credentialStore: KeychainCredentialStore = .init()

    @State private var pastedKey = ""
    @State private var hasStoredKey = false
    @State private var tosAcknowledged = false
    @State private var connectionTestResult: String?
    @State private var isTestingConnection = false
    @State private var requestCount = 0 // local-only, reset each app launch — not analytics

    var body: some View {
        Section {
            Picker("Reasoning backend", selection: $reasoningBackend) {
                Text("On-Device").tag(ReasoningBackend.onDevice)
                Text("Local").tag(ReasoningBackend.localEndpoint)
                Text("Cloud").tag(ReasoningBackend.cloud)
            }
            .accessibilityHint("Chooses which backend composes scene descriptions. On-device is free and private.")
            .onChange(of: reasoningBackend) { _, _ in
                tosAcknowledged = false
                connectionTestResult = nil
            }

            switch reasoningBackend {
            case .onDevice:
                EmptyView()
            case .localEndpoint:
                localEndpointFields
                bundledModelDisclosureRow
            case .cloud:
                cloudFields
            }
        } header: {
            Text("Reasoning")
                .foregroundStyle(Color("SecondaryText"))
        } footer: {
            Text(footerText)
                .foregroundStyle(Color("SecondaryText"))
        }
        .task { hasStoredKey = credentialStore.credential(for: currentCredentialKey) != nil }
    }

    // MARK: - Local

    @ViewBuilder
    private var localEndpointFields: some View {
        TextField(
            "Endpoint URL", text: Binding(get: { localEndpointURL ?? "" }, set: { localEndpointURL = $0 }),
            prompt: Text("http://192.168.1.20:11434")
        )
        .keyboardType(.URL)
        .textInputAutocapitalization(.never)
        .accessibilityHint("""
        Your own self-hosted server's address. Labels leave your device to \
        whatever this address reaches — SenseBridge has no visibility past that point.
        """)
        TextField(
            "Model name",
            text: Binding(get: { reasoningModelOverride ?? "" }, set: { reasoningModelOverride = $0 }),
            prompt: Text("llama3.2")
        )
        .textInputAutocapitalization(.never)
        .accessibilityHint("Required — your server's model identifier.")
        tosAcknowledgmentToggle(
            label: "I understand this sends labels to the address I entered",
            linkLabel: nil
        )
        testConnectionRow
    }

    private var bundledModelDisclosureRow: some View {
        Label {
            Text("Bundled on-device model — not yet available. Needs a benchmarked model; tracked as a follow-up.")
                .font(.callout)
        } icon: {
            Image(systemName: "info.circle")
                .foregroundStyle(Color("SecondaryText"))
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Cloud

    @ViewBuilder
    private var cloudFields: some View {
        Picker("Provider", selection: $cloudProvider) {
            Text("Choose a provider").tag(CloudProvider?.none)
            Text("Anthropic").tag(CloudProvider?.some(.anthropic))
            Text("OpenAI").tag(CloudProvider?.some(.openai))
            Text("NVIDIA NIM").tag(CloudProvider?.some(.nvidiaNIM))
        }
        .onChange(of: cloudProvider) { _, _ in
            tosAcknowledged = false
            connectionTestResult = nil
            hasStoredKey = credentialStore.credential(for: currentCredentialKey) != nil
        }
        if cloudProvider == .nvidiaNIM {
            TextField(
                "Model name",
                text: Binding(get: { reasoningModelOverride ?? "" }, set: { reasoningModelOverride = $0 }),
                prompt: Text("meta/llama-3.1-8b-instruct")
            )
            .accessibilityHint("Required — NVIDIA NIM has no default model.")
        }
        if hasStoredKey {
            HStack {
                Text("A key is saved")
                Spacer()
                Button("Remove", role: .destructive) {
                    credentialStore.removeCredential(for: currentCredentialKey)
                    hasStoredKey = false
                    connectionTestResult = nil
                }
            }
        } else {
            Button("Paste key from clipboard") {
                if let clipboardText = UIPasteboard.general.string, !clipboardText.isEmpty {
                    pastedKey = clipboardText
                }
            }
            .accessibilityHint("Primary way to enter your API key — avoids typing it character by character.")
            SecureField("API key", text: $pastedKey)
                .accessibilityHint("Fallback if you can't paste. This field never shows a previously saved key.")
            if !pastedKey.isEmpty {
                Button("Save key") {
                    credentialStore.save(pastedKey, for: currentCredentialKey)
                    pastedKey = ""
                    hasStoredKey = true
                }
            }
        }
        if let provider = cloudProvider, provider != .nvidiaNIM || hasStoredKey {
            tosAcknowledgmentToggle(
                label: "I have read and agree to \(providerName(provider))'s terms of service",
                linkLabel: providerTermsLabel(provider)
            )
        }
        testConnectionRow
        Text("Requests this session: \(requestCount)")
            .font(.caption)
            .foregroundStyle(Color("SecondaryText"))
    }

    // MARK: - Shared

    /// A `Toggle`-backed ToS/data-use acknowledgment — never a bare tap
    /// target, so VoiceOver announces it with the same on/off semantics as
    /// any other consent control in the app.
    private func tosAcknowledgmentToggle(label: LocalizedStringKey, linkLabel: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(isOn: $tosAcknowledged) {
                Text(label)
            }
            .accessibilityHint("Required before this backend can be turned on.")
            if let linkLabel {
                Text(linkLabel)
                    .font(.caption)
                    .foregroundStyle(Color("SecondaryText"))
            }
        }
    }

    @ViewBuilder
    private var testConnectionRow: some View {
        Button(isTestingConnection ? "Testing…" : "Test connection") {
            Task { await testConnection() }
        }
        .disabled(isTestingConnection || !canTestConnection)
        .accessibilityHint("Sends one real request to confirm this backend works before you rely on it.")
        if let connectionTestResult {
            Text(connectionTestResult)
                .font(.caption)
                .foregroundStyle(Color("SecondaryText"))
        }
    }
}

/// Non-view-building logic — state derivation, the network round trip, and
/// static copy — split out of the struct body purely to keep it under
/// SwiftLint's `type_body_length`. Same-file access to the type's private
/// members is unaffected.
private extension ReasoningBackendSettingsView {
    var canTestConnection: Bool {
        switch reasoningBackend {
        case .onDevice: false
        case .localEndpoint: !(localEndpointURL ?? "").isEmpty && !(reasoningModelOverride ?? "").isEmpty
        case .cloud:
            switch cloudProvider {
            case .anthropic, .openai: hasStoredKey
            case .nvidiaNIM: !(reasoningModelOverride ?? "").isEmpty
            case nil: false
            }
        }
    }

    /// Sends one real request through the configured backend to confirm it
    /// works before the user relies on it in a hands-free session where a
    /// failure would otherwise surface only as a silent fallback.
    func testConnection() async {
        isTestingConnection = true
        defer { isTestingConnection = false }
        let session = URLSession(configuration: .ephemeral)
        let factory = LiveNetworkComposerFactory(session: session, requestTimeout: 8, locale: .current)
        let credential = credentialStore.credential(for: currentCredentialKey)
        let request = NetworkComposerRequest(
            provider: cloudProvider, endpointURL: localEndpointURL,
            modelOverride: reasoningModelOverride, credential: credential, detail: .standard
        )
        guard let composer = factory.composer(backend: reasoningBackend, configuration: request) else {
            connectionTestResult = "Couldn't build a request — check the fields above."
            return
        }
        do {
            _ = try await composer.compose(from: [
                PerceptionRecord(kind: .detectedObject(label: "chair", confidence: 0.9), capturedAt: .now)
            ])
            requestCount += 1
            connectionTestResult = "Connection works."
        } catch {
            connectionTestResult = "Couldn't connect. Check the address, model, and key, then try again."
        }
    }

    var currentCredentialKey: CredentialKey {
        switch reasoningBackend {
        case .onDevice: .anthropic // unused; onDevice never reads a credential
        case .localEndpoint: .localEndpoint
        case .cloud:
            switch cloudProvider {
            case .anthropic: .anthropic
            case .openai: .openai
            case .nvidiaNIM: .nvidiaNIM
            case nil: .anthropic
            }
        }
    }

    /// The display name shown in the ToS acknowledgment label.
    func providerName(_ provider: CloudProvider) -> String {
        switch provider {
        case .anthropic: "Anthropic"
        case .openai: "OpenAI"
        case .nvidiaNIM: "NVIDIA"
        }
    }

    /// The provider's ToS name and URL, shown as caption text under the acknowledgment toggle.
    func providerTermsLabel(_ provider: CloudProvider) -> String {
        switch provider {
        case .anthropic: "Anthropic's Consumer Terms of Service, anthropic.com/legal/consumer-terms"
        case .openai: "OpenAI's Terms of Use, openai.com/policies/terms-of-use"
        case .nvidiaNIM: "NVIDIA's API Terms of Use, nvidia.com/en-us/agreements/cloud-services/product-terms"
        }
    }

    var footerText: LocalizedStringKey {
        switch reasoningBackend {
        case .onDevice:
            "Free, private, and the default. Nothing about your surroundings leaves your device."
        case .localEndpoint:
            """
            Sends recognized labels to a server you control. Off by default. Turn it off any \
            time from this screen. While a network backend is active, the time between hands-free \
            descriptions is held to at least 10 seconds to bound request volume.
            """
        case .cloud:
            """
            Sends recognized labels — never camera images, audio, or your location — to the \
            provider you choose, only after you agree to their terms. Off by default. Turn it \
            off any time from this screen. If it stops responding, SenseBridge continues with \
            on-device descriptions and tells you once. While a network backend is active, the \
            time between hands-free descriptions is held to at least 10 seconds to bound request volume.
            """
        }
    }
}
