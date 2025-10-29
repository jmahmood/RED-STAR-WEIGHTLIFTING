import WatchKit

struct WatchHaptics {
    func playSuccess() {
        WKInterfaceDevice.current().play(.success)
    }
}
