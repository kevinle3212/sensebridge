import CoreGraphics
import CoreVideo
import ImageIO
import SenseBridgeCore
import Testing

/// Exercises the camera-frame-to-drawable-image conversion behind the awareness
/// preview.
///
/// Lives in the app test target rather than the package's, because
/// `AmbientSensingSource` is compiled only for iOS (`canImport(ARKit) &&
/// os(iOS)`) and the package's own tests run on macOS. A synthetic
/// `CVPixelBuffer` stands in for ARKit, which delivers no frames in a
/// simulator — that is exactly why the render path needs testing separately
/// from the sensing that feeds it.
struct AmbientPreviewImageTests {
    @MainActor
    @Test
    func rendersALandscapeCameraBufferAsAnUprightPortraitImage() async throws {
        // ARKit hands back landscape frames and portrait apps pass `.right`
        // alongside them. If that orientation were dropped, the preview would
        // be sideways and every outline would land on the wrong thing.
        let frame = try Self.frame(width: 1920, height: 1440, orientation: .right)

        let image = try #require(await AmbientSensingSource().previewImage(for: frame))

        #expect(image.height > image.width)
        #expect(Double(image.width) / Double(image.height) == 0.75)
    }

    @MainActor
    @Test
    func scalesDownToTheRequestedLongestEdge() async throws {
        let frame = try Self.frame(width: 1920, height: 1440, orientation: .right)

        let image = try #require(
            await AmbientSensingSource().previewImage(for: frame, maximumDimension: 640)
        )

        #expect(max(image.width, image.height) == 640)
    }

    @MainActor
    @Test
    func leavesAnImageSmallerThanTheLimitAlone() async throws {
        let frame = try Self.frame(width: 320, height: 240, orientation: .up)

        let image = try #require(
            await AmbientSensingSource().previewImage(for: frame, maximumDimension: 640)
        )

        #expect(image.width == 320)
        #expect(image.height == 240)
    }

    /// Builds an `AmbientFrame` around a blank BGRA pixel buffer of the given
    /// size — enough for the conversion under test, which never inspects the
    /// depth maps.
    private static func frame(
        width: Int,
        height: Int,
        orientation: CGImagePropertyOrientation
    ) throws -> AmbientFrame {
        var buffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            [kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary] as CFDictionary,
            &buffer
        )
        #expect(status == kCVReturnSuccess)
        return try AmbientFrame(
            image: #require(buffer),
            depthMap: nil,
            depthConfidenceMap: nil,
            orientation: orientation,
            projection: CameraProjection(
                focalLength: SIMD2(1, 1),
                principalPoint: SIMD2(0, 0),
                upInCameraSpace: SIMD3(0, 1, 0)
            ),
            imageResolution: CGSize(width: width, height: height),
            capturedAt: .now
        )
    }
}
