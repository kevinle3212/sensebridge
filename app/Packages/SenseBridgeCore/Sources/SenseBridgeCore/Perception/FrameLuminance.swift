import CoreVideo
import Foundation

/// How bright a camera frame is, for deciding whether the torch would help.
///
/// Live reading needs an answer to "is there enough light on this page?", and
/// the honest answer comes from the frame itself rather than from a proxy like
/// "recognition failed" — recognition also fails on a blank wall in full
/// daylight, and switching a torch on there is a bright light in a bystander's
/// face for no reason.
///
/// Returns a **relative** figure in `0...1`, never lux. The camera's own
/// auto-exposure is already compensating for the scene, so this is a measure of
/// how dark the image the recognizer is being handed looks, which is exactly the
/// question being asked, and it is not evidence about the room.
public enum FrameLuminance {
    /// Below this, live reading offers the torch. Chosen well under the
    /// mid-grey an auto-exposed frame settles at, so a merely dim page does not
    /// trip it — the failure to avoid is a torch that flicks on and off as the
    /// user's hand shifts.
    public static let dimThreshold = 0.18

    /// Mean relative luminance of `buffer`, or `nil` when the pixel format is
    /// one this cannot read.
    ///
    /// `nil` means "could not measure", as everywhere else in this package —
    /// never "the frame is dark". A caller that treats an unreadable format as
    /// darkness would switch the torch on permanently on any device whose
    /// capture format changes.
    ///
    /// Samples a sparse grid rather than every pixel: this runs on every live
    /// frame, and a 12-megapixel full walk would cost more than the text
    /// recognition it is deciding for. The grid is deterministic, so the same
    /// frame always measures the same.
    ///
    /// - Parameters:
    ///   - buffer: A frame from `AVCaptureVideoDataOutput`.
    ///   - samplesPerAxis: How many points to read along each axis.
    public static func averageLuminance(of buffer: CVPixelBuffer, samplesPerAxis: Int = 32) -> Double? {
        let format = CVPixelBufferGetPixelFormatType(buffer)
        guard CVPixelBufferLockBaseAddress(buffer, .readOnly) == kCVReturnSuccess else { return nil }
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }

        return switch format {
        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange:
            lumaPlaneAverage(of: buffer, samplesPerAxis: samplesPerAxis, isVideoRange: false)
        case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
            lumaPlaneAverage(of: buffer, samplesPerAxis: samplesPerAxis, isVideoRange: true)
        case kCVPixelFormatType_32BGRA:
            bgraAverage(of: buffer, samplesPerAxis: samplesPerAxis)
        default:
            nil
        }
    }

    /// What a frame's brightness says about whether added light would help.
    ///
    /// Three cases rather than an optional `Bool`, because the third one is the
    /// whole point: "could not be measured" is a different claim from "not
    /// dark", and a caller that collapses them would either leave the torch on
    /// permanently or never switch it on at all.
    public enum Brightness: Sendable, Equatable {
        /// Dark enough that added light would plausibly help.
        case dim
        /// Bright enough that added light would not.
        case adequate
        /// Brightness could not be measured — an unreadable pixel format, not a
        /// dark room.
        case unmeasured
    }

    /// How bright `buffer` is, in the terms a torch decision needs.
    public static func brightness(of buffer: CVPixelBuffer) -> Brightness {
        guard let luminance = averageLuminance(of: buffer) else { return .unmeasured }
        return luminance < dimThreshold ? .dim : .adequate
    }

    /// Mean of the Y plane of a biplanar YCbCr buffer.
    ///
    /// - Parameter isVideoRange: Whether 16...235 encodes black to white, as
    ///   the video-range formats do. Ignoring this would report a video-range
    ///   black frame as 6% grey and a full-range one as 0%, which straddles the
    ///   threshold and would make the torch's behaviour depend on a capture
    ///   format the user never chose.
    private static func lumaPlaneAverage(
        of buffer: CVPixelBuffer,
        samplesPerAxis: Int,
        isVideoRange: Bool
    ) -> Double? {
        guard let base = CVPixelBufferGetBaseAddressOfPlane(buffer, 0) else { return nil }
        let width = CVPixelBufferGetWidthOfPlane(buffer, 0)
        let height = CVPixelBufferGetHeightOfPlane(buffer, 0)
        let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(buffer, 0)
        guard width > 0, height > 0 else { return nil }
        let pixels = base.assumingMemoryBound(to: UInt8.self)

        var total = 0.0
        var count = 0
        for (column, row) in grid(width: width, height: height, samplesPerAxis: samplesPerAxis) {
            total += Double(pixels[row * bytesPerRow + column])
            count += 1
        }
        guard count > 0 else { return nil }
        let mean = total / Double(count)
        return isVideoRange
            ? min(max((mean - 16) / (235 - 16), 0), 1)
            : mean / 255
    }

    /// Mean Rec. 709 luma of a 32-bit BGRA buffer.
    private static func bgraAverage(of buffer: CVPixelBuffer, samplesPerAxis: Int) -> Double? {
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        guard width > 0, height > 0 else { return nil }
        let pixels = base.assumingMemoryBound(to: UInt8.self)

        var total = 0.0
        var count = 0
        for (column, row) in grid(width: width, height: height, samplesPerAxis: samplesPerAxis) {
            let offset = row * bytesPerRow + column * 4
            let blue = Double(pixels[offset])
            let green = Double(pixels[offset + 1])
            let red = Double(pixels[offset + 2])
            total += 0.2126 * red + 0.7152 * green + 0.0722 * blue
            count += 1
        }
        guard count > 0 else { return nil }
        return total / Double(count) / 255
    }

    /// Deterministic sample coordinates spread across the frame.
    private static func grid(width: Int, height: Int, samplesPerAxis: Int) -> [(Int, Int)] {
        let steps = max(1, min(samplesPerAxis, min(width, height)))
        return (0 ..< steps).flatMap { row in
            (0 ..< steps).map { column in
                (column * width / steps, row * height / steps)
            }
        }
    }
}
