import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawn } from "node:child_process";
import { parseLaunchOptions } from "../events/helpers/parse-launch-options";

function crossoverWine(): string {
  const candidates = [
    "/Applications/CrossOver.app",
    path.join(os.homedir(), "Applications", "CrossOver.app"),
  ];
  for (const base of candidates) {
    const wine = path.join(base, "Contents", "SharedSupport", "CrossOver", "bin", "wine");
    if (fs.existsSync(wine)) return wine;
  }
  throw new Error("CrossOver is not installed; Windows executables cannot run natively on macOS.");
}
function validBottle(p: string): boolean {
  try {
    return fs.statSync(path.join(p, "drive_c")).isDirectory() &&
      fs.statSync(path.join(p, "system.reg")).isFile();
  } catch { return false; }
}
function resolveBottle(chosen?: string | null): string {
  if (chosen) {
    if (!validBottle(chosen)) throw new Error("Selected CrossOver bottle is invalid.");
    return fs.realpathSync(chosen);
  }
  const root = path.join(os.homedir(), "Library", "Application Support", "CrossOver", "Bottles");
  const bottles = fs.existsSync(root) ?
    fs.readdirSync(root, { withFileTypes: true })
      .filter(entry => entry.isDirectory())
      .map(entry => path.join(root, entry.name))
      .filter(validBottle) : [];
  if (bottles.length !== 1) {
    throw new Error(bottles.length === 0
      ? "Create a CrossOver bottle first, then select it in game options."
      : "Select the correct CrossOver bottle in game options.");
  }
  return bottles[0];
}

export async function launchMacGame(
  executablePath: string,
  launchOptions?: string | null,
  winePrefixPath?: string | null
): Promise<number | null> {
  if (process.platform !== "darwin") throw new Error("Mac game launcher requires macOS");
  if (!path.isAbsolute(executablePath) || !fs.existsSync(executablePath))
    throw new Error("Game executable does not exist");
  const args = parseLaunchOptions(launchOptions).filter(arg => arg !== "%command%");
  const extension = path.extname(executablePath).toLowerCase();
  let command: string;
  let commandArgs: string[];
  let env = { ...process.env };
  let track = false;
  if (extension === ".app" && fs.statSync(executablePath).isDirectory()) {
    command = "/usr/bin/open";
    commandArgs = ["-a", executablePath, ...(args.length ? ["--args", ...args] : [])];
  } else if (extension === ".exe" && fs.statSync(executablePath).isFile()) {
    const bottle = resolveBottle(winePrefixPath);
    command = crossoverWine();
    commandArgs = [executablePath, ...args];
    env = {
      ...env,
      CX_BOTTLE: path.basename(bottle),
      CX_BOTTLE_PATH: path.dirname(bottle),
      WINEPREFIX: bottle,
      CX_ROOT: path.dirname(path.dirname(command)),
      PATH: path.dirname(command) + ":" + (env.PATH ?? "/usr/bin:/bin"),
    };
  } else if (fs.statSync(executablePath).isFile() &&
             ![".msi", ".bat", ".cmd", ".dll", ".dmg"].includes(extension)) {
    fs.accessSync(executablePath, fs.constants.X_OK);
    command = executablePath;
    commandArgs = args;
    track = true;
  } else {
    throw new Error("Unsupported executable type for macOS");
  }
  return new Promise((resolve, reject) => {
    const child = spawn(command, commandArgs, {
      cwd: path.dirname(executablePath),
      env, shell: false, detached: extension !== ".app", stdio: "ignore",
    });
    let done = false;
    const complete = (error?: Error) => {
      if (done) return;
      done = true;
      if (error) reject(error);
      else resolve(track ? child.pid ?? null : null);
    };
    child.once("error", complete);
    if (extension === ".app") child.once("close", code => {
      if (code === 0) complete(); else complete(new Error("LaunchServices failed (exit " + code + ")"));
    });
    else child.once("spawn", () => { child.unref(); complete(); });
  });
}
