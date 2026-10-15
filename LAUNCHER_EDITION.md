# Launcher Edition: interface and compatibility boundaries

## Navigation and interaction
- **Discover** is a true dashboard, not a summary form. Main controls are on the *left* of a two-column layout.
- **Game Library** uses responsive playable game cards, a search field and contextual actions. No original prefix table is used by default.
- **Vault** is a card-based backup management page with safe, explicit deletion confirmation.
- The right-hand rail includes a separate **SETUP** destination. This opens the original detailed operational view as an advanced sheet, preserving every existing workflow and its original confirmations.

## Why some filenames still say notproton

Changing the names of Steam injection binaries, the SwiftPM `NotProtonApp` module, on-disk runner names or `~/Library/Application Support/notproton` could break installed runtimes and prefixes. Those technical identifiers remain intentionally unchanged, while the new UI, bundle name, identifier, icon and releases use ProtonLess Steam.

Do not change these internal names without a separate tested migration and rollback strategy. The repo must continue crediting upstream creators because it reuses the engine.

## Trial and licensing
CrossOver free-trial detection from the base remains intact. The button labelled **Restore saved settings** only restores a previously backed-up preference; it is not a trial-extension feature. CrossOver must be used within its authorised trial or under a valid licence.
