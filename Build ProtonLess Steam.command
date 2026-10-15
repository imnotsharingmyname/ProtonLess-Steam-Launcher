#!/bin/bash
# ProtonLess Steam — double-click GitHub macOS builder.
# Runs from the source project's directory. Uses GitHub Actions, not local Xcode.
set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
cd "$PROJECT_DIR"
WORKFLOW="app.yml"
ARTIFACT="ProtonLess-Steam-macOS-Apple-Silicon"

on_exit() {
    local code="$1"
    trap - EXIT
    printf '\n'
    if [ "$code" -eq 0 ]; then
        printf '\033[32mProtonLess Steam GitHub builder completed successfully.\033[0m\n'
    else
        printf '\033[31mBuilder stopped (exit code %s). Read the message above.\033[0m\n' "$code"
    fi
    if [ "${NOTPROTON_NO_PAUSE:-0}" != "1" ] && [ -t 0 ]; then
        printf '\nPress Return to close this window... '
        read -r _unused || true
    fi
    exit "$code"
}
trap 'on_exit $?' EXIT

say() { printf '\n\033[1;36m%s\033[0m\n' "$*"; }
fail() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }
confirm() {
    local answer
    printf '%s [y/N]: ' "$1"
    read -r answer || return 1
    case "$answer" in y|Y|yes|YES|Yes) return 0 ;; *) return 1 ;; esac
}

printf '\n=========================================\n'
printf ' ProtonLess Steam — Build via GitHub\n'
printf '=========================================\n'
printf 'Project: %s\n' "$PROJECT_DIR"

[ -f "app/Package.swift" ] || fail "Place this .command file in the ProtonLess Steam source folder (next to Makefile)."
[ -f ".github/workflows/app.yml" ] || fail "Missing .github/workflows/app.yml. Extract the complete source ZIP first."
command -v git >/dev/null 2>&1 || fail "Git is missing. Install Apple Command Line Tools: xcode-select --install"

if ! command -v gh >/dev/null 2>&1; then
    say "GitHub CLI (gh) is required."
    if command -v brew >/dev/null 2>&1 && confirm "Install GitHub CLI now with Homebrew?"; then
        brew install gh || fail "Homebrew could not install gh. See https://cli.github.com/"
    else
        fail "Install GitHub CLI from https://cli.github.com/ or run 'brew install gh', then reopen this file."
    fi
fi

if ! gh auth status >/dev/null 2>&1; then
    say "Sign in to your GitHub account"
    gh auth login --web || fail "GitHub authentication was not completed."
fi

# Makes Git over HTTPS use the GitHub CLI's credential helper.
if ! gh auth setup-git; then
    printf 'Note: Git credential setup was unsuccessful. Pushing may prompt for authentication.\n'
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    say "Set up a local Git repository"
    confirm "Initialize Git in this source folder?" || fail "No Git repository configured."
    git init -b main
fi

# Source ZIPs and some file-copy methods can strip executable bits. GitHub
# preserves the executable bit from Git, so repair all first-party build helpers
# BEFORE `git status` and the commit/push confirmation.
say "Check executable permissions required by the macOS build"
permissions_fixed=0
for script in \
    bridge/*.sh bridge/pe-info.py \
    lsteamclient/*.sh steam-shim/*.sh \
    ntdll-patch/*.sh \
    dylib/feats/*.sh dylib/tests/*.sh \
    scripts/*.sh \
    app/Sources/NotProtonApp/Resources/*.sh; do
    [ -f "$script" ] || continue
    if [ ! -x "$script" ]; then
        chmod +x "$script" || fail "Could not make $script executable."
        printf 'Fixed: %s\n' "$script"
        permissions_fixed=$((permissions_fixed + 1))
    fi
done
if [ "$permissions_fixed" -eq 0 ]; then
    printf 'All first-party build scripts already have executable permission.\n'
else
    printf 'Repaired %s script(s); these Git mode changes will be committed after your confirmation.\n' "$permissions_fixed"
fi

# Never publish unreviewed local files without asking. Initial source will also be
# committed here; .gitignore excludes compiled outputs and scratch directories.
if [ -n "$(git status --porcelain)" ]; then
    say "Files waiting to be committed"
    git status --short
    printf '\nInspect the list above for private files before continuing.\n'
    confirm "Commit ALL these files and push them to your GitHub repository?" || fail "Nothing uploaded. Commit your changes manually and rerun."
    git add -A
    if ! git diff --cached --quiet; then
        git commit -m "Update ProtonLess Steam macOS builder" || fail "Git commit failed. Configure git user.name and user.email, then retry."
    fi
fi

branch="$(git branch --show-current)"
[ -n "$branch" ] || fail "Cannot determine Git branch. Check out 'main' and retry."

if ! git remote get-url origin >/dev/null 2>&1; then
    say "Choose a GitHub repository"
    account="$(gh api user --jq .login)" || fail "Unable to identify your GitHub account."
    default_repo="${account}/ProtonLess-Steam"

    # A new ZIP extracted into a fresh folder has no Git remote, even if the
    # same GitHub repository was created in a previous build attempt.
    if gh repo view "$default_repo" >/dev/null 2>&1; then
        printf 'Found your EXISTING GitHub repository: https://github.com/%s\n' "$default_repo"
        if confirm "Reuse this existing repository instead of creating another?"; then
            git remote add origin "https://github.com/${default_repo}.git"
        else
            printf 'Enter another existing repository OWNER/REPO (or blank to cancel): '
            read -r existing_repo || fail "No repository chosen."
            case "$existing_repo" in
                */*) ;;
                *) fail "Expected OWNER/REPO, e.g. myusername/ProtonLess-Steam." ;;
            esac
            gh repo view "$existing_repo" >/dev/null || fail "The requested GitHub repository was not accessible."
            git remote add origin "https://github.com/${existing_repo}.git"
        fi
    else
        printf 'No existing %s repository was found.\n' "$default_repo"
        if confirm "Create a NEW PRIVATE repository with that name?"; then
            gh repo create "$default_repo" --private --source=. --remote=origin || fail "Could not create this repository. Check GitHub permissions."
        else
            printf 'Enter an existing repository OWNER/REPO (or blank to cancel): '
            read -r existing_repo || fail "No repository chosen."
            case "$existing_repo" in
                */*) ;;
                *) fail "Expected OWNER/REPO, e.g. myusername/ProtonLess-Steam." ;;
            esac
            gh repo view "$existing_repo" >/dev/null || fail "The requested GitHub repository was not accessible."
            git remote add origin "https://github.com/${existing_repo}.git"
        fi
    fi
fi

repo="$(gh repo view --json nameWithOwner --jq .nameWithOwner)" || fail "The Git 'origin' remote is not an accessible GitHub repository."
remote="$(git remote get-url origin)"

# Reusing an existing repo from a NEWLY EXTRACTED ZIP requires reconciling two
# histories. Otherwise `git push` fails with non-fast-forward. Never force-push.
say "Check the existing GitHub branch"
remote_exists=0
if git ls-remote --exit-code --heads origin "refs/heads/${branch}" >/dev/null 2>&1; then
    remote_exists=1
else
    lookup_exit=$?
    [ "$lookup_exit" -eq 2 ] || fail "Unable to check the GitHub branch (git exit ${lookup_exit})."
fi
if [ "$remote_exists" -eq 1 ]; then
    remote_ref="refs/remotes/origin/${branch}"
    git fetch --no-tags origin "refs/heads/${branch}:${remote_ref}" || fail "Unable to download existing GitHub history."
    if ! git merge-base --is-ancestor "$remote_ref" HEAD; then
        if git merge-base HEAD "$remote_ref" >/dev/null 2>&1; then
            printf '\nThe GitHub branch has commits that this local folder does not have.\n'
            confirm "Merge the GitHub changes into this project before building?" || fail "Cancelled to protect existing GitHub changes."
            git merge --no-edit "$remote_ref" || fail "Merge conflict. Resolve it in Git, then restart the builder. No force push was attempted."
        else
            printf '\nThis extracted folder and GitHub were initialized as SEPARATE Git histories.\n'
            printf 'To avoid deleting the previous GitHub history, the builder can create\n'
            printf 'a merge commit that keeps the SOURCE FILES FROM THIS LOCAL FOLDER.\n'
            printf 'Existing GitHub source files with the same paths may be replaced;\n'
            printf 'your earlier GitHub commits remain in the repository history.\n'
            confirm "Merge the histories and use THIS folder's source for the next build?" || fail "Cancelled. No GitHub history was changed."
            git merge --allow-unrelated-histories -s ours --no-edit "$remote_ref" || fail "Could not safely merge histories. No force push was attempted."
        fi
    fi
fi

sha="$(git rev-parse HEAD)"
say "Upload source to GitHub"
printf 'Repository: %s\nRemote: %s\nBranch: %s\nCommit: %s\n' "$repo" "$remote" "$branch" "$sha"
confirm "Push this branch to GitHub and start a cloud build?" || fail "Cancelled; no build started."
git push -u origin "$branch" || fail "Push failed. Check repository permissions and branch protection. No force push was attempted."

say "Find GitHub Actions build workflow"
# Newly pushed workflows may take a few seconds to appear via GitHub's API.
found_workflow=0
for _attempt in 1 2 3 4 5 6; do
    if gh workflow view "$WORKFLOW" --repo "$repo" >/dev/null 2>&1; then
        found_workflow=1
        break
    fi
    sleep 3
done
[ "$found_workflow" -eq 1 ] || fail "GitHub does not see ${WORKFLOW}. Check the Actions tab and enable workflows for this repository."

# Remember the latest run for this exact event/commit before dispatch, so an
# unrelated push-triggered run is not accidentally downloaded.
find_run() {
    gh run list --repo "$repo" --workflow "$WORKFLOW" \
        --branch "$branch" --commit "$sha" --event workflow_dispatch \
        --limit 20 --json databaseId --jq '.[0].databaseId // empty' 2>/dev/null || true
}
before_run="$(find_run)"
say "Trigger macOS build on GitHub"
dispatch_output="$(gh workflow run "$WORKFLOW" --repo "$repo" --ref "$branch" 2>&1)" || fail "GitHub refused to start the workflow: ${dispatch_output}"
printf '%s\n' "$dispatch_output"

run_id="$(printf '%s\n' "$dispatch_output" | sed -nE 's@.*github.com/[^/]*/[^/]*/actions/runs/([0-9]+).*@\1@p' | head -n 1)"
if [ -z "$run_id" ]; then
    for _attempt in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24; do
        candidate="$(find_run)"
        if [ -n "$candidate" ] && [ "$candidate" != "$before_run" ]; then
            run_id="$candidate"
            break
        fi
        sleep 5
    done
fi
[ -n "$run_id" ] || fail "Build was requested but GitHub did not return a run ID. See https://github.com/${repo}/actions"

say "Watch GitHub build #${run_id}"
printf 'https://github.com/%s/actions/runs/%s\n' "$repo" "$run_id"
if ! gh run watch "$run_id" --repo "$repo" --exit-status --interval 10; then
    printf '\nBuild failed; failed-job logs (when available):\n'
    gh run view "$run_id" --repo "$repo" --log-failed || true
    fail "GitHub could not build ProtonLess Steam. Review the Actions run above."
fi

say "Download finished macOS app"
output_dir="${HOME}/Downloads/ProtonLess-Steam-Builds/${run_id}"
mkdir -p "$output_dir"
gh run download "$run_id" --repo "$repo" --name "$ARTIFACT" --dir "$output_dir" || fail "Couldn't download the app artifact."
zip_file="${output_dir}/ProtonLess-Steam.zip"
[ -s "$zip_file" ] || fail "Expected artifact not found: $zip_file"
/usr/bin/ditto -x -k "$zip_file" "$output_dir" || fail "Couldn't extract ProtonLess Steam.app from the ZIP."
app_path="${output_dir}/ProtonLess Steam.app"
[ -d "$app_path" ] || fail "The downloaded build did not contain ProtonLess Steam.app."
printf '\nSUCCESS! Your macOS app is here:\n%s\n' "$app_path"
printf 'ZIP backup: %s\n' "$zip_file"
printf '\nNote: this app is ad-hoc signed, not Apple notarized. macOS may require Open Anyway.\n'
if command -v open >/dev/null 2>&1; then
    open -R "$app_path" || true
fi
