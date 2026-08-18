import CoreVideo
import Foundation
import Testing
@testable import SenseBridgeCore

struct FrameLuminanceTests {
    /// A buffer of one repeated byte value, in the given format.
    private func buffer(
        format: OSType,
        fill: UInt8,
        width: Int = 64,
        height: Int = 48
    ) throws -> CVPixelBuffer {
        var created: CVPixelBuffer?
        let status = CVPixelBufferCreate(nil, width, height, format, nil, &created)
        #expect(status == kCVReturnSuccess)
        let buffer = try #require(created)

        #expect(CVPixelBufferLockBaseAddress(buffer, []) == kCVReturnSuccess)
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        if CVPixelBufferIsPlanar(buffer) {
            for plane in 0 ..< CVPixelBufferGetPlaneCount(buffer) {
                let base = try #require(CVPixelBufferGetBaseAddressOfPlane(buffer, plane))
                let bytes = CVPixelBufferGetBytesPerRowOfPlane(buffer, plane)
                    * CVPixelBufferGetHeightOfPlane(buffer, plane)
                // Chroma planes are filled too; only the luma plane is read, and
                // leaving chroma uninitialised would make the test's own result
                // depend on whatever was in that memory.
                memset(base, Int32(plane == 0 ? fill : 128), bytes)
            }
        } else {
            let base = try #require(CVPixelBufferGetBaseAddress(buffer))
            memset(base, Int32(fill), CVPixelBufferGetBytesPerRow(buffer) * height)
        }
        return buffer
    }

    @Test
    func measuresAFullRangeLumaPlaneDirectly() throws {
        let mid = try buffer(format: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, fill: 128)

        let luminance = try #require(FrameLuminance.averageLuminance(of: mid))

        #expect(abs(luminance - 128.0 / 255) < 0.01)
    }

    @Test
    func rescalesAVideoRangeLumaPlaneSoBlackReadsAsBlack() throws {
        // 16 is black in video range. Read as full range it would be 6% grey,
        // which sits either side of the dim threshold depending on a capture
        // format the user never chose.
        let black = try buffer(format: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, fill: 16)
        let white = try buffer(format: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, fill: 235)

        #expect(try #require(FrameLuminance.averageLuminance(of: black)) < 0.001)
        #expect(try #require(FrameLuminance.averageLuminance(of: white)) > 0.999)
    }

    @Test
    func clampsAnOutOfRangeVideoRangeSampleRatherThanReportingNegativeLight() throws {
        let belowBlack = try buffer(format: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, fill: 0)

        let luminance = try #require(FrameLuminance.averageLuminance(of: belowBlack))

        #expect(luminance == 0)
    }

    @Test
    func measuresABGRABufferAsWeightedLuma() throws {
        let white = try buffer(format: kCVPixelFormatType_32BGRA, fill: 255)
        let black = try buffer(format: kCVPixelFormatType_32BGRA, fill: 0)

        #expect(try #require(FrameLuminance.averageLuminance(of: white)) > 0.99)
        #expect(try #require(FrameLuminance.averageLuminance(of: black)) < 0.01)
    }

    @Test
    func reportsThatItCouldNotMeasureAnUnknownFormatRatherThanGuessingDarkness() throws {
        // Treating an unreadable format as darkness would leave the torch on
        // permanently on any device whose capture format changes.
        let unsupported = try buffer(format: kCVPixelFormatType_16Gray, fill: 0)

        #expect(FrameLuminance.averageLuminance(of: unsupported) == nil)
        #expect(FrameLuminance.brightness(of: unsupported) == .unmeasured)
    }

    @Test
    func callsADarkFrameDimAndAWellLitOneNot() throws {
        let dark = try buffer(format: kCVPixelFormatType_32BGRA, fill: 20)
        let lit = try buffer(format: kCVPixelFormatType_32BGRA, fill: 200)

        #expect(FrameLuminance.brightness(of: dark) == .dim)
        #expect(FrameLuminance.brightness(of: lit) == .adequate)
    }

    @Test
    func measuresTheSameFrameIdenticallyEveryTime() throws {
        // The sample grid is deterministic, so the torch cannot flicker on a
        // still scene just because two passes happened to read different pixels.
        let frame = try buffer(format: kCVPixelFormatType_32BGRA, fill: 90)

        let first = FrameLuminance.averageLuminance(of: frame)
        let second = FrameLuminance.averageLuminance(of: frame)

        #expect(first == second)
    }

    @Test
    func handlesABufferSmallerThanTheSampleGrid() throws {
        let tiny = try buffer(format: kCVPixelFormatType_32BGRA, fill: 255, width: 2, height: 2)

        #expect(try #require(FrameLuminance.averageLuminance(of: tiny, samplesPerAxis: 32)) > 0.99)
    }
}
