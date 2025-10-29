import WatchKit

struct WatchHaptics {
    func playClick() {
        WKInterfaceDevice.current().play(.click)
    }

    func playError() {
        WKInterfaceDevice.current().play(.failure)
    }

    func playSuccess() {
        WKInterfaceDevice.current().play(.success)
    }
}
