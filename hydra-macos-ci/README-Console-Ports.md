# Console Ports — independent Hydra discovery source

The experiment adds a **Console Ports** sidebar page and `#/community-ports` route to Hydra's macOS build. It **does not replace Hydra's Steam/Epic catalogue or its existing user-installed download sources**.

## Sources and refresh behavior

1. **Console Ports Index** — editable JSON at [community-ports-index.json](./community-ports-index.json). Loaded from GitHub on page open and refreshed every **six hours while Hydra is open**. Changes to the index do not require a new DMG.
2. **GitHub release assets** — for each indexed `github.com/OWNER/REPO` project, the page queries GitHub's latest-release API and links to its release and binary assets (if available). These may be launchers/engines rather than standalone copyrighted games.
3. **Public listing metadata** — a read-only Electron-main feed adapter requests `https://fitgirl-repacks.site/feed/`, extracts only posts whose metadata suggests an unofficial console-to-PC port, and links back to the original listing. It does not mirror or parse installers, direct downloads, magnet links or torrents. Feed access is best effort and may fail due to access controls; the status is shown in the page. Bloodborne's supplied listing is in the fallback index.
4. **Custom feeds** — users may add CORS-accessible HTTPS JSON indexes; maximum 20. The built-in index can be augmented with user-added entries and external indexes. Only HTTPS project links are accepted.

Example `ports.json`:

```json
{
  "version": 2,
  "entries": [
    {
      "title": "Example console port",
      "projectUrl": "https://github.com/owner/project",
      "description": "Description of the project and asset requirements",
      "platforms": ["Windows", "PlayStation 2"],
      "origin": "PlayStation 2",
      "buildType": "Source-based port"
    }
  ]
}
```

**Classification is critical**: a `Complete-build listing` label means an external website claims to describe a build; it is **not verification** that a download is legal, functional, safe, or genuinely complete. A `GitHub release` is not automatically a working game: community ports often need an original game dump.

## CI / installation

The workflow installs the overlay before compiling, checks that the Console Ports sidebar link, renderer page and feed adapter exist, then produces an artifact uniquely named `Hydra-macOS-Console-Ports-RUN_NUMBER`.

Install from the **new run's artifact**, not an older `Hydra-macOS-ARM64-experimental` ZIP. Exit Hydra before overwriting the application bundle in `/Applications`; keep the last working build until the new one launches successfully.

The working experiment remains on branch `hydra-macos-ci-experiment`; the `main` branch is unchanged. The app is ad-hoc signed for local testing, not Apple-notarized.
