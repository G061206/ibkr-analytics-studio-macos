import AppKit
import WebKit

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var webController: WebViewController?
    private var staticServer: StaticFileServer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if ProcessInfo.processInfo.environment["IBKR_SELF_TEST"] == "1" {
            Task {
                await runSelfTestAndExit()
            }
            return
        }

        do {
            let webRoot = try ContentLocator.resolveWebRoot()
            let server = try StaticFileServer.start(root: webRoot, preferredPort: 4187)
            staticServer = server

            let controller = WebViewController()
            webController = controller

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1280, height: 860),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "IBKR Analytics Studio"
            window.minSize = NSSize(width: 960, height: 640)
            window.contentViewController = controller
            window.center()
            window.makeKeyAndOrderFront(nil)
            self.window = window

            controller.load(url: server.indexURL)
        } catch {
            showStartupError(error)
            NSApp.terminate(nil)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func showStartupError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Unable to start IBKR Analytics Studio"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .critical
        alert.runModal()
    }

    private func runSelfTestAndExit() async {
        do {
            try await BundleSelfTest.run()
            print("IBKR Analytics Studio self-test passed")
            exit(0)
        } catch {
            fputs("IBKR Analytics Studio self-test failed: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }
}
