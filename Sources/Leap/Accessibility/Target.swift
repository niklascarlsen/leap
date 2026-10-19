import ApplicationServices

/// Something Leap can label and act on. Frames are in accessibility (top-left origin) coordinates.
struct Target {
    enum Activation {
        /// Click with a synthetic mouse event at the frame center. Works for almost everything.
        case mouse
        /// Perform `AXPress`. Used for system UI such as Mission Control and the Dock.
        case press
        /// Perform `AXPress` and never click: a notification banner may be gone by then, and a
        /// click would land on whatever was under it.
        case pressOnly
    }

    let element: AXUIElement
    let frame: CGRect
    let activation: Activation
    /// The accessibility action Shift performs instead of a right-click: closing a desktop
    /// or a notification.
    var shiftAction: String?
    /// Where the element is drawn as Mission Control starts opening, if it moves into place.
    var appearsFrom: CGRect?
    /// A Dock item, which may still be sliding in while its label is shown.
    var inDock = false
    /// Set for Leap's own status item and window, which Leap cannot ask for their names:
    /// its main thread would wait for itself.
    var name: String?
    /// Presses one of Leap's own controls in-process. A synthetic click does not reach all
    /// of them (toolbar tabs ignore it).
    var pressInProcess: (@MainActor () -> Void)?
}
