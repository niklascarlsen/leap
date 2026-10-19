/// Accessibility roles that are worth a hint label in leap mode.
///
/// Containers (windows, groups, lists, tables, scroll areas, web areas) are deliberately
/// excluded: they are not click targets themselves and would bury real controls in labels.
public enum Roles {
    public static let clickable: Set<String> = [
        "AXButton", "AXCheckBox", "AXComboBox", "AXDisclosureTriangle", "AXDockItem",
        "AXIncrementor", "AXLink", "AXMenuBarItem", "AXMenuButton", "AXMenuItem",
        "AXPopUpButton", "AXRadioButton", "AXRow", "AXSlider",
        "AXTabButton", "AXTextArea", "AXTextField", "AXLayoutItem",
    ]
    // Plain AXStaticText is left out on purpose: it is rarely actionable (links are AXLink)
    // and labelling it doubles up on rows, headers and window titles.

    /// Inside an element that already has a label (a row, a button), only these nested
    /// roles get their own label. Text, images and cells there just repeat the parent.
    public static let nestedControls: Set<String> = [
        "AXButton", "AXCheckBox", "AXComboBox", "AXDisclosureTriangle", "AXLink", "AXMenuButton",
        "AXPopUpButton", "AXRadioButton", "AXSlider", "AXTextArea", "AXTextField",
    ]

    /// Roles that are not clickable by role alone but often are by action, e.g. Finder's
    /// icon view items are `AXImage` with `AXOpen`. Only these pay for an action lookup.
    public static let clickableByAction: Set<String> = [
        "AXImage", "AXGroup", "AXCell", "AXUnknown",
    ]
    /// iOS apps on the Mac (Messages, WhatsApp) expose list cells and sidebar items as
    /// `AXStaticText`. AppKit's pressable text is mostly window titles, so this applies only
    /// to UIKit windows.
    public static let clickableByActionInUIKit: Set<String> = ["AXStaticText"]
    public static let clickActions: Set<String> = ["AXPress", "AXOpen", "AXPick", "AXConfirm"]

    /// Roles that, wrapped around other targets, are just containers made focusable or
    /// pressable (web headings, cards, page regions); the targets inside stand for them.
    public static let wrappers: Set<String> = [
        "AXGroup", "AXHeading", "AXCell", "AXUnknown", "AXStaticText", "AXImage",
    ]

    /// Roles whose frame clips what is visible inside them.
    public static let clipping: Set<String> = [
        "AXWindow", "AXSheet", "AXScrollArea", "AXWebArea", "AXPopover",
    ]

    public static let scrollArea = "AXScrollArea"
    public static let webArea = "AXWebArea"
}
