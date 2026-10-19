// Dumps the accessibility tree of an app's focused window: ax-dump <bundle-id> [maxDepth]
import AppKit

let bundle = CommandLine.arguments[1]
let maxDepth = CommandLine.arguments.count > 2 ? Int(CommandLine.arguments[2])! : 12
let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundle).first!
let el = AXUIElementCreateApplication(app.processIdentifier)
func attr(_ e: AXUIElement, _ n: String) -> AnyObject? {
    var v: AnyObject?
    AXUIElementCopyAttributeValue(e, n as CFString, &v)
    return v
}
func line(_ e: AXUIElement) -> String {
    var parts: [String] = []
    for n in ["AXRole", "AXSubrole", "AXTitle", "AXDescription", "AXIdentifier"] {
        if let s = attr(e, n) as? String, !s.isEmpty { parts.append("\(n.dropFirst(2))=\(s)") }
    }
    var p = CGPoint.zero
    var s = CGSize.zero
    if let v = attr(e, "AXPosition") { AXValueGetValue(v as! AXValue, .cgPoint, &p) }
    if let v = attr(e, "AXSize") { AXValueGetValue(v as! AXValue, .cgSize, &s) }
    var actions: CFArray?
    AXUIElementCopyActionNames(e, &actions)
    return parts.joined(separator: " ")
        + " @\(Int(p.x)),\(Int(p.y)) \(Int(s.width))x\(Int(s.height)) [\((actions as? [String] ?? []).joined(separator: ","))]"
}
var count = 0
func visit(_ e: AXUIElement, _ d: Int) {
    count += 1
    if count > 400 { return }
    print(String(repeating: "  ", count: d) + line(e))
    if d >= maxDepth { return }
    for c in (attr(e, "AXChildren") as? [AXUIElement] ?? []) { visit(c, d + 1) }
}
visit(attr(el, "AXFocusedWindow") as! AXUIElement, 0)
