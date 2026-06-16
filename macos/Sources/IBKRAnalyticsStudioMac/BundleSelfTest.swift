import Foundation

enum BundleSelfTest {
    static func run() async throws {
        let webRoot = try ContentLocator.resolveWebRoot()
        try requireFile(webRoot.appendingPathComponent("index.html"))
        try requireFile(webRoot.appendingPathComponent("src/app.js"))
        try requireFile(webRoot.appendingPathComponent("src/parser.js"))
        try requireFile(webRoot.appendingPathComponent("assets/styles.css"))
        try requireFile(webRoot.appendingPathComponent("samples/ibkr-sample-demo.csv"))

        let server = try StaticFileServer.start(root: webRoot, preferredPort: 4187)
        try await assertHTTP(server.indexURL, contains: "<div id=\"app\"></div>")
        try await assertHTTP(server.indexURL.deletingLastPathComponent().appendingPathComponent("src/app.js"), contains: "function canUseNativeFlex")
        try await assertHTTP(server.indexURL.deletingLastPathComponent().appendingPathComponent("samples/ibkr-sample-demo.csv"), contains: "Sample Investor")
        _ = server
    }

    private static func requireFile(_ url: URL) throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
            throw SelfTestError("Missing required bundled file: \(url.path)")
        }
    }

    private static func assertHTTP(_ url: URL, contains expectedText: String) async throws {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw SelfTestError("Expected HTTP 200 for \(url.absoluteString)")
        }

        let text = String(data: data, encoding: .utf8) ?? ""
        guard text.contains(expectedText) else {
            throw SelfTestError("Response for \(url.absoluteString) did not contain expected text.")
        }
    }
}

struct SelfTestError: LocalizedError {
    private let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? {
        message
    }
}
