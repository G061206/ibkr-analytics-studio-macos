import AppKit
import Foundation

@main
enum Main {
    private static var appDelegate: AppDelegate?

    static func main() async {
        if ProcessInfo.processInfo.environment["IBKR_SELF_TEST"] == "1" {
            await runSelfTest()
            return
        }

        let application = NSApplication.shared
        let delegate = AppDelegate()
        appDelegate = delegate
        application.delegate = delegate
        application.setActivationPolicy(.regular)
        application.run()
    }

    private static func runSelfTest() async {
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
