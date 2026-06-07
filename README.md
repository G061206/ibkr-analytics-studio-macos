# IBKR Analytics Studio macOS Migration

This folder is a separate macOS migration workspace. The original `ibkr-analytics-studio-offline` project is treated as read-only.

## Layout

```text
ibkr-analytics-studio-macos/
├─ web/
│  ├─ index.html
│  ├─ assets/
│  ├─ samples/
│  └─ src/
├─ macos/
│  ├─ Package.swift
│  └─ Sources/IBKRAnalyticsStudioMac/
└─ docs/
```

## Current Migration State

- The static web app has been copied into `web/`.
- The copied frontend now supports a platform-neutral native bridge:
  - `window.chrome.webview` for the existing Windows shape.
  - `window.ibkrNative` for the new macOS WKWebView shell.
- The macOS shell scaffold uses Swift/AppKit, `WKWebView`, and a local `127.0.0.1` static server.
- The Swift side includes first-pass ports of the Flex API client and GitHub update checker.

## Develop on macOS

From this folder:

```bash
cd macos
swift run IBKRAnalyticsStudioMac
```

The app resolves web content in this order:

1. `IBKR_WEB_ROOT` environment variable.
2. `../web` from the `macos` folder.
3. `web` from the current folder.
4. `web` bundled in the app resources.

## Verification

From `web/`:

```bash
npm run check
npm run serve
```

From `macos/` on a Mac:

```bash
swift build
swift run IBKRAnalyticsStudioMac
```

Then verify:

- sample report loads with `http://127.0.0.1:4187/?sample=1`
- manual CSV/TXT import works
- Flex API fetch returns CSV through `window.ibkrNative`
- cached Flex report reloads from IndexedDB
- S&P 500 overlay loads
- JSON/PNG export works
- update link opens in the default browser

## Important Notes

- This is a migration scaffold, not a signed `.app` release yet.
- Packaging still needs an Xcode project or app-bundle script, code signing, hardened runtime, and notarization.
- Token storage currently matches the Windows behavior and remains in webview `localStorage`; a later hardening pass can move it to Keychain.
