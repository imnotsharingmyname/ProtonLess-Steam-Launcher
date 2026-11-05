# NovaHub — reuse GameSir's published gaming engine components

## Source status (verified 5 November 2026)

The full **GameHub for Mac launcher** source has **not** been publicly released under `gamesir-labs/gamehub-for-mac`. That repository contains only a README and functions as a public issue tracker. Do not present NovaHub as a GameHub fork or copy GameHub branding.

The GameSir Labs organisation DOES publish the following **engine-related source repositories**; using their licensed code is a valid path toward a standalone NovaHub.

| Component | Repository | Pinned revision | Use / scope |
|---|---|---|---|
| Wine (Proton/macOS fork) | https://github.com/gamesir-labs/wine | `316bf39a51ebf599bc755709a441e17539238874` | Potential replacement / patch source for x86_64 Windows API compatibility. Build from source and keep LGPL notices + corresponding source. |
| DXMT GameHub fork | https://github.com/gamesir-labs/dxmt | `98bc4899e0fff63c5956062c62b752581199be7a` | D3D10/11 to Metal graphics backend; LGPL-2.1-or-later. Requires Wine integration, correct DXGI/D3D DLL placement, Wine↔Metal bridging and verified runtime environment. |
| DXVK GameHub fork | https://github.com/gamesir-labs/dxvk | `011706c611dbc34c31e0acd2eca249bc20542e48` | Alternative DirectX to Vulkan, needs Vulkan-on-macOS (e.g. MoltenVK) and compatible GPU / driver; Zlib licence. |
| Rosetta x87 JIT | https://github.com/gamesir-labs/rosettax87_jit | `a34993d909c563012f7f92482832f6e3130ab1df` | Relevant only to specific Rosetta translation paths on Apple Silicon; NOT necessary on the native x86_64 Hackintosh engine. |

## Initial standalone build (NovaHub 0.2)

The starter build bundles **Gcenx Wine Staging 11.21**, not yet GameSir's Wine fork or DXMT. Its dependency is pinned to SHA-256 `d7bcd5abf4df27aae397a7898aef074fea4a2e0b51e0a55aa9659517bbf9d452`. This is a first step toward standalone packaging, not equivalent to GameHub compatibility.

The next integration must be *gated by working macOS hardware tests*, not by the ability to build one component in isolation.

## Integration plan

1. **Smoke-test the bundled executable** on an Intel or AMD Hackintosh: run `wine --version`, `winecfg`, a Windows test executable, verify Wine prefix persists, then game launching and quit lifecycle. Check executable architecture and `otool -L` dependencies.
2. **Build/test GameSir's Wine fork** from its exact revision with a reproducible macOS toolchain. Replace generic Gcenx Wine only after tests pass. Verify the macOS driver is present, that internal runtime paths resolve inside the .app, and that it supports `winemac.so` symbols needed by DXMT.
3. **Build GameSir DXMT against this Wine**, retain LGPL notices and linkable/rebuildable source information; install the DXMT `dxgi`/`d3d11` Windows DLLs correctly inside selected prefixes, and enable native DLL overrides per-game with rollback.
4. **Fallback backend**: WineD3D/OpenGL where appropriate; DXVK + MoltenVK only after proving Vulkan path available on the Hackintosh GPU.
5. **Games**: verify at least two D3D11 programs and representative game settings; measure GPU driver support and crashes. Do not promise D3D12 or anti-cheat compatibility.

## Architecture and licensing cautions

- Native x86_64 Hackintosh Windows game binaries do **not** need Apple Silicon→Intel translation.
- DXMT explicitly treats unlisted GPUs and Hackintoshes as unsupported; Metal 3 support is a prerequisite, not a guarantee.
- Source visibility != licence to bundle the full GameHub application. Use only permissively licensed components or properly satisfy copyleft requirements; preserve notices and offer the corresponding source for binaries distributed.
- Third-party packaged Wine builds may have additional dependency notices. Track them before redistribution.
- No GameSir proprietary game files, cloud services, branding, or login systems are included.

## Upstream documentation

- GameSir project: https://github.com/gamesir-labs
- GameHub issue tracker: https://github.com/gamesir-labs/gamehub-for-mac
- DXMT upstream requirements: https://github.com/3Shain/dxmt/wiki/Device-System-Runtime-Specifications
