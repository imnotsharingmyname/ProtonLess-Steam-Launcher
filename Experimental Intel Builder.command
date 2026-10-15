#!/bin/bash
# Build the ORIGINAL ProtonLess Steam app/engine for x86_64, not Windows Steam launcher.
set -euo pipefail
cd "$(dirname "$0")"
if [[ $(uname -m) != x86_64 ]]; then
  echo 'This build script must run on your Intel Mac.' >&2
  exit 1
fi
printf '%s\n' 'Building original ProtonLess Steam for Intel / macOS Tahoe.'
if ! xcode-select -p >/dev/null 2>&1; then
  echo 'Install Xcode Command Line Tools (xcode-select --install).' >&2; exit 1
fi
command -v cmake >/dev/null || { echo 'Missing cmake (brew install cmake)' >&2; exit 1; }
command -v brew >/dev/null || { echo 'Homebrew is needed for mingw-w64, bison, flex.' >&2; exit 1; }
if [[ ! -e vendor/dobby/CMakeLists.txt ]]; then
  git clone https://github.com/jmpews/Dobby.git vendor/dobby
  git -C vendor/dobby checkout 5dfc8546954ce3b3198132ab13fddb89ee92cdd7
fi
brew list mingw-w64 >/dev/null 2>&1 || brew install mingw-w64
brew list bison >/dev/null 2>&1 || brew install bison
brew list flex >/dev/null 2>&1 || brew install flex
make ARCH=x86_64 dobby
make ARCH=x86_64 bridge
make ARCH=x86_64 app
bash scripts/verify-fes-app.sh 'out/ProtonLess Steam.app' x86_64
printf '%s\n' 'Built original ProtonLess Steam x86_64 app in out/ProtonLess Steam.app.'
printf '%s\n' 'IMPORTANT: Mac Steam hook functionality is NOT READY: Intel signature profiles are missing.'
printf '%s\n' 'Do not install a game hook using any ARM64 signatures.'
