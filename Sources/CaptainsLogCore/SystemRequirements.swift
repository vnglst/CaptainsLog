import Foundation
import Metal

/// The supported runtime platform, checked before app state or models are loaded.
/// Memory and storage needs depend on the configured models; there is no fixed
/// RAM or free-space minimum established for every supported configuration.
public enum SystemRequirements {
    public static func unmetRequirements(
        macOSMajorVersion: Int,
        isAppleSilicon: Bool,
        hasMetalDevice: Bool
    ) -> [String] {
        var requirements: [String] = []
        if macOSMajorVersion < 26 {
            requirements.append("macOS 26 or later is required. Update macOS to use CaptainsLog.")
        }
        if !isAppleSilicon {
            requirements.append("An Apple Silicon Mac is required for local transcription and text processing.")
        }
        if !hasMetalDevice {
            requirements.append("A Metal GPU must be available for local text processing. Restart your Mac and try again.")
        }
        return requirements
    }

    public static func currentUnmetRequirements() -> [String] {
        #if arch(arm64)
        let isAppleSilicon = true
        #else
        let isAppleSilicon = false
        #endif
        return unmetRequirements(
            macOSMajorVersion: ProcessInfo.processInfo.operatingSystemVersion.majorVersion,
            isAppleSilicon: isAppleSilicon,
            hasMetalDevice: MTLCreateSystemDefaultDevice() != nil
        )
    }
}
