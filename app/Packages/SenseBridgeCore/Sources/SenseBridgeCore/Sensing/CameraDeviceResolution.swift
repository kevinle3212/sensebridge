@preconcurrency import AVFoundation
import Foundation

/// Resolves which physical capture device to use and which lenses it offers.
///
/// Split out of `CameraSource` because none of it touches the actor's state:
/// these are pure functions of the hardware present, called once during
/// `start()`. Keeping them here leaves `CameraSource` as the session
/// lifecycle and nothing else.
extension CameraSource {
    #if os(iOS)
        /// Preference order for the virtual multi-lens device: widest
        /// constituent coverage first, since more lenses reachable through
        /// one continuous-zoom input beats fewer. `.builtInDualCamera`
        /// (wide + telephoto, no ultra-wide) is deliberately ranked below
        /// `.builtInDualWideCamera` (ultra-wide + wide) for the same reason.
        static let devicePreference: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera, .builtInWideAngleCamera
        ]
    #else
        /// Virtual multi-lens device types (`.builtInTripleCamera` and
        /// friends) don't exist on macOS; a plain Mac webcam only ever
        /// reports as a single wide-angle camera.
        static let devicePreference: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera]
    #endif

    /// Resolves the best available capture device per `devicePreference`,
    /// independent of whatever order `DiscoverySession.devices` happens to
    /// return them in.
    static func discoverDevice() -> AVCaptureDevice? {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: devicePreference, mediaType: .video, position: .back
        )
        for deviceType in devicePreference {
            if let match = discovery.devices.first(where: { $0.deviceType == deviceType }) {
                return match
            }
        }
        return nil
    }

    /// Derives this device's available lenses from its constituent devices.
    /// Falls back to `[.wide]` for a non-virtual device (`constituentDevices`
    /// is documented to return an empty array there) and for any constituent
    /// whose type this package doesn't have a `CameraLens` mapping for.
    static func lenses(for device: AVCaptureDevice) -> [CameraLens] {
        #if os(iOS)
            let constituents = device.constituentDevices.compactMap(lens(for:))
            return constituents.isEmpty ? [.wide] : constituents
        #else
            return [.wide]
        #endif
    }

    #if os(iOS)
        /// Maps one constituent physical camera to the field-of-view name the
        /// rest of the app uses. `nil` for a device type this package has no
        /// `CameraLens` case for, which `lenses(for:)` then drops.
        static func lens(for constituent: AVCaptureDevice) -> CameraLens? {
            switch constituent.deviceType {
            case .builtInUltraWideCamera: .ultraWide
            case .builtInWideAngleCamera: .wide
            case .builtInTelephotoCamera: .telephoto
            default: nil
            }
        }
    #endif
}
