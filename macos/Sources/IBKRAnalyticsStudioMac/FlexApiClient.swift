import Foundation

struct FlexFetchResult {
    let reportText: String
    let contentType: String
    let referenceCode: String
}

final class FlexApiClient {
    private let baseURL = URL(string: "https://ndcdyn.interactivebrokers.com/AccountManagement/FlexWebService")!
    private let retryDelays: [UInt64] = [4, 8, 12, 16]
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchReport(token: String, queryId: String) async throws -> FlexFetchResult {
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedQueryId = queryId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedToken.isEmpty else {
            throw FlexApiError("Flex Web Service token is required.")
        }

        guard !trimmedQueryId.isEmpty else {
            throw FlexApiError("Flex Query ID is required.")
        }

        let referenceCode = try await sendRequest(token: trimmedToken, queryId: trimmedQueryId)
        return try await getStatementWithRetry(token: trimmedToken, referenceCode: referenceCode)
    }

    private func sendRequest(token: String, queryId: String) async throws -> String {
        let url = try buildURL(path: "SendRequest", token: token, code: queryId)
        let (data, response) = try await session.data(for: request(url: url))
        let body = decode(data: data, response: response)

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw FlexApiError("IBKR SendRequest failed with HTTP \(statusCode).")
        }

        let status = try FlexXmlStatus.parse(body)
        guard status.isSuccess, let referenceCode = status.referenceCode, !referenceCode.isEmpty else {
            throw FlexApiError(status.userMessage(fallback: "IBKR could not generate the Flex report."))
        }

        return referenceCode
    }

    private func getStatementWithRetry(token: String, referenceCode: String) async throws -> FlexFetchResult {
        for attempt in 0...retryDelays.count {
            let url = try buildURL(path: "GetStatement", token: token, code: referenceCode)
            let (data, response) = try await session.data(for: request(url: url))
            let body = decode(data: data, response: response)
            let httpStatus = (response as? HTTPURLResponse)?.statusCode ?? 0
            let contentType = (response as? HTTPURLResponse)?.mimeType ?? "text/plain"

            if (200..<300).contains(httpStatus), !looksLikeFlexStatus(body) {
                return FlexFetchResult(reportText: body, contentType: contentType, referenceCode: referenceCode)
            }

            let status = looksLikeFlexStatus(body)
                ? try FlexXmlStatus.parse(body)
                : FlexXmlStatus(isSuccess: false, referenceCode: nil, errorCode: "\(httpStatus)", errorMessage: "HTTP \(httpStatus)")

            if !shouldRetry(status: status, httpStatus: httpStatus) || attempt == retryDelays.count {
                throw FlexApiError(status.userMessage(fallback: "IBKR could not retrieve the generated Flex report."))
            }

            try await Task.sleep(nanoseconds: retryDelays[attempt] * 1_000_000_000)
        }

        throw FlexApiError("IBKR report generation did not complete in time. Please try again shortly.")
    }

    private func request(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("IBKRAnalyticsStudio/\(AppMetadata.version) macOS", forHTTPHeaderField: "User-Agent")
        return request
    }

    private func buildURL(path: String, token: String, code: String) throws -> URL {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw FlexApiError("Could not build IBKR Flex URL.")
        }
        components.queryItems = [
            URLQueryItem(name: "t", value: token),
            URLQueryItem(name: "q", value: code),
            URLQueryItem(name: "v", value: "3")
        ]
        guard let url = components.url else {
            throw FlexApiError("Could not build IBKR Flex URL.")
        }
        return url
    }

    private func decode(data: Data, response: URLResponse) -> String {
        if data.starts(with: Data([0xef, 0xbb, 0xbf])) {
            return String(data: Data(data.dropFirst(3)), encoding: .utf8) ?? ""
        }

        if let text = String(data: data, encoding: .utf8) {
            return text
        }

        return String(data: data, encoding: .isoLatin1) ?? ""
    }

    private func looksLikeFlexStatus(_ body: String) -> Bool {
        let text = body.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.localizedCaseInsensitiveContains("<FlexStatementResponse")
    }

    private func shouldRetry(status: FlexXmlStatus, httpStatus: Int) -> Bool {
        if httpStatus >= 500 {
            return true
        }

        return [
            "1001", "1003", "1004", "1005", "1006",
            "1007", "1008", "1009", "1019", "1021"
        ].contains(status.errorCode ?? "")
    }
}

struct FlexXmlStatus {
    let isSuccess: Bool
    let referenceCode: String?
    let errorCode: String?
    let errorMessage: String?

    static func parse(_ xml: String) throws -> FlexXmlStatus {
        do {
            let document = try XMLDocument(xmlString: xml, options: [])
            let root = document.rootElement()
            let status = root?.elements(forName: "Status").first?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let referenceCode = root?.elements(forName: "ReferenceCode").first?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
            let errorCode = root?.elements(forName: "ErrorCode").first?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
            let errorMessage = root?.elements(forName: "ErrorMessage").first?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)

            return FlexXmlStatus(
                isSuccess: status.caseInsensitiveCompare("Success") == .orderedSame,
                referenceCode: referenceCode,
                errorCode: errorCode,
                errorMessage: errorMessage
            )
        } catch {
            throw FlexApiError("IBKR returned an unreadable XML response. \(error.localizedDescription)")
        }
    }

    func userMessage(fallback: String) -> String {
        let code = errorCode ?? ""
        let message = errorMessage ?? ""
        if !code.isEmpty || !message.isEmpty {
            return "IBKR Flex error \(code): \(message)".trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return fallback
    }
}

struct FlexApiError: LocalizedError {
    private let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? {
        message
    }
}
