import Foundation

enum AppVersion {
    static var display: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "26.8.2"
    }

    static var copyright: String { "©CDC \(display)" }
}
