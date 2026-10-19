import os

/// Unified logging. Follow live with:
/// `log stream --level info --predicate 'subsystem == "com.niklascarlsen.leap"'`
enum Log {
    static let app = Logger(subsystem: "com.niklascarlsen.leap", category: "app")
    static let modes = Logger(subsystem: "com.niklascarlsen.leap", category: "modes")
}
