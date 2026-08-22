import Foundation

struct ReleaseManifest: Decodable {
    let latestVersion: String
    let minimumSupportedVersion: String
    let releaseURL: URL
    let message: String
}

@MainActor
final class UpdateChecker: ObservableObject {
    enum Status: Equatable {
        case checking
        case current
        case updateAvailable
        case unavailable
    }

    @Published private(set) var status: Status = .checking
    @Published private(set) var manifest: ReleaseManifest?
    @Published var dismissedVersion: String?

    var shouldPresentUpdate: Bool {
        status == .updateAvailable && dismissedVersion != manifest?.latestVersion
    }

    private let manifestURL = URL(string:
        "https://raw.githubusercontent.com/markusciani/ciani-device-control/main/update.json"
    )!

    func check() async {
        status = .checking
        do {
            var request = URLRequest(url: manifestURL)
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            request.timeoutInterval = 12
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                status = .unavailable
                return
            }
            let decoded = try JSONDecoder().decode(ReleaseManifest.self, from: data)
            manifest = decoded
            status = Self.isNewer(decoded.latestVersion, than: AppVersion.display) ? .updateAvailable : .current
        } catch {
            status = .unavailable
        }
    }

    func dismissCurrentNotice() {
        dismissedVersion = manifest?.latestVersion
    }

    private static func isNewer(_ candidate: String, than installed: String) -> Bool {
        let candidateParts = candidate.split(separator: ".").map { Int($0) ?? 0 }
        let installedParts = installed.split(separator: ".").map { Int($0) ?? 0 }
        for index in 0..<max(candidateParts.count, installedParts.count) {
            let lhs = index < candidateParts.count ? candidateParts[index] : 0
            let rhs = index < installedParts.count ? installedParts[index] : 0
            if lhs != rhs { return lhs > rhs }
        }
        return false
    }
}
