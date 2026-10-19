import ApplicationServices
import CoreGraphics

/// Thin, typed wrappers around the C Accessibility API.
enum AX {
    static func attribute<T>(_ element: AXUIElement, _ name: String, as _: T.Type = T.self) -> T? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
            return nil
        }
        return value as? T
    }

    static func element(_ element: AXUIElement, _ name: String) -> AXUIElement? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success,
            let value, CFGetTypeID(value) == AXUIElementGetTypeID()
        else { return nil }
        return (value as! AXUIElement)
    }

    static func children(_ element: AXUIElement) -> [AXUIElement] {
        attribute(element, kAXChildrenAttribute, as: [AXUIElement].self) ?? []
    }

    /// A short human readable name for logs: the title, else the description, else the identifier.
    static func name(of element: AXUIElement) -> String? {
        let names = attributes(
            element, [kAXTitleAttribute, kAXDescriptionAttribute, kAXIdentifierAttribute])
        let name = names.lazy.compactMap { $0 as? String }.first { !$0.isEmpty }
        return name.map { String($0.prefix(60)).replacing("\n", with: " ") }
    }

    static func setAttribute(_ element: AXUIElement, _ name: String, _ value: AnyObject) {
        AXUIElementSetAttributeValue(element, name as CFString, value)
    }

    @discardableResult
    static func press(_ element: AXUIElement) -> Bool {
        perform(element, kAXPressAction)
    }

    static func perform(_ element: AXUIElement, _ action: String) -> Bool {
        AXUIElementPerformAction(element, action as CFString) == .success
    }

    static func parameterized(_ element: AXUIElement, _ name: String, _ parameter: AnyObject)
        -> AnyObject?
    {
        var value: AnyObject?
        guard
            AXUIElementCopyParameterizedAttributeValue(element, name as CFString, parameter, &value)
                == .success
        else { return nil }
        return value
    }

    /// Reads several attributes in one IPC round trip. Missing attributes come back as nil.
    static func attributes(_ element: AXUIElement, _ names: [String]) -> [AnyObject?] {
        var values: CFArray?
        let result = AXUIElementCopyMultipleAttributeValues(element, names as CFArray, [], &values)
        guard result == .success, let list = values as? [AnyObject], list.count == names.count
        else {
            return Array(repeating: nil, count: names.count)
        }
        return list.map { value in
            if CFGetTypeID(value) == AXValueGetTypeID(),
                AXValueGetType(value as! AXValue) == .axError
            {
                return nil
            }
            return value
        }
    }

    static func point(_ value: AnyObject?) -> CGPoint? {
        guard let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        return AXValueGetValue(value as! AXValue, .cgPoint, &point) ? point : nil
    }

    static func size(_ value: AnyObject?) -> CGSize? {
        guard let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var size = CGSize.zero
        return AXValueGetValue(value as! AXValue, .cgSize, &size) ? size : nil
    }

    static func frame(position: AnyObject?, size: AnyObject?) -> CGRect? {
        guard let origin = point(position), let size = self.size(size) else { return nil }
        return CGRect(origin: origin, size: size)
    }

    static func frame(of element: AXUIElement) -> CGRect? {
        let values = attributes(element, [kAXPositionAttribute, kAXSizeAttribute])
        return frame(position: values[0], size: values[1])
    }
}
