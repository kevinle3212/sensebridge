import Foundation
import Testing
@testable import SenseBridgeCore

struct DepthGeometryTests {
    /// A plausible depth map's worth of intrinsics. Exact values do not matter;
    /// the ratios do.
    private static func projection(
        pitchedDownBy pitch: Float = 0,
        focalLength: SIMD2<Float> = .init(200, 200)
    ) -> CameraProjection {
        CameraProjection(
            focalLength: focalLength,
            principalPoint: .init(160, 120),
            // A camera pitched down sees world-up lean backwards, into +Z.
            upInCameraSpace: .init(0, cos(pitch), sin(pitch))
        )
    }

    private static func height(
        depth: Float,
        column: Int = 160,
        row: Int = 120,
        projection: CameraProjection = DepthGeometryTests.projection()
    ) -> Float {
        DepthGeometry.heightRelativeToCamera(
            depthMeters: depth,
            column: column,
            row: row,
            projection: projection
        )
    }

    @Test
    func aSampleOnTheOpticalAxisOfALevelCameraSitsAtTheCameraSHeight() {
        #expect(Self.height(depth: 2.0) == 0)
    }

    @Test
    func lowerRowsOfALevelCameraAreBelowIt() {
        // Image rows grow downward. Getting this flip wrong would place the
        // floor overhead, and every floor sample would survive floor rejection.
        // (120 - 220) * 2.0 / 200 = -1.0
        #expect(Self.height(depth: 2.0, row: 220) == -1.0)
    }

    @Test
    func aCameraPitchedDownSeesTheGroundAheadOfItAsBelowIt() {
        // The chest-mount case: the phone tilts down, so a sample straight
        // ahead on the optical axis is genuinely lower than the camera. This is
        // the whole reason the floor cannot be excluded by a fixed rectangle.
        // -depth * sin(30°) = -2.0 * 0.5
        let height = Self.height(depth: 2.0, projection: Self.projection(pitchedDownBy: .pi / 6))

        #expect(abs(height - -1.0) < 0.0001)
    }

    @Test
    func theSameSampleReadsHigherAsTheMountTiltsBackUp() {
        // Height must track the mount's pitch rather than the pixel's position,
        // because the pixel does not move when the strap loosens.
        let steep = Self.height(depth: 2.0, projection: Self.projection(pitchedDownBy: .pi / 6))
        let shallow = Self.height(depth: 2.0, projection: Self.projection(pitchedDownBy: .pi / 12))

        #expect(steep < shallow)
    }

    @Test
    func reportsNotANumberForSamplesWithNoUsableGeometry() {
        #expect(Self.height(depth: 0).isNaN)
        #expect(Self.height(depth: -1).isNaN)
        #expect(Self.height(depth: .nan).isNaN)
        #expect(Self.height(depth: .infinity).isNaN)
        // A zero focal length would divide by zero rather than trap, producing
        // an infinity that reads as a real height.
        #expect(Self.height(
            depth: 2.0, projection: Self.projection(focalLength: .init(0, 200))
        ).isNaN)
    }

    @Test
    func upInCameraSpaceTakesTheRotationSSecondRow() {
        // Column-major storage means the second *row* is the `y` of each
        // column. Reading the second column instead is the easy mistake, and it
        // would silently pick the camera's own up axis rather than gravity's.
        let up = CameraProjection.upInCameraSpace(
            rotationColumn0: .init(1, 2, 3),
            rotationColumn1: .init(4, 5, 6),
            rotationColumn2: .init(7, 8, 9)
        )

        #expect(up == SIMD3(2, 5, 8))
    }

    @Test
    func aLevelCameraSIdentityRotationYieldsWorldUp() {
        let up = CameraProjection.upInCameraSpace(
            rotationColumn0: .init(1, 0, 0),
            rotationColumn1: .init(0, 1, 0),
            rotationColumn2: .init(0, 0, 1)
        )

        #expect(up == SIMD3(0, 1, 0))
    }

    @Test
    func scalingIntrinsicsOntoASmallerBufferMovesBothFocalLengthAndCentre() {
        // Scaling one without the other tilts the computed ground plane, which
        // reads as a calibration problem rather than as the bug it is.
        let scaled = Self.projection().scaled(by: .init(0.5, 0.25))

        #expect(scaled.focalLength == SIMD2(100, 50))
        #expect(scaled.principalPoint == SIMD2(80, 30))
        #expect(scaled.upInCameraSpace == Self.projection().upInCameraSpace)
    }

    @Test
    func theSameSurfaceMeasuresTheSameHeightAtEitherBufferResolution() {
        // The end-to-end property that makes rescaling correct: a point on the
        // floor is the same distance below the camera whether it was sampled
        // from the full-resolution image or the smaller depth map.
        let full = Self.projection()
        let half = full.scaled(by: .init(0.5, 0.5))

        let atFullResolution = DepthGeometry.heightRelativeToCamera(
            depthMeters: 3.0, column: 200, row: 200, projection: full
        )
        let atHalfResolution = DepthGeometry.heightRelativeToCamera(
            depthMeters: 3.0, column: 100, row: 100, projection: half
        )

        #expect(abs(atFullResolution - atHalfResolution) < 0.0001)
    }
}
