/// Why a shortcut cannot start a mode.
public enum HotKeyProblem: Equatable, Sendable {
    case unsupportedKey
    case needsModifier
    case usedByApps
    case usedByOtherMode
    case usedByMacOS
}
