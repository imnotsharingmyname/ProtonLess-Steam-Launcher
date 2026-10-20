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
# Use electron-builder's native ad-hoc signing path instead of Hydra's
# custom hook, which skips signing without a Developer ID certificate.
# This is only for the experimental unsigned/not-notarized build.
patch("electron-builder.yml", [
    ('mac:\n  sign: scripts/legendary-mac-sign.cjs\n',
     'mac:\n  identity: "-"\n'),
])
# Hardened runtime on Apple Silicon needs this entitlement for Electron's
# embedded frameworks with Apple Team IDs.
patch("build/entitlements.mac.plist", [
    ('    <key>com.apple.security.cs.allow-jit</key>',
     '    <key>com.apple.security.cs.disable-library-validation</key>\n'
     '    <true/>\n'
     '    <key>com.apple.security.cs.allow-jit</key>'),
])
# Fail closed: verify all upstream anchors before writing files.
for p, data in changes.items():
    p.write_text(data, encoding="utf8")
    print("patched", p.relative_to(root))
target = root / "src/main/helpers/mac-game-launcher.ts"
shutil.copyfile(here / "mac-game-launcher.ts", target)
print("installed", target.relative_to(root))
