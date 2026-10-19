import AppKit

extension NSRunningApplication {
    /// The running process of an app that runs once, such as the Dock.
    static func running(_ bundleIdentifier: String) -> NSRunningApplication? {
        runningApplications(withBundleIdentifier: bundleIdentifier).first
    }
}
