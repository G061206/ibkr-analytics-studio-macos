# macOS Migration Checklist

## Done

- Created a separate migration folder.
- Copied the static frontend into `web/`.
- Added `window.ibkrNative` support to the copied frontend only.
- Added SwiftPM scaffold for a macOS AppKit app.
- Added local static HTTP server.
- Added WKWebView bridge.
- Ported Flex API request flow to Swift.
- Ported GitHub release update check to Swift.
- Added unsigned `.app` zip and `.dmg` packaging in GitHub Actions.

## Next

- Compile and fix Swift issues on macOS with `swift build`.
- Decide whether to keep SwiftPM only or generate an Xcode `.xcodeproj`.
- Add app icon resources and `Info.plist`.
- Add signing, hardened runtime, and notarization workflow.
- Test real Flex API fetch with a real IBKR token/query ID.
- Test Apple Silicon and Intel, or produce a universal build.

## Bridge Contract

Frontend to native:

- `flex.fetch`
- `app.updateCheck`
- `app.openExternal`

Native to frontend:

- `flex.result`
- `app.updateResult`
- `app.openExternalResult`

The event shape is intentionally the same as WebView2:

```js
nativeBridge.addEventListener("message", (event) => {
  console.log(event.data);
});
```
