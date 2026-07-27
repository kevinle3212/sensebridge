import Testing
@testable import SenseBridgeCore

/// Records every message it receives, so tests can assert which channels a
/// `MultiRenderTarget` actually delivered to.
private actor SpyRenderTarget: RenderTarget {
    private(set) var receivedMessages: [OutputMessage] = []

    func render(_ message: OutputMessage) async {
        receivedMessages.append(message)
    }
}

struct MultiRenderTargetTests {
    @Test
    func blindProfileFansOutToSpeechOnly() async {
        let speech = SpyRenderTarget()
        let haptic = SpyRenderTarget()
        let target = MultiRenderTarget(profile: .blind, targets: [.speech: speech, .haptic: haptic])

        await target.render(OutputMessage(text: "hello", signal: .resultReady))

        #expect(await speech.receivedMessages.count == 1)
        #expect(await haptic.receivedMessages.isEmpty)
    }

    @Test
    func deafBlindProfileFansOutToHapticOnly() async {
        let speech = SpyRenderTarget()
        let haptic = SpyRenderTarget()
        let target = MultiRenderTarget(profile: .deafBlind, targets: [.speech: speech, .haptic: haptic])

        await target.render(OutputMessage(text: "hello", signal: .resultReady))

        #expect(await haptic.receivedMessages.count == 1)
        #expect(await speech.receivedMessages.isEmpty)
    }

    @Test
    func deafProfileWithNoCaptionTargetSurfacesTheGapInsteadOfSwallowingIt() {
        let target = MultiRenderTarget(profile: .deaf, targets: [:])
        #expect(target.unsupportedChannels == [.caption])
    }

    @Test
    func fullySupportedProfileReportsNoUnsupportedChannels() {
        let speech = SpyRenderTarget()
        let target = MultiRenderTarget(profile: .blind, targets: [.speech: speech])
        #expect(target.unsupportedChannels.isEmpty)
    }
}
