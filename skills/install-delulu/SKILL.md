---
name: install-delulu
description: Build and install the Delulu macOS menu bar app from its GitHub repository when the user asks to install or update Delulu.
---

# Install Delulu

Install the app from `https://github.com/bzavolovich/delulu` in `~/Applications/Delulu.app`, unless the user specifies another location. There are no prebuilt releases yet; build from source.

## Check requirements

Run `sw_vers -productVersion` and `swift --version`. The app targets macOS 14 or later; building requires Swift 6 or later from Xcode or Command Line Tools. Development has been verified on macOS 26.3 with Apple silicon. Builds for older supported systems and Intel Macs are not yet verified.

If developer tools are missing, run `xcode-select --install` and let the user complete Apple's installer, then continue. If Xcode reports an unaccepted license or incomplete setup, let the user complete it. Do not switch their system toolchain or accept a license on their behalf.

## Build

Use a fresh checkout, or a clean existing checkout the user has asked to install from. Preserve any local changes; do not reset an existing repository to install the app.

```sh
git clone https://github.com/bzavolovich/delulu.git
cd delulu
bash scripts/build-app.sh
```

Choose an unused checkout directory if `delulu` already exists. The script builds the release executable for the current Mac's architecture, generates its icon, packages `dist/Delulu.app`, and signs it ad hoc. It does not install system services, request administrator access, or enable notifications.

If the build fails, report the actual failure and stop the install until it is resolved. Do not copy a stale app bundle from a previous build. Do not disable Gatekeeper or remove quarantine attributes to bypass a macOS warning.

## Install and open

Quit any running copy of Delulu before replacing or opening the installed version. Use the app's Quit control when available. Do not leave both the checkout build and installed copy running.

If the destination already exists, check that its `Contents/Info.plist` has bundle identifier `app.delulu.menubar`. If it is a different app, stop and ask the user for another destination. For an update, move the previous matching bundle to a recoverable backup before copying; preserve `~/Library/Application Support/Delulu`.

For a new installation, or after moving the old bundle aside:

```sh
mkdir -p "$HOME/Applications"
ditto dist/Delulu.app "$HOME/Applications/Delulu.app"
codesign --verify --strict "$HOME/Applications/Delulu.app"
open "$HOME/Applications/Delulu.app"
```

Use the user's chosen destination consistently if it differs. If copying or verification fails during an update, restore the previous bundle from the backup. Keep a successful update's backup until the new app has been verified.

## Verify and hand off

Confirm the installed bundle exists and the app launches. If UI access is available, check for Delulu's envelope icon or its panel; otherwise report the executable/bundle checks completed and tell the user where to open it. Do not claim that a notification appeared unless it was actually observed.

Tell the user:

- Where the app was installed and that it was built from source.
- Open settings to enter a name and dream role, then use **Send now** for a test or select a repeat interval and click **Okay**.
- macOS requests notification permission on the first send. The installer should not send messages or start a repeating schedule on its own.
- To uninstall, click **Stop**, then **Quit**, and move the app to Trash. The optional saved profile is in `~/Library/Application Support/Delulu`.

Do not create a login item or background agent. Installation does not require either.
