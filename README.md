<div align="center">

# delulu

A tiny macOS menu bar app that sends fictional recruiter messages about your dream job.

[![License: MIT](https://img.shields.io/badge/License-MIT-aec4cc?style=flat-square&labelColor=242627)](LICENSE)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-aec4cc?style=flat-square&labelColor=242627)](#requirements)
[![Status: Alpha](https://img.shields.io/badge/Status-Alpha-c9b88c?style=flat-square&labelColor=242627)](#status)

[![Install](https://img.shields.io/badge/Install-242627?style=for-the-badge)](#installation)
[![Using it](https://img.shields.io/badge/Using_it-242627?style=for-the-badge)](#using-it)
[![Uninstall](https://img.shields.io/badge/Uninstall-242627?style=for-the-badge)](#uninstall)
[![Development](https://img.shields.io/badge/Development-242627?style=for-the-badge)](#development)

</div>

Choose a role, pick a mode, and get a little encouragement in your notifications. Everything runs locally: no account, API key, or subscription.

- **First hello** — a recruiter reaches out about a role.
- **The offer** — a message offering you the job, with optional compensation and work setup.
- **Send now** — try a message immediately.
- **Repeat** — receive a message every 1, 5, or 15 minutes, or every 1 or 3 hours.

## Installation

### Install with your agent

Copy this into a coding agent that can read GitHub and run commands on your Mac:

```text
Install Delulu by following https://github.com/bzavolovich/delulu/blob/main/skills/install-delulu/SKILL.md. Build it from source, install it in ~/Applications, and open the app.
```

The [agent install guide](skills/install-delulu/SKILL.md) covers requirements, building, copying the app, and checking the installation. There is no prebuilt release yet; the agent builds the app on your Mac.

### Requirements

| | Requirement |
| --- | --- |
| Run the app | macOS 14 Sonoma or later |
| Build from source | Swift 6 or later, provided by Xcode or Command Line Tools |
| Receive messages | Allow notifications for Delulu when prompted |

Check your tools with `swift --version`. If developer tools are missing, run `xcode-select --install` and complete Apple's installer. The app is built for the architecture of your Mac.

### Build from source

```sh
git clone https://github.com/bzavolovich/delulu.git
cd delulu
bash scripts/build-app.sh
open dist/Delulu.app
```

The build script compiles the app, generates its icon, and creates a locally signed `dist/Delulu.app`. It is ad-hoc signed and not notarized for distribution.

To keep the app in your user Applications folder, quit any running copy of Delulu, then run:

```sh
mkdir -p "$HOME/Applications"
ditto dist/Delulu.app "$HOME/Applications/Delulu.app"
open "$HOME/Applications/Delulu.app"
```

If you're updating an existing installation, quit it and move the old app bundle to Trash before copying the new one. Your saved profile lives separately and is preserved.

## Using it

1. Click the envelope icon in the menu bar.
2. Open settings and enter your **first name** and **dream role**. Add a standout skill, compensation, and work setup if you want, then click **Save my dream job**.
3. Choose **First hello** or **The offer**.
4. Click **Send now** for a test notification, or choose a repeat interval and click **Okay** to start the schedule.
5. Allow notifications when macOS asks.

| Control | What it does |
| --- | --- |
| **Send now** | Sends one message using the selected mode and sound setting, without changing the repeating schedule. |
| **Okay** | Starts or replaces the repeating schedule. The first message arrives after one full interval. |
| **Sound icon** | Chooses sound for Send now or the next schedule you apply with Okay. |
| **Stop** | Cancels the repeating schedule. |
| **Quit** | Closes Delulu. Scheduled notifications continue until you stop them. |

Each schedule repeats one generated message. Applying a new schedule or saving your profile while a schedule is active generates a new version and restarts the interval. Recruiter and company names come from fictional templates.

### Reading notifications

Delulu includes the entire message in the notification body. Hover over a notification and click the small arrow beside the app name, when macOS shows it, to see more details. Clicking the notification body opens Delulu's controls.

If messages aren't appearing, check **System Settings → Notifications → Delulu**. Focus, sleep, and notification settings can silence or delay banners.

### Your data

Your profile and settings stay in:

```text
~/Library/Application Support/Delulu/state.json
```

Delulu does not contact recruiters, companies, or external services. Notifications are delivered to your current Mac.

## Uninstall

1. Open Delulu and click **Stop** if a repeating schedule is active. **Quitting alone does not cancel scheduled notifications.**
2. Click **Quit**.
3. Move `~/Applications/Delulu.app` to Trash in Finder, or remove it from whichever folder you installed it in.
4. Optionally remove your saved profile: in Finder, choose **Go → Go to Folder**, enter `~/Library/Application Support/Delulu`, and move that folder to Trash.
5. If you built from source and no longer need the checkout, you can also move the `delulu` repository folder to Trash. This removes the build in `dist/` too.

Delulu does not install login items or background agents. Already delivered notifications can be cleared in Notification Center.

## Development

Build and run the test suite:

```sh
swift build
swift test
```

`swift test` works with a full Xcode toolchain selected. For standalone Command Line Tools, use the included wrapper, which supplies the Swift Testing framework paths:

```sh
bash scripts/test.sh
```

The wrapper also works with Xcode and does not change your selected toolchain. Tests use fake notifications and temporary storage, so they do not send messages or modify your saved profile.

Build a debug app bundle for testing the interface and notifications:

```sh
CONFIGURATION=debug bash scripts/build-app.sh
open dist/Delulu.app
```

Quit the running app before opening a rebuilt version. Use the packaged `.app` for notification testing; `swift run Delulu` opens the interface, but notification APIs require an app bundle.

| Location | Purpose |
| --- | --- |
| `Sources/Delulu` | Menu bar panel, SwiftUI interface, and macOS notification adapter |
| `Sources/DeluluCore` | Message generation, scheduling logic, profiles, and persistence |
| `Tests/DeluluCoreTests` | Automated tests |
| `scripts/` | App packaging, icon generation, and test tooling |

## Status

**Alpha · 0.1.0.** The app works locally; its interface and behavior may change as it develops.

Development and local testing have been done on **macOS 26.3 with Apple silicon**.

## License

[MIT](LICENSE) © 2026 bzavolovich.
