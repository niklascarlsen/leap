// Prints the bundle identifier of the frontmost app.
import AppKit

print(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "none")
