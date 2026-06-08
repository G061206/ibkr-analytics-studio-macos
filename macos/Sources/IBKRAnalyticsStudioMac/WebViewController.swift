import AppKit
import Foundation
import WebKit

final class WebViewController: NSViewController, WKScriptMessageHandler, WKNavigationDelegate {
    private let webView: WKWebView
    private let flexClient = FlexApiClient()
    private let updateClient = UpdateClient()

    init() {
        let userContentController = WKUserContentController()
        userContentController.addUserScript(WKUserScript(
            source: Self.bridgeScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = userContentController
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true

        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init(nibName: nil, bundle: nil)

        userContentController.add(self, name: "ibkrNative")
        webView.navigationDelegate = self
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        view = webView
    }

    func load(url: URL) {
        webView.load(URLRequest(url: url))
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "ibkrNative" else {
            return
        }

        let body = message.body
        Task {
            await handleBridgePayload(body)
        }
    }

    private func handleBridgePayload(_ body: Any) async {
        guard
            let payload = body as? [String: Any],
            let type = payload["type"] as? String
        else {
            return
        }

        let requestId = (payload["requestId"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? UUID().uuidString

        switch type {
        case "flex.fetch":
            await handleFlexFetch(payload: payload, requestId: requestId)
        case "app.updateCheck":
            await handleUpdateCheck(requestId: requestId)
        case "app.openExternal":
            handleOpenExternal(payload: payload, requestId: requestId)
        default:
            return
        }
    }

    private func handleFlexFetch(payload: [String: Any], requestId: String) async {
        do {
            let token = payload["token"] as? String ?? ""
            let queryId = payload["queryId"] as? String ?? ""
            let result = try await flexClient.fetchReport(token: token, queryId: queryId)
            postNativeMessage([
                "type": "flex.result",
                "requestId": requestId,
                "ok": true,
                "reportText": result.reportText,
                "contentType": result.contentType,
                "referenceCode": result.referenceCode
            ])
        } catch {
            postNativeMessage([
                "type": "flex.result",
                "requestId": requestId,
                "ok": false,
                "error": error.localizedDescription
            ])
        }
    }

    private func handleUpdateCheck(requestId: String) async {
        do {
            let result = try await updateClient.checkLatest(currentVersion: AppMetadata.version)
            postNativeMessage([
                "type": "app.updateResult",
                "requestId": requestId,
                "ok": true,
                "result": result.asDictionary
            ])
        } catch {
            postNativeMessage([
                "type": "app.updateResult",
                "requestId": requestId,
                "ok": false,
                "error": error.localizedDescription
            ])
        }
    }

    private func handleOpenExternal(payload: [String: Any], requestId: String) {
        guard
            let value = payload["url"] as? String,
            let url = URL(string: value),
            url.scheme == "http" || url.scheme == "https"
        else {
            postNativeMessage([
                "type": "app.openExternalResult",
                "requestId": requestId,
                "ok": false,
                "error": "Only http and https links can be opened."
            ])
            return
        }

        NSWorkspace.shared.open(url)
        postNativeMessage([
            "type": "app.openExternalResult",
            "requestId": requestId,
            "ok": true
        ])
    }

    private func postNativeMessage(_ payload: [String: Any]) {
        guard
            JSONSerialization.isValidJSONObject(payload),
            let data = try? JSONSerialization.data(withJSONObject: payload),
            let json = String(data: data, encoding: .utf8)
        else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.webView.evaluateJavaScript("window.__ibkrNativeDispatch(\(json));")
        }
    }

    private static let bridgeScript = """
    (() => {
      const listeners = new Set();
      window.ibkrNative = {
        postMessage(payload) {
          window.webkit.messageHandlers.ibkrNative.postMessage(payload);
        },
        addEventListener(type, handler) {
          if (type === "message" && typeof handler === "function") listeners.add(handler);
        },
        removeEventListener(type, handler) {
          if (type === "message") listeners.delete(handler);
        }
      };
      window.__ibkrNativeDispatch = (payload) => {
        const event = { data: payload };
        for (const handler of Array.from(listeners)) handler(event);
      };
    })();
    """
}
