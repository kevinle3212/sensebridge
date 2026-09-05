#if canImport(ARKit) && os(iOS)
    import ARKit
    import CoreGraphics
    import CoreVideo
    import Foundation

    /// Splitting one depth frame into left, centre, and right.
    ///
    /// A separate file from `AmbientSensingSource.swift` purely for SwiftLint's
    /// `file_length` gate — `readDepthRegion` is internal rather than `private`
    /// specifically so this same-type extension can reach it.
    public extension AmbientSensingSource {
        /// Takes exactly one depth reading, for `ObstacleAwarenessView`'s
        /// one-shot "Check once" — starts, waits for the first usable frame (or
        /// `timeout`), reads it, and stops, rather than holding the
        /// camera/display-awake assertion the continuous session does.
        ///
        /// Returns a zoned reading rather than a bare distance so a single check
        /// can name a side too; the overall figure inside it is exactly the
        /// number a whole-region reduction would have produced. Every figure is
        /// `nil` when the wait ended with nothing measurable — the same "could
        /// not measure, not nothing is there" contract as ``depthMeters(in:)``.
        /// Throws exactly like ``start()``.
        ///
        /// **Waits for a frame carrying depth, not merely for a frame.** ARKit
        /// vends an `ARFrame` as soon as the camera opens and populates
        /// `sceneDepth` several frames later, so stopping at the first frame
        /// answered a tap with "couldn't take a measurement" perhaps a tenth of
        /// a second before the depth map the user asked for arrived. A hedge is
        /// only honest when the app actually looked. Waiting out the whole
        /// `timeout` costs nothing on a device that cannot produce depth at
        /// all — ``start()`` has already thrown for those.
        ///
        /// That the frame is also *this tap's* rather than the previous one's
        /// is ``AmbientSensingSource/latestFrame(orientation:)``'s guarantee,
        /// not this loop's: `ARSession.currentFrame` outlives a stop/start pair,
        /// and a check answered from the room the user was last in would be
        /// wrong in the way that is hardest to notice.
        func sampleOnce(timeout: Duration = .seconds(3)) async throws -> AwarenessDepthReading {
            try start()
            defer { stop() }
            let deadline = ContinuousClock.now.advanced(by: timeout)
            while ContinuousClock.now < deadline {
                if let frame = latestFrame(), frame.depthMap != nil, frame.depthConfidenceMap != nil {
                    return await zonedDepth(in: frame)
                }
                try await Task.sleep(for: .milliseconds(50))
            }
            return .unmeasured
        }

        /// Reduces `frame`'s depth map both overall and per zone, from one pass
        /// over the same pixels.
        ///
        /// The three zone sub-regions **partition** ``regionOfInterest``, so
        /// their samples concatenated are exactly the samples
        /// ``depthMeters(in:)`` would have walked. The overall figure comes from
        /// that concatenation rather than from a second walk, which is what
        /// makes it identical to the value the alert decision has always used —
        /// see `AwarenessDepthReading` on why that identity matters.
        ///
        /// Everything above the pixel walk — where the zone boundaries fall and
        /// which third is the user's left — lives in `AwarenessZoneGeometry`,
        /// which no platform gate hides from the test suite.
        @concurrent
        nonisolated func zonedDepth(in frame: AmbientFrame) async -> AwarenessDepthReading {
            guard let depthMap = frame.depthMap, let confidenceMap = frame.depthConfidenceMap else {
                return .unmeasured
            }
            let camera = (frame.projection, frame.imageResolution)
            // Zones come from a **wider** strip than the distance does — see
            // `AwarenessZoneGeometry.zoneRegion(measuring:)`. Cut from the
            // region of interest, each zone spanned about 8°, which is less
            // than the yaw of an uncalibrated chest strap; "on your left" was
            // claiming more than the geometry could support.
            var samples = [AwarenessZone: DepthSamples]()
            let zoneRegion = AwarenessZoneGeometry.zoneRegion(measuring: regionOfInterest)
            for (zone, region) in AwarenessZoneGeometry.regions(in: zoneRegion) {
                samples[zone] = Self.readDepthRegion(
                    depthMap: depthMap, confidenceMap: confidenceMap, region: region, camera: camera
                )
            }
            // The distance still comes from the untouched region of interest, so
            // the number the alert threshold acts on is exactly what it was
            // before zones existed.
            let overall = Self.readDepthRegion(
                depthMap: depthMap, confidenceMap: confidenceMap, region: regionOfInterest, camera: camera
            )
            return AwarenessZoneGeometry.reading(
                from: samples, overall: overall, floorClearanceMeters: floorClearanceMeters
            )
        }
    }
#endif
