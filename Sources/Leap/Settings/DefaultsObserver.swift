import Foundation

/// Calls `handler` whenever one of `keys` changes in `defaults`, also from another process.
/// Observing stops when the observer is released.
final class DefaultsObserver: NSObject {
    private let defaults: UserDefaults
    private let keys: [String]
    private let handler: @MainActor () -> Void

    init(defaults: UserDefaults, keys: [String], handler: @escaping @MainActor () -> Void) {
        self.defaults = defaults
        self.keys = keys
        self.handler = handler
        super.init()
        for key in keys { defaults.addObserver(self, forKeyPath: key, options: [], context: nil) }
    }

    deinit {
        for key in keys { defaults.removeObserver(self, forKeyPath: key) }
    }

    override func observeValue(
        forKeyPath _: String?, of _: Any?, change _: [NSKeyValueChangeKey: Any]?,
        context _: UnsafeMutableRawPointer?
    ) {
        // Changes from other processes arrive on a background queue.
        let handler = handler
        Task { @MainActor in handler() }
    }
}
