import Foundation

final class UpdateClient {
    private let latestReleaseURL = URL(string: "https://api.github.com/repos/G061206/IBKRAnalyticsStudio/releases/latest")!
    private let releasesPageURL = "https://github.com/G061206/IBKRAnalyticsStudio/releases"
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func checkLatest(currentVersion: String) async throws -> UpdateCheckResult {
        var request = URLRequest(url: latestReleaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("IBKRAnalyticsStudio/\(AppMetadata.version) macOS", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

        if statusCode == 404 {
            return UpdateCheckResult.noRelease(currentVersion: currentVersion, releasesPageURL: releasesPageURL)
        }

        guard (200..<300).contains(statusCode) else {
            throw UpdateCheckError("GitHub update check failed with HTTP \(statusCode).")
        }

        let release = try JSONDecoder.releaseDecoder.decode(GitHubRelease.self, from: data)
        guard let latestVersion = normalizeVersion(release.tagName) ?? normalizeVersion(release.name) else {
            throw UpdateCheckError("The latest release does not contain a recognizable version.")
        }

        let preferredAsset = release.assets?
            .filter { !($0.browserDownloadURL ?? "").isEmpty }
            .sorted { lhs, rhs in
                if isPreferredMacAsset(lhs.name) != isPreferredMacAsset(rhs.name) {
                    return isPreferredMacAsset(lhs.name)
                }
                return (lhs.name ?? "") < (rhs.name ?? "")
            }
            .first

        return UpdateCheckResult(
            currentVersion: currentVersion,
            latestVersion: latestVersion,
            updateAvailable: isNewerVersion(latestVersion, than: currentVersion),
            releaseURL: release.htmlURL ?? releasesPageURL,
            downloadURL: preferredAsset?.browserDownloadURL ?? release.htmlURL ?? releasesPageURL,
            assetName: preferredAsset?.name ?? "",
            releaseName: release.name ?? release.tagName ?? latestVersion,
            releaseAvailable: true,
            publishedAt: release.publishedAt
        )
    }

    private func isPreferredMacAsset(_ name: String?) -> Bool {
        let value = name?.lowercased() ?? ""
        return value.hasSuffix(".zip") &&
            (value.contains("macos") || value.contains("darwin")) &&
            (value.contains("universal") || value.contains("arm64") || value.contains("x64"))
    }

    private func isNewerVersion(_ latestVersion: String, than currentVersion: String) -> Bool {
        parseVersion(latestVersion).compare(parseVersion(currentVersion)) == .orderedDescending
    }

    private func parseVersion(_ value: String) -> Version {
        Version(normalizeVersion(value) ?? "0.0.0")
    }

    private func normalizeVersion(_ value: String?) -> String? {
        guard var trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }

        if trimmed.lowercased().hasPrefix("v") {
            trimmed.removeFirst()
        }

        if let dashIndex = trimmed.firstIndex(of: "-") {
            trimmed = String(trimmed[..<dashIndex])
        }

        return trimmed
    }
}

struct UpdateCheckResult {
    let currentVersion: String
    let latestVersion: String
    let updateAvailable: Bool
    let releaseURL: String
    let downloadURL: String
    let assetName: String
    let releaseName: String
    let releaseAvailable: Bool
    let publishedAt: Date?

    static func noRelease(currentVersion: String, releasesPageURL: String) -> UpdateCheckResult {
        UpdateCheckResult(
            currentVersion: currentVersion,
            latestVersion: currentVersion,
            updateAvailable: false,
            releaseURL: releasesPageURL,
            downloadURL: releasesPageURL,
            assetName: "",
            releaseName: "",
            releaseAvailable: false,
            publishedAt: nil
        )
    }

    var asDictionary: [String: Any] {
        var dictionary: [String: Any] = [
            "currentVersion": currentVersion,
            "latestVersion": latestVersion,
            "updateAvailable": updateAvailable,
            "releaseUrl": releaseURL,
            "downloadUrl": downloadURL,
            "assetName": assetName,
            "releaseName": releaseName,
            "releaseAvailable": releaseAvailable
        ]

        dictionary["publishedAt"] = publishedAt.map { ISO8601DateFormatter().string(from: $0) } ?? NSNull()
        return dictionary
    }
}

private struct GitHubRelease: Decodable {
    let tagName: String?
    let name: String?
    let htmlURL: String?
    let publishedAt: Date?
    let assets: [GitHubAsset]?

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case htmlURL = "html_url"
        case publishedAt = "published_at"
        case assets
    }
}

private struct GitHubAsset: Decodable {
    let name: String?
    let browserDownloadURL: String?

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
}

private struct Version {
    private let parts: [Int]

    init(_ value: String) {
        parts = value.split(separator: ".").map { Int($0) ?? 0 }
    }

    func compare(_ other: Version) -> ComparisonResult {
        let count = max(parts.count, other.parts.count)
        for index in 0..<count {
            let lhs = index < parts.count ? parts[index] : 0
            let rhs = index < other.parts.count ? other.parts[index] : 0
            if lhs > rhs { return .orderedDescending }
            if lhs < rhs { return .orderedAscending }
        }
        return .orderedSame
    }
}

private struct UpdateCheckError: LocalizedError {
    private let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? {
        message
    }
}

private extension JSONDecoder {
    static var releaseDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
