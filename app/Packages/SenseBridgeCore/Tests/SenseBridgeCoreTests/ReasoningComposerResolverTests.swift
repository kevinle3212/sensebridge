import Foundation
import Testing
@testable import SenseBridgeCore

/// Never throws, never uses the network — stands in for
/// `FoundationModelsSceneComposer` in resolver tests.
private struct StubOnDeviceComposer: SceneComposer {
    func compose(from _: [PerceptionRecord]) async -> String {
        "on-device: stub"
    }
}

private struct FailingComposer: SceneComposer {
    struct Failure: Error {}
    func compose(from _: [PerceptionRecord]) async throws -> String {
        throw Failure()
    }
}

private struct SucceedingComposer: SceneComposer {
    func compose(from _: [PerceptionRecord]) async -> String {
        "network: ok"
    }
}

private final class StubFactory: NetworkComposerFactory, @unchecked Sendable {
    var next: SceneComposer?
    /// The `detail` the resolver most recently passed in — lets tests assert
    /// it actually forwarded `settings.spokenDetail` rather than a default.
    var lastDetail: SpokenDetail?
    func composer(backend _: ReasoningBackend, configuration: NetworkComposerRequest) -> SceneComposer? {
        lastDetail = configuration.detail
        return next
    }
}

private final class StubCredentialStore: APICredentialStore, @unchecked Sendable {
    var stored: [CredentialKey: String] = [:]
    func credential(for key: CredentialKey) -> String? {
        stored[key]
    }

    func save(_ value: String, for key: CredentialKey) {
        stored[key] = value
    }

    func removeCredential(for key: CredentialKey) {
        stored[key] = nil
    }
}

@MainActor
struct ReasoningComposerResolverTests {
    private func makeResolver(
        factory: StubFactory, store: StubCredentialStore = .init()
    ) -> ReasoningComposerResolver {
        ReasoningComposerResolver(onDeviceComposer: StubOnDeviceComposer(), credentialStore: store, factory: factory)
    }

    @Test func onDeviceBackendNeverConsultsTheFactory() async {
        let factory = StubFactory()
        let resolver = makeResolver(factory: factory)
        var settings = Settings()
        settings.reasoningBackend = .onDevice
        let result = await resolver.compose(from: [], settings: settings, locale: .current, requestTimeout: 4)
        #expect(result?.backendUsed == .onDevice)
        #expect(result?.announcement == nil)
    }

    @Test func cloudWithNoProviderConfiguredFallsBackSilently() async {
        let factory = StubFactory()
        let resolver = makeResolver(factory: factory)
        var settings = Settings()
        settings.reasoningBackend = .cloud
        settings.cloudProvider = nil
        let result = await resolver.compose(from: [], settings: settings, locale: .current, requestTimeout: 4)
        #expect(result?.backendUsed == .onDevice)
        #expect(result?.announcement == nil)
    }

    @Test func workingNetworkComposerIsUsedDirectly() async {
        let factory = StubFactory()
        factory.next = SucceedingComposer()
        let store = StubCredentialStore()
        store.save("sk-test", for: .anthropic)
        let resolver = makeResolver(factory: factory, store: store)
        var settings = Settings()
        settings.reasoningBackend = .cloud
        settings.cloudProvider = .anthropic
        let result = await resolver.compose(from: [], settings: settings, locale: .current, requestTimeout: 4)
        #expect(result?.backendUsed == .cloud)
        #expect(result?.text == "network: ok")
        #expect(result?.announcement == nil)
    }

    @Test func forwardsSettingsSpokenDetailToTheFactory() async {
        let factory = StubFactory()
        factory.next = SucceedingComposer()
        let store = StubCredentialStore()
        store.save("sk-test", for: .anthropic)
        let resolver = makeResolver(factory: factory, store: store)
        var settings = Settings()
        settings.reasoningBackend = .cloud
        settings.cloudProvider = .anthropic
        settings.spokenDetail = .detailed
        _ = await resolver.compose(from: [], settings: settings, locale: .current, requestTimeout: 4)
        #expect(factory.lastDetail == .detailed)
    }

    @Test func singleFailureFallsBackWithoutAnnouncing() async {
        let factory = StubFactory()
        factory.next = FailingComposer()
        let store = StubCredentialStore()
        store.save("sk-test", for: .anthropic)
        let resolver = makeResolver(factory: factory, store: store)
        var settings = Settings()
        settings.reasoningBackend = .cloud
        settings.cloudProvider = .anthropic
        let result = await resolver.compose(from: [], settings: settings, locale: .current, requestTimeout: 4)
        #expect(result?.backendUsed == .onDevice)
        #expect(result?.announcement == nil, "one failure must not announce yet")
    }

    @Test func secondConsecutiveFailureTripsTheBreakerAndAnnouncesOnce() async {
        let factory = StubFactory()
        factory.next = FailingComposer()
        let store = StubCredentialStore()
        store.save("sk-test", for: .anthropic)
        let resolver = makeResolver(factory: factory, store: store)
        var settings = Settings()
        settings.reasoningBackend = .cloud
        settings.cloudProvider = .anthropic
        _ = await resolver.compose(from: [], settings: settings, locale: .current, requestTimeout: 4)
        let second = await resolver.compose(from: [], settings: settings, locale: .current, requestTimeout: 4)
        #expect(second?.announcement != nil, "the second consecutive failure must announce once")
        let third = await resolver.compose(from: [], settings: settings, locale: .current, requestTimeout: 4)
        #expect(third?.announcement == nil, "must not repeat the announcement every tick")
    }

    @Test func recoveryAfterBreakerTripAnnouncesOnce() async {
        let factory = StubFactory()
        factory.next = FailingComposer()
        let store = StubCredentialStore()
        store.save("sk-test", for: .anthropic)
        let resolver = makeResolver(factory: factory, store: store)
        var settings = Settings()
        settings.reasoningBackend = .cloud
        settings.cloudProvider = .anthropic
        _ = await resolver.compose(from: [], settings: settings, locale: .current, requestTimeout: 4) // 1st failure
        _ = await resolver.compose(from: [], settings: settings, locale: .current, requestTimeout: 4) // trips breaker
        // Breaker probes again every 5th tick post-trip; 4 skipped ticks here
        // brings the counter to 4, so the next call below is the 5th tick.
        for _ in 0 ..< 4 {
            _ = await resolver.compose(from: [], settings: settings, locale: .current, requestTimeout: 4)
        }
        factory.next = SucceedingComposer()
        let recovered = await resolver.compose(from: [], settings: settings, locale: .current, requestTimeout: 4)
        #expect(recovered?.backendUsed == .cloud)
        #expect(recovered?.announcement != nil, "recovery must be announced once")
    }

    @Test func resetSessionClearsBreakerState() async {
        let factory = StubFactory()
        factory.next = FailingComposer()
        let store = StubCredentialStore()
        store.save("sk-test", for: .anthropic)
        let resolver = makeResolver(factory: factory, store: store)
        var settings = Settings()
        settings.reasoningBackend = .cloud
        settings.cloudProvider = .anthropic
        _ = await resolver.compose(from: [], settings: settings, locale: .current, requestTimeout: 4)
        _ = await resolver.compose(from: [], settings: settings, locale: .current, requestTimeout: 4) // breaker tripped
        resolver.resetSession()
        factory.next = SucceedingComposer()
        let afterReset = await resolver.compose(from: [], settings: settings, locale: .current, requestTimeout: 4)
        #expect(
            afterReset?.announcement == nil,
            "a fresh session must not carry over the previous session's breaker trip/recovery state"
        )
    }
}

/// `ReasoningComposerResolverTests` above tests the resolver against a
/// `StubFactory` and never exercises `LiveNetworkComposerFactory`'s own
/// per-backend routing — these tests close that gap directly.
struct LiveNetworkComposerFactoryTests {
    private let factory: LiveNetworkComposerFactory = .init(
        session: StubURLProtocol.makeSession { _ in
            StubResponse(status: 200, data: Data(), contentType: "application/json")
        },
        requestTimeout: 4, locale: .current
    )

    private func request(
        provider: CloudProvider? = nil, endpointURL: String? = nil,
        modelOverride: String? = nil, credential: String? = nil
    ) -> NetworkComposerRequest {
        NetworkComposerRequest(
            provider: provider, endpointURL: endpointURL, modelOverride: modelOverride,
            credential: credential, detail: .standard
        )
    }

    @Test func onDeviceAlwaysReturnsNil() {
        let result = factory.composer(backend: .onDevice, configuration: request())
        #expect(result == nil)
    }

    @Test func cloudAnthropicWithNoCredentialReturnsNil() {
        let result = factory.composer(backend: .cloud, configuration: request(provider: .anthropic))
        #expect(result == nil)
    }

    @Test func cloudAnthropicWithCredentialReturnsAComposer() {
        let result = factory.composer(
            backend: .cloud, configuration: request(provider: .anthropic, credential: "sk-ant-test")
        )
        #expect(result != nil)
    }

    @Test func cloudOpenAIWithCredentialReturnsAComposer() {
        let result = factory.composer(
            backend: .cloud, configuration: request(provider: .openai, credential: "sk-test")
        )
        #expect(result != nil)
    }

    @Test func cloudNIMWithNoModelReturnsNilEvenWithACredential() {
        let result = factory.composer(
            backend: .cloud, configuration: request(provider: .nvidiaNIM, credential: "nvapi-test")
        )
        #expect(result == nil)
    }

    @Test func cloudNIMWithModelReturnsAComposer() {
        let result = factory.composer(
            backend: .cloud,
            configuration: request(
                provider: .nvidiaNIM, modelOverride: "meta/llama-3.1-8b-instruct", credential: "nvapi-test"
            )
        )
        #expect(result != nil)
    }

    @Test func localEndpointWithNoModelReturnsNil() {
        let result = factory.composer(
            backend: .localEndpoint, configuration: request(endpointURL: "http://192.168.1.20:11434")
        )
        #expect(result == nil)
    }

    @Test func localEndpointWithUrlAndModelReturnsAComposerEvenWithNoCredential() {
        let result = factory.composer(
            backend: .localEndpoint,
            configuration: request(endpointURL: "http://192.168.1.20:11434", modelOverride: "llama3.2")
        )
        #expect(result != nil)
    }

    @Test func localEndpointWithEmbeddedCredentialsURLReturnsNilRatherThanThrowing() {
        let result = factory.composer(
            backend: .localEndpoint,
            configuration: request(endpointURL: "http://user:pass@192.168.1.20:11434", modelOverride: "llama3.2")
        )
        #expect(result == nil, "an invalid endpoint must degrade to not-configured, never propagate a throw")
    }
}
