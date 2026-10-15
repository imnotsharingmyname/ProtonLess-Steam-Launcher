# Restore saved CrossOver FirstRunDate — NotProton FES

The **Restore Settings** button in **Status → CrossOver** executes the bundled
`restore_crossover_first_run_date.sh` with `/bin/bash` using Foundation `Process`.
It runs off the SwiftUI main thread **without opening Terminal** and displays
captured output in a success/failure alert. This is separate from **Backup Bottles**:
that other button backs up the `system.reg` files in CrossOver bottles.

## Requirements

1. Quit CrossOver before clicking **Restore Settings**.
2. The file `~/Desktop/CrossOver_FirstRunDate_Backup.txt` must already exist.
   This feature does **not** create that file. If it contains a date, the script
   writes it to the `com.codeweavers.CrossOver` `FirstRunDate` preference. If it
   is zero bytes, the script deletes the preference key instead.
3. The app needs permission to read the Desktop folder if macOS requests it.
   Check **System Settings → Privacy & Security → Files & Folders** if access
   is denied. With the existing unsandboxed app, no special app-sandbox
   entitlements are needed.

## Build on GitHub

If you already have the GitHub repository, merge the contents of the
`NotProton-FES-Restore-Settings-Update.zip` file into your **existing**
`NotProton-FES` project folder (preserve the hidden `.git` folder), replacing
existing files where prompted. Double-click the existing
`Build NotProton via GitHub.command`, confirm the new commit and push, then
follow the GitHub Actions build. **Do not create another repository.**

The GitHub build workflow remains intact. The Makefile now makes the new shell
resource executable in the `.app` bundle, and `verify-fes-app.sh` checks it.

The actual macOS app must be built on a Mac or via GitHub Actions. Script and
Swift syntax checks on another platform do not constitute an end-to-end macOS
app build.
