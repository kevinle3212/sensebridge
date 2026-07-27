import Testing
@testable import SenseBridgeCore

struct CameraConfigurationTests {
    /// The trap this whole type exists to prevent: `1.0` is `.ultraWide` on a
    /// triple camera but `.wide` on a dual camera, so the lens→zoom map can
    /// never be hardcoded — it has to come from the device's own constituents.
    @Test
    func widestConstituentIsAlwaysZoomFactorOne() {
        let triple = CameraConfiguration.zoomFactors(
            constituents: [.ultraWide, .wide, .telephoto],
            switchOverFactors: [2.0, 6.0]
        )
        let dual = CameraConfiguration.zoomFactors(
            constituents: [.wide, .telephoto],
            switchOverFactors: [3.0]
        )

        #expect(triple[.ultraWide] == 1.0)
        #expect(dual[.wide] == 1.0)
    }

    @Test
    func narrowerLensesTakeTheirSwitchOverFactor() {
        let factors = CameraConfiguration.zoomFactors(
            constituents: [.ultraWide, .wide, .telephoto],
            switchOverFactors: [2.0, 6.0]
        )

        #expect(factors[.wide] == 2.0)
        #expect(factors[.telephoto] == 6.0)
    }

    @Test
    func singleLensDeviceReportsOnlyTheWidestFactor() {
        let factors = CameraConfiguration.zoomFactors(constituents: [.wide], switchOverFactors: [])
        #expect(factors == [.wide: 1.0])
    }

    @Test
    func noConstituentsYieldsAnEmptyMap() {
        #expect(CameraConfiguration.zoomFactors(constituents: [], switchOverFactors: [1.0]).isEmpty)
    }

    /// `switchOverFactors` comes from the OS; a short array must degrade to
    /// omitting the lenses it can't place, never trap on an index.
    @Test
    func shortSwitchOverArrayOmitsThePlacelessLenses() {
        let factors = CameraConfiguration.zoomFactors(
            constituents: [.ultraWide, .wide, .telephoto],
            switchOverFactors: [2.0]
        )

        #expect(factors == [.ultraWide: 1.0, .wide: 2.0])
    }

    @Test(arguments: [
        (requested: 0.5, expected: 1.0),
        (requested: 3.0, expected: 3.0),
        (requested: 99.0, expected: 8.0)
    ])
    func zoomIsClampedIntoTheSupportedRange(requested: Double, expected: Double) {
        #expect(CameraConfiguration.clampZoom(requested, min: 1.0, max: 8.0) == expected)
    }

    @Test
    func invertedRangeFallsBackToTheMinimum() {
        #expect(CameraConfiguration.clampZoom(5.0, min: 8.0, max: 1.0) == 8.0)
    }
}
