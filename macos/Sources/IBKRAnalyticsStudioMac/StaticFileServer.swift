import Foundation
import Network

final class StaticFileServer {
    let root: URL
    let port: UInt16
    let indexURL: URL

    private let listener: NWListener
    private let queue = DispatchQueue(label: "IBKRAnalyticsStudioMac.StaticFileServer")

    private init(root: URL, port: UInt16, listener: NWListener) {
        self.root = root.standardizedFileURL
        self.port = port
        self.indexURL = URL(string: "http://127.0.0.1:\(port)/index.html")!
        self.listener = listener
    }

    static func start(root: URL, preferredPort: UInt16) throws -> StaticFileServer {
        var lastError: Error?

        for offset in 0...20 {
            let port = preferredPort + UInt16(offset)
            do {
                guard let endpointPort = NWEndpoint.Port(rawValue: port) else {
                    continue
                }
                let parameters = NWParameters.tcp
                parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(IPv4Address("127.0.0.1")!), port: endpointPort)
                let listener = try NWListener(using: parameters)
                let server = StaticFileServer(root: root, port: port, listener: listener)
                server.start()
                return server
            } catch {
                lastError = error
            }
        }

        throw lastError ?? NSError(
            domain: "IBKRAnalyticsStudioMac",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Could not start local web server."]
        )
    }

    private func start() {
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection: connection)
        }
        listener.start(queue: queue)
    }

    private func handle(connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16 * 1024) { [weak self] data, _, _, _ in
            guard let self else {
                connection.cancel()
                return
            }

            let response = self.buildResponse(for: data ?? Data())
            connection.send(content: response, completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }

    private func buildResponse(for data: Data) -> Data {
        guard
            let request = String(data: data, encoding: .utf8),
            let firstLine = request.components(separatedBy: "\r\n").first
        else {
            return response(status: "400 Bad Request", contentType: "text/plain; charset=utf-8", body: Data("Bad request".utf8))
        }

        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2 else {
            return response(status: "400 Bad Request", contentType: "text/plain; charset=utf-8", body: Data("Bad request".utf8))
        }

        guard parts[0] == "GET" || parts[0] == "HEAD" else {
            return response(status: "405 Method Not Allowed", contentType: "text/plain; charset=utf-8", body: Data("Method not allowed".utf8))
        }

        if let body = fileBody(for: String(parts[1])) {
            let responseBody = parts[0] == "HEAD" ? Data() : body.data
            return response(status: "200 OK", contentType: body.contentType, body: responseBody)
        }

        return response(status: "404 Not Found", contentType: "text/plain; charset=utf-8", body: Data("Not found".utf8))
    }

    private func fileBody(for rawPath: String) -> (data: Data, contentType: String)? {
        let url = URL(string: rawPath, relativeTo: URL(string: "http://127.0.0.1")!)
        let path = url?.path.removingPercentEncoding ?? "/"
        let relativePath = path == "/" ? "index.html" : String(path.dropFirst())
        let fileURL = root.appendingPathComponent(relativePath).standardizedFileURL

        guard fileURL.path.hasPrefix(root.path + "/") || fileURL.path == root.path else {
            return nil
        }

        guard let data = try? Data(contentsOf: fileURL), !isDirectory(fileURL) else {
            return nil
        }

        return (data, mimeType(for: fileURL.pathExtension))
    }

    private func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return isDirectory.boolValue
    }

    private func response(status: String, contentType: String, body: Data) -> Data {
        var output = Data()
        let header = "HTTP/1.1 \(status)\r\n" +
            "Content-Type: \(contentType)\r\n" +
            "Content-Length: \(body.count)\r\n" +
            "Cache-Control: no-store\r\n" +
            "Connection: close\r\n\r\n"
        output.append(Data(header.utf8))
        output.append(body)
        return output
    }

    private func mimeType(for ext: String) -> String {
        switch ext.lowercased() {
        case "html":
            return "text/html; charset=utf-8"
        case "css":
            return "text/css; charset=utf-8"
        case "js":
            return "text/javascript; charset=utf-8"
        case "svg":
            return "image/svg+xml; charset=utf-8"
        case "json":
            return "application/json; charset=utf-8"
        case "csv":
            return "text/csv; charset=utf-8"
        case "png":
            return "image/png"
        case "ico":
            return "image/x-icon"
        default:
            return "application/octet-stream"
        }
    }
}
