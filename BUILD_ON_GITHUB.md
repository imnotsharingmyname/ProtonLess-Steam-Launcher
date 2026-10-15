# ProtonLess Steam — build a macOS app with GitHub Actions

This is the **source project**, not a precompiled `.app`. It uses a Swift Package Manager package (`app/Package.swift`) and a project-level `Makefile`; no `.xcodeproj` is required. The GitHub Actions builder runs on an **Apple Silicon `xcode-27` runner**, builds the native NotProton components and the SwiftUI application, verifies the bundle, and publishes a downloadable ZIP artifact.

## Easiest method: double-click the GitHub builder (.command)

1. Extract the full ProtonLess Steam source ZIP on your Mac.
2. Double-click **`Build ProtonLess Steam.command`** inside the project folder. If macOS blocks opening the downloaded script, use Finder **Control-click → Open** (only if you trust this code); if needed, run `chmod +x "Build ProtonLess Steam.command"` from Terminal.
3. If GitHub CLI is not installed, the script offers to install it via Homebrew, or you can run `brew install gh`. It will guide you through `gh auth login --web` the first time.
4. On first use, it can initialize a local Git repo and create a **private** `ProtonLess-Steam` repo on your GitHub account (or connect to an existing repo). It will **show and ask permission** before committing/pushing the source.
5. The script triggers `.github/workflows/app.yml`, displays the status of the cloud build, downloads the specific successful build, and extracts **`ProtonLess Steam.app`** into `~/Downloads/ProtonLess-Steam-Builds/<run-id>/`. It opens Finder at the resulting app.

The app is built **on GitHub's macOS runner**, not on your Mac. You must have an internet connection and a GitHub account; new private GitHub Actions builds may count against your account's included minutes/billing. The source is uploaded to the repository **only after your confirmation**. The command does not bypass GitHub authentication, Gatekeeper, or macOS signing requirements.

**Alternative: build manually on GitHub without the `.command` launcher:**

## 1. Create a GitHub repository

Create an **empty** GitHub repository, for example `ProtonLess-Steam` (no generated README or `.gitignore`). Extract this source ZIP, then open Terminal inside its **ProtonLess-Steam** folder and run (substitute your real GitHub username):

```bash
git init -b main
git add .
git commit -m "Build ProtonLess Steam macOS app"
git remote add origin https://github.com/YOUR-USERNAME/ProtonLess-Steam.git
git push -u origin main
```

This code includes the original NotProton license and attribution. Check the license and third-party notices before distributing the fork.

## 2. Build and download the macOS app

1. On your GitHub repository, open **Actions → Build ProtonLess Steam (macOS)**.
2. Select **Run workflow** on the `main` branch. A push to `main` also triggers this build.
3. Once the build completes successfully, open that workflow run's **Artifacts** section.
4. Download **ProtonLess-Steam-macOS-Apple-Silicon**, then extract the artifact to get **ProtonLess-Steam.zip**.
5. Extract the inner ZIP to get **ProtonLess Steam.app**. Move the app to `/Applications` if desired.

GitHub builds must have network access to install `mingw-w64`, `bison`, `flex` and retrieve the pinned Dobby source, Wine components, and Swift package dependencies. Compilation can fail due to changes in third-party dependencies or runner images; check the workflow log if it does.

### Requirements

- **Architecture:** Apple Silicon (arm64; e.g. M1, M2, M3, M4, M5).
- **Minimum macOS:** 26.0 as declared by the existing app's Swift package and Info.plist.
- **Signing:** ad hoc (`codesign -s -`). **Not Apple Developer ID signed, not notarized.** Gatekeeper may flag the downloaded app; only open builds you trust using macOS's documented **Privacy & Security → Open Anyway** flow. Do not disable Gatekeeper system-wide.
- **Sandbox:** not enabled in this project. The bundled `/bin/bash` bottle-backup script runs with the launching user's normal filesystem permissions.
- **CrossOver license:** this fork does not activate or extend a CrossOver trial; it preserves the existing trial-state detection logic.

## 3. Optional GitHub Releases

For a **GitHub Release** with a downloadable `ProtonLess-Steam.zip`, push a version tag **matching `NOTPROTON_VERSION` in `dylib/version.h`**. The initial source version is `1.1.2`.

```bash
git tag v1.1.2
git push origin v1.1.2
```

This triggers **Release ProtonLess Steam**, which calls the same verified macOS builder and attaches the ZIP to a GitHub Release. For later versions, first update `NOTPROTON_VERSION`, commit/push, then tag the corresponding version. The release workflow does **not** delete or rewrite existing tags or releases.

## Updating the fork

`app/Info.plist` uses a distinct bundle ID (`io.protonless.steam`) and display name (`ProtonLess Steam`). The original NotProton internal target names (`NotProtonApp`, its SwiftPM resource bundle, filesystem support paths, helper binaries) remain intact to avoid breaking existing functionality.

The fork **does not use the original author's Sparkle update feed/key**. The **Check for Updates…** menu tells you that updates are unconfigured. To enable a real auto-updater later, set up your own signed appcast and key pair and supply `SUFeedURL` and `SUPublicEDKey` in `app/Info.plist`. A GitHub Release ZIP by itself is **not** a working signed Sparkle update feed.

## Troubleshooting

- If **Actions** is absent, ensure you uploaded the *whole source directory*, including `.github/workflows/app.yml`, and that GitHub Actions is enabled for the repository.
- If the builder fails at **Build the bridge**, check Homebrew/MinGW and fetched Wine-tree logs. The project relies on those third-party components to stage a complete installer; a standalone `swift build` does not create the full deployable app.
- If packaging fails to find `backup_crossover_bottles.sh`, run `make app` from a clean source checkout; the script must be included by SwiftPM as a resource.
- A failed GitHub workflow produces **no valid app artifact**; only download artifacts from a successful run.

### Existing GitHub repository from an earlier attempt

If `Faycalelhandi99/ProtonLess-Steam` (or the equivalent on your account) already exists, the `.command` launcher detects it and asks whether to reuse it. **Do not create another repository.**

If you extracted a fresh ZIP into a new folder, Git will have a separate history. The launcher fetches the existing remote branch and asks before making a merge commit that preserves both histories while using the **source files from the extracted folder** as the new working tree. This can replace files with the same paths in the GitHub repository. The launcher never uses `git push --force`; you can decline at the merge confirmation without changing the GitHub repository.
