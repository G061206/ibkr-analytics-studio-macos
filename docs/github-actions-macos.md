# GitHub Actions macOS Build

This migration folder includes a macOS CI workflow at:

```text
.github/workflows/macos-build.yml
```

GitHub only detects workflows stored in the repository root `.github/workflows` directory. That means either:

- push `ibkr-analytics-studio-macos` as its own repository, keeping this `.github` folder at the root, or
- move `.github/workflows/macos-build.yml` to the root of the repository that should run the workflow.

## What It Does

- Runs on GitHub-hosted `macos-latest`.
- Prints macOS, Xcode, and Swift versions.
- Runs `npm run check` in `web/`.
- Runs `swift build -v` in `macos/`.

## How To Run

After pushing to GitHub:

1. Open the repository on GitHub.
2. Go to **Actions**.
3. Select **macOS Build**.
4. Click **Run workflow**.

The workflow also runs on pushes to `main` or `master`, and pull requests, but only when files under `web/`, `macos/`, or the workflow itself change.

## Notes

- macOS runner minutes are more expensive than Linux minutes, so the workflow has a 20 minute timeout and cancels older runs on the same branch.
- This validates compilation. It does not yet produce a signed `.app`.
- The next CI step after a successful `swift build` is adding an app bundle packaging job.
