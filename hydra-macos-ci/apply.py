#!/usr/bin/env python3
"""Apply the experimental Hydra macOS launcher overlay (anchored, fail-closed)."""
from pathlib import Path
import shutil
import sys

root = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path.cwd()
here = Path(__file__).resolve().parent
changes = {}
def patch(name, substitutions):
    p = root / name
    data = p.read_text(encoding="utf8")
    for old, new in substitutions:
        if old not in data:
            if new in data:
                continue
            raise RuntimeError(f"Upstream anchor changed: {name}: {old[:100]}")
        if data.count(old) != 1:
            raise RuntimeError(f"Ambiguous source anchor: {name}")
        data = data.replace(old, new, 1)
    changes[p] = data

patch("src/main/helpers/launch-game.ts", [
 ('import { shell } from "electron";',
  'import { shell } from "electron";\nimport { launchMacGame } from "./mac-game-launcher";'),
 ('''  if (process.platform !== "linux") {
    return launchNatively(parsedPath, launchOptions, useMangohud, useGamemode);
  }''',
 '''  if (process.platform === "darwin") {
    const game = await gamesSublevel.get(gameKey);
    try {
      const pid = await launchMacGame(parsedPath, launchOptions, game?.winePrefixPath);
      if (pid !== null) launchedGamePids.set(gameKey, pid);
      return pid;
    } catch (error) {
      logger.error("macOS game launch failed", error);
      clearCloudSaveLaunchGuard(objectId, shop);
      WindowManager.closeGameLauncherWindow();
      throw error;
    }
  }
  if (process.platform !== "linux") {
    return launchNatively(parsedPath, launchOptions, useMangohud, useGamemode);
  }'''),
])
patch("src/main/services/native-addon.ts", [
 ("""const value = platform === 'win32'
      ? proc.exe
      : path.join(proc.cwd || '', proc.name || '');""",
  """const value = platform === 'win32' || platform === 'darwin'
      ? (proc.exe || path.join(proc.cwd || '', proc.name || ''))
      : path.join(proc.cwd || '', proc.name || '');""")
])
patch("src/main/services/process-watcher.ts", [
 ('import path from "node:path";',
  'import path from "node:path";\nimport { resolveMacAppBundleExecutable } from "./emulators/macos-app-bundle";'),
 ('''      const executable = matchPath
        .slice(matchPath.lastIndexOf(platform === "win32" ? "\\\\" : "/") + 1)
        .toLowerCase();

      if (processMap.get(executable)?.has(matchPath)) return true;''',
  '''      const processPath = platform === "darwin"
        ? (resolveMacAppBundleExecutable(matchPath) ?? matchPath)
        : matchPath;
      const executable = processPath
        .slice(processPath.lastIndexOf(platform === "win32" ? "\\\\" : "/") + 1)
        .toLowerCase();

      if (processMap.get(executable)?.has(processPath)) return true;''')
])
patch("src/main/services/wine.ts", [
 ('''    if (process.platform !== "linux") {
      return null;
    }

    return path.join(SystemPath.getPath("userData"), "wine-prefixes");''',
  '''    if (process.platform === "darwin") {
      return path.join(SystemPath.getPath("home"),
        "Library", "Application Support", "CrossOver", "Bottles");
    }
    if (process.platform !== "linux") return null;
    return path.join(SystemPath.getPath("userData"), "wine-prefixes");''')
])
patch("src/shared/constants.ts", [
 ('export const DARWIN_GAME_EXECUTABLE_EXTENSIONS = ["app"];',
  'export const DARWIN_GAME_EXECUTABLE_EXTENSIONS = ["app", "exe", "command"];')
])
patch("src/renderer/src/helpers.ts", [
 ('    filters = [{ name: "Application", extensions: ["app"] }];',
  '    filters = [{ name: "Mac or Windows game", extensions: ["app", "exe", "command"] }];')
])
patch("src/renderer/src/components/sidebar/sidebar-adding-custom-game-modal.tsx", [
 ('''    const { filePaths } = await window.electron.showOpenDialog({
      properties: ["openFile"],
      filters,
    });''',
  '''    const { filePaths } = await window.electron.showOpenDialog({
      properties: window.electron.platform === "darwin"
        ? ["openFile", "openDirectory"] : ["openFile"],
      filters,
    });''')
])
patch("src/renderer/src/pages/game-details/modals/game-options-modal.tsx", [
 ('''if (!visible || globalThis.window.electron.platform !== "linux") {
      setDefaultWinePrefixPath(null);''',
  '''if (!visible || !["linux", "darwin"].includes(globalThis.window.electron.platform)) {
      setDefaultWinePrefixPath(null);'''),
 ('''  const shouldShowWinePrefixConfiguration =
    globalThis.window.electron.platform === "linux";
  const defaultHydraWinePrefixPath =
    game.shop !== "epic" && defaultWinePrefixPath''',
  '''  const shouldShowWinePrefixConfiguration =
    ["linux", "darwin"].includes(globalThis.window.electron.platform);
  const defaultHydraWinePrefixPath =
    globalThis.window.electron.platform === "linux" &&
    game.shop !== "epic" && defaultWinePrefixPath''')
])
patch("src/renderer/src/pages/game-details/modals/game-options-modal/compatibility-section.tsx", [
 ('''  return (
    <>
      <div className="game-options-modal__wine-prefix">''',
  '''  if (globalThis.window.electron.platform === "darwin") {
    return (
      <div className="game-options-modal__wine-prefix">
        <div className="game-options-modal__header">
          <h2>CrossOver bottle</h2>
          <h4 className="game-options-modal__header-description">
            Select an existing CrossOver bottle for Windows games.
          </h4>
        </div>
        <TextField value={game.winePrefixPath ?? ""} readOnly theme="dark"
          disabled placeholder="Auto-detect if exactly one bottle exists"
          rightContent={<>
            <Button type="button" theme="outline" onClick={onChangeWinePrefixPath}>
              <FileDirectoryIcon /> Select bottle
            </Button>
            {game.winePrefixPath && (
              <Button type="button" theme="outline" onClick={onClearWinePrefixPath}>Clear</Button>
            )}
          </>}
        />
      </div>
    );
  }
  return (
    <>
      <div className="game-options-modal__wine-prefix">''')
])
# Keep upstream's custom macOS sign hook and ad-hoc sign without a
# Developer ID. This permits local verification but does NOT notarize the app.
patch("scripts/legendary-mac-sign.cjs", [
    ('const path = require("node:path");',
     'const path = require("node:path");\n'
     'const { execFileSync } = require("node:child_process");'),
    ('''    return;
  }
  // Delegate to the same signer''',
     '''    // Sign embedded frameworks and native helpers with an ad-hoc identity.
    execFileSync("/usr/bin/codesign", [
      "--force", "--deep", "--sign", "-", "--timestamp=none",
      "--entitlements",
      path.join(packager.projectDir, "build", "entitlements.mac.plist"),
      options.app,
    ], { stdio: "inherit" });
    execFileSync("/usr/bin/codesign", [
      "--verify", "--deep", "--verbose=2", options.app,
    ], { stdio: "inherit" });
    return;
  }
  // Delegate to the same signer'''),
])
# Allow Electron native modules and its embedded libraries to load.
patch("build/entitlements.mac.plist", [
    ('    <key>com.apple.security.cs.allow-jit</key>',
     '    <key>com.apple.security.cs.disable-library-validation</key>\n'
     '    <true/>\n'
     '    <key>com.apple.security.cs.allow-jit</key>'),
])
# Add a separate, searchable community port catalogue.
patch("src/renderer/src/main.tsx", [
    ('import Catalogue from "./pages/catalogue/catalogue";',
     'import Catalogue from "./pages/catalogue/catalogue";\n'
     'import CommunityPorts from "./pages/community-ports/community-ports";'),
    ('                  <Route path="/catalogue" element={<Catalogue />} />',
     '                  <Route path="/catalogue" element={<Catalogue />} />\n'
     '                  <Route path="/community-ports" element={<CommunityPorts />} />'),
])
patch("src/renderer/src/components/sidebar/routes.tsx", [
    ('  AppsIcon,',
     '  AppsIcon,\n  CodeIcon,'),
    ('''  {
    path: "/library",
    nameKey: "library",
    render: () => <BookIcon />,
  },''',
     '''  {
    path: "/library",
    nameKey: "library",
    render: () => <BookIcon />,
  },
  {
    path: "/community-ports",
    nameKey: "community_ports",
    render: () => <CodeIcon />,
  },'''),
])
patch("src/renderer/src/components/sidebar/sidebar.tsx", [
    ('<span>{t(nameKey)}</span>',
     '<span>{nameKey === "community_ports" ? "Console Ports" : t(nameKey)}</span>'),
])
# Read-only metadata adapter for public repack listing RSS.
patch("src/main/events/index.ts", [
    ('import "./epic";',
     'import "./epic";\nimport "./console-ports-rss";'),
])
patch("src/preload/index.ts", [
    ('  openExternal: (src: string) => ipcRenderer.invoke("openExternal", src),',
     '  openExternal: (src: string) => ipcRenderer.invoke("openExternal", src),\n'
     '  fetchConsolePortsRss: () => ipcRenderer.invoke("getConsolePortsRss"),'),
])
# Fail closed: verify all upstream anchors before writing files.
for p, data in changes.items():
    p.write_text(data, encoding="utf8")
    print("patched", p.relative_to(root))
target = root / "src/main/helpers/mac-game-launcher.ts"
shutil.copyfile(here / "mac-game-launcher.ts", target)
print("installed", target.relative_to(root))
ports_dir = root / "src/renderer/src/pages/community-ports"
ports_dir.mkdir(parents=True, exist_ok=True)
rss_target = root / "src/main/events/console-ports-rss.ts"
shutil.copyfile(here / "console-ports-rss.ts", rss_target)
print("installed", rss_target.relative_to(root))
for name in ("community-ports.tsx", "community-ports.scss"):
    shutil.copyfile(here / name, ports_dir / name)
    print("installed", (ports_dir / name).relative_to(root))
