import Foundation

enum ContentLocator {
    static func resolveWebRoot() throws -> URL {
        let fileManager = FileManager.default

        if let envRoot = ProcessInfo.processInfo.environment["IBKR_WEB_ROOT"], !envRoot.isEmpty {
            let url = URL(fileURLWithPath: envRoot)
            if fileManager.fileExists(atPath: url.appendingPathComponent("index.html").path) {
                return url
            }
        }

        let current = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        let candidates = [
            current.appendingPathComponent("../web"),
            current.appendingPathComponent("web"),
            Bundle.main.resourceURL?.appendingPathComponent("web")
        ].compactMap { $0?.standardizedFileURL }

        for candidate in candidates {
            if fileManager.fileExists(atPath: candidate.appendingPathComponent("index.html").path) {
                return candidate
            }
        }

        throw NSError(
            domain: "IBKRAnalyticsStudioMac",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Could not find bundled web content. Set IBKR_WEB_ROOT or run from the macos folder."]
        )
    }
}
