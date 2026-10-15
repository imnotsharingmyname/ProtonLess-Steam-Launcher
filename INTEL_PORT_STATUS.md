# Original NotProton FES — Intel Steam Play port status

This is an Intel source port of the **original NotProton FES project you supplied**, NOT a standalone Windows Steam / CrossOver launcher.

## Implemented in this draft

- Builds the original SwiftUI `NotProtonApp` for x86_64 instead of arm64.
- Compiles the **real** original `dylib/*.c` hook engine for x86_64 instead of an empty stub (requires pinned Dobby).
- Architecture-specific signature profile selection; rejects loading ARM64 signatures on an Intel process.
- x86 instruction-alignment bounds and basic prologue recognition.
- Guards ARM64-specific Dobby register modification hooks and WebUI instruction decoding; these are disabled on Intel, rather than applying incorrect patches.
- Uses the existing CrossOver Rosetta/x86_64 Wine tool and original bridge source, skipping the ARM64 Wine build on Intel.
- Preserves the original NotProton FES interface, bottle backup, trial *detection*, and existing Steam installer.
- Adds Intel Tahoe (`macos-26-intel`) GitHub Actions build job and read-only Steam diagnostics.

## NOT IMPLEMENTED — critical for game launching

1. **Intel x86_64 Steam signatures** for `steamclient.dylib` and `steamui.dylib`. The supplied archive has ONLY `signatures/macos.arm64/*.json`. These binary signatures cannot be translated without analyzing the exact x86_64 Steam build. Do not copy/rename ARM64 JSON to x86_64.
2. Intel-equivalent prehooks for `GetOSListOverrideForApp.oslist_gate` and `ResolveCompatToolForApp.local_redirect`. These require Intel disassembly and matching Dobby x86_64 register handling or semantic replacement hooks; they are disabled rather than guessing registers.
3. Intel variants of ARM64-specific anchor, WebUI message routing and hooking algorithms, plus end-to-end testing.
4. Native macOS app compilation and runtime smoke tests were **not performed** here; this environment is Linux without macOS SDK or Steam clients. Swift and C builds may need adjustments on your Mac.

**Do not use the Intel app to patch a live Steam client yet**. It may compile and its UI may open but its installer will refuse missing signatures. This is intentional to avoid an unsupported patch that could break Steam. Steam Play games are **not** confirmed to work.

## Getting a base compilation

On an Intel Mac running Tahoe, extract ZIP, run `Build Original NotProton for Intel.command` or use the `build-original-intel.yml` GitHub workflow. This builds the ORIGINAL project. Missing `signatures/macos.x86_64` prevents safely installing the Steam hook, not necessarily building the GUI.

`Intel Steam Diagnostic.command` writes a text report on your Desktop identifying the Steam Intel Mach-O modules needed for porting. It does not modify Steam.

Development next step: develop version-specific x86_64 Steam hook signatures, port architecture-specific prehooks, and test on an isolated Steam installation/bottle before enabling installation.
