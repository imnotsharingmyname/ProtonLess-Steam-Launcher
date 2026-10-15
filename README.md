# ProtonLess Steam — Launcher Edition

> Steam Play integration for macOS, with an original game-launcher interface.

## A different experience

This is not a recolouring of the original UI. Launcher Edition replaces the split-view/sidebar workflow with a **right-side launcher rail**, an editorial Home screen, a library **card gallery**, a snapshot **vault**, and left-anchored action tiles. Its identity is graphite, coral, and pale orange, with an original portal/play icon.

### Core functions retained

- Steam Play installation, update and repair
- CrossOver runner detection, supported previews and activation/trial **detection**
- Setup of patched CrossOver runners and compatibility tools
- Game prefixes, Run .exe, Finder access, Wine tools, rebuilds and deletions
- Back up game prefixes and manage snapshot files
- CrossOver bottle registry backup
- Restore a *previously saved* CrossOver FirstRunDate preference
- Steam controller permission, update blocking, Valve binary fetches and diagnostics
- macOS Apple Silicon automated app builds and release packaging

To use any advanced operations, select **SETUP** at the bottom of the right navigation rail. The original safety confirmations and detailed diagnostics remain available there. The new home shortcuts for bottle backup and preference restoration run without Terminal but do not manipulate licensing eligibility.

## Build

The repository is created by the accompanying Launch Kit. The source still uses the proven compatibility engine from NotProton, with important internal loader names and SwiftPM resource paths preserved for compatibility.

On macOS with the documented toolchain, build using `make app`, or select **Actions → Build ProtonLess Steam (macOS)**. The release artifact is `ProtonLess-Steam.zip` containing `ProtonLess Steam.app`, minimum macOS 26.0. GitHub builds are ad-hoc signed and not notarized.

The GitHub Actions builder may have additional requirements or third-party dependencies; follow `BUILD_ON_GITHUB.md` before compiling.

## Provenance and licensing

**This project is a derivative of [NotProton-FES](https://github.com/imnotsharingmyname/NotProton-FES) and upstream NotProton.** The launcher UI, layout and artwork are new; the underlying Steam Play engine and runtime integrations are not newly invented. Retained `notproton` internal identifiers are compatibility requirements and do not represent user-facing branding.

`NOTICE`, `LICENSE`, `LICENSE.lsteamclient`, and `LICENSE.steam-shim` are retained, along with third-party copyright/licence information and original source notices. Any distribution must honour their terms. Not affiliated with Valve, CodeWeavers or Epic Games.
