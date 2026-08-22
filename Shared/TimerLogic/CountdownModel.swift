import Foundation

struct CountdownValue: Equatable {
    let seconds: Int
    var formatted: String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let seconds = seconds % 60
        return hours > 0 ? String(format: "%02d:%02d:%02d", hours, minutes, seconds)
                         : String(format: "%02d:%02d", minutes, seconds)
    }
}

enum CountdownLogic {
    static func remaining(until date: Date, now: Date = .now) -> CountdownValue {
        CountdownValue(seconds: max(0, Int(ceil(date.timeIntervalSince(now)))))
    }
}
