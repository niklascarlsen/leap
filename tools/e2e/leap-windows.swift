// Prints how many on-screen windows Leap owns (overlays are 1 per screen while a mode runs).
import CoreGraphics

let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as! [[String: Any]]
print(list.filter { ($0[kCGWindowOwnerName as String] as? String) == "Leap" }.count)
