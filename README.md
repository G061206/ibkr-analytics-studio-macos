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

To create an unsigned app bundle and installer artifacts from the repository root:

```bash
bash macos/scripts/package_app.sh
```

The packaging script creates:

- `dist/IBKRAnalyticsStudio-2.1.8-macos-<arch>-unsigned.zip`
- `dist/IBKRAnalyticsStudio-2.1.8-macos-<arch>-unsigned.dmg`

GitHub Actions builds unsigned artifacts for both Apple Silicon (`ARM64`) and Intel (`X64`) runners.

The packaged app also runs a CI self-test before artifacts are uploaded. The self-test starts the bundled app executable with `IBKR_SELF_TEST=1`, verifies the bundled `web/` files, starts the local server, and fetches the app HTML, JavaScript, and sample CSV through `127.0.0.1`.

Then verify:

- sample report loads with `http://127.0.0.1:4187/?sample=1`
- manual CSV/TXT import works
- Flex API fetch returns CSV through `window.ibkrNative`
- cached Flex report reloads from IndexedDB
- S&P 500 overlay loads
- JSON/PNG export works
- update link opens in the default browser

## Important Notes

- GitHub Actions can now produce an unsigned `.app` zip and `.dmg` artifact.
- Code signing, hardened runtime, and notarization are still needed for a smooth public macOS install experience.
- Token storage currently matches the Windows behavior and remains in webview `localStorage`; a later hardening pass can move it to Keychain.
