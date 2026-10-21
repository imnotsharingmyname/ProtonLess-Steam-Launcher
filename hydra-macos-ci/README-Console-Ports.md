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

## Console Ports interface (new)

The page now uses Hydra's own Sass dark colors (`#121212` background and `#0d0d0d` controls), a constrained responsive grid, and a properly column-oriented flex layout. This fixes the old sideways-scrolling and oversized card issue.

Two tabs partition entries without changing their underlying source:
- **Console Ports · GitHub**: GitHub repositories, latest releases and linked assets.
- **Console Ports · FitGirl & Other Sources**: repack article listings and user-added non-GitHub listings.

### Import a listing and download

In the second tab:
1. Paste a third-party `https://…` **game page URL** and choose **Add game listing**. The game then becomes searchable in the local Console Ports catalogue.
2. To actually download **using Hydra**, enter a title and a **supported download URI**, e.g. a magnet URI or a hoster URL recognized by upstream Hydra's `getDownloadersForUri`, then choose **Download with Hydra**.
3. The feature uses the real `window.electron.startGameDownload` event, with `shop: "custom"`, a unique object ID, the user's configured download directory, and automatic extraction disabled. On success, it opens **Downloads**.

**A web article URL (including `https://fitgirl-repacks.site/bloodborne/`) is not a playable archive or torrent and cannot by itself start a Hydra transfer.** We deliberately do not claim that Hydra can ingest arbitrary page URLs or scrape restricted mirrors. A compatible direct URI must be provided separately. Source permission/ownership remains the user's responsibility.
