# CrossOver active-trial detection patch (experimental)

This fork includes the CrossOver licence detection fix and its Swift regression tests.
It also includes an independent registry-only bottle backup action (see
`BOTTLE_BACKUP_README.md`).
It recognises a *currently active* 14-day CrossOver trial, in addition to the pre-existing
signed paid-licence validation. It does not reset, extend, or change the CrossOver trial.

## Behaviour

- A valid purchased licence remains accepted via its cryptographic signature.
- If there is no purchased licence file, check CrossOver's `FirstRunDate` Date from the user's `~/Library/Preferences/com.codeweavers.CrossOver.plist`.
- Accept an existing trial only within 14 days of the recorded first launch.
- Reject trials with missing/invalid/future start dates and expired trials.
- Reject unsigned or invalid purchased licences rather than falling back to trial.
- Continue requiring the CrossOver installation's verification key.

## Building on macOS

This is **source code**, not a built or signed macOS application. On a Mac with a
compatible Xcode toolchain and all of NotProton's build dependencies, follow the
original `.github/workflows/app.yml` procedure to build the project (`make all`,
`make overlay-shim`, `make iconmaker appinfo`, `make bridge`,
`make app-payload`, `make app`, and `make app-tests`).
See the workflow for pinned Dobby commit, Wine cache and prerequisite compilers.

## Validation and limitations

The edited Swift check compiled successfully with Swift 6.2.1 on Linux, and a
6-case executable test harness passed with synthetic plist dates and signed licences.
The project's full macOS app build and test suite could not be run in this Linux
container, nor tested against a genuine local CrossOver trial installation.

CrossOver may use additional expiry controls, and the `FirstRunDate` preference
is not a cryptographically authenticated proof of entitlement. This change is
intended to fix a false-negative during setup, not substitute for CrossOver's
own runtime checks. For upstreaming, consider confirming an official CrossOver
license/trial status API before shipping broadly.
