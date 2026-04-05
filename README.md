# Boop

A native macOS menu bar app that replaces Claude Code's terminal permission prompts with an elegant glass-style overlay.

Instead of switching to the terminal every time Claude Code needs permission, Boop shows a floating panel in the corner of your screen. See what Claude wants to do, why it needs it, and approve or deny with a single keystroke.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue) ![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange) ![Universal Binary](https://img.shields.io/badge/arch-arm64%20%2B%20x86__64-green)

## Features

- **Permission overlay** — floating glass panel in the bottom-right corner, always visible across all spaces
- **Risk level indicators** — color-coded badges (HIGH / MEDIUM / LOW) based on what Claude wants to do
- **Context display** — shows the command, file path, or URL along with why Claude needs it (extracted from the session transcript)
- **Three permission modes** — Default (ask everything), Smart Scope (auto-allow reads, ask for writes/shell), Permanent (auto-allow all)
- **Toast notifications** — brief stackable cards for auto-approved actions
- **Keyboard-first** — Return to allow, Escape to deny, no mouse needed
- **Launch at login** — optional auto-start via macOS Settings
- **Graceful fallback** — if Boop isn't running, Claude Code falls back to terminal prompts automatically

## Install

### Quick Install (pre-built binary)

No Xcode required. Download `Boop.zip` from the [latest release](../../releases/latest), then:

```bash
git clone https://github.com/arjunw7/Boop.git
cd Boop
# Place Boop.zip in the repo root
bash scripts/install.sh --prebuilt
```

### Build from Source

Requires Xcode Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/arjunw7/Boop.git
cd Boop
bash scripts/install.sh
```

The install script builds the app, installs it to `/Applications/Boop.app`, registers the HTTP hook in `~/.claude/settings.json`, and launches it. A hand icon appears in your menu bar — you're good to go.

## Usage

When Claude Code needs permission, a floating overlay appears showing:

| | |
|---|---|
| **What** | The command, file path, or URL Claude wants to access |
| **Why** | Context extracted from the session transcript |
| **Risk** | HIGH (shell), MEDIUM (file writes, web), or LOW (reads) |

### Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `Return` | Allow this time |
| `Shift+Return` | Allow for this session |
| `Cmd+Return` | Allow permanently |
| `Escape` | Deny |

## Permission Modes

Configure in **Menu Bar Icon > Settings > Consent Mode**.

| Mode | Behavior |
|------|----------|
| **Default** | Asks for every action. "Always allow" lasts until you quit Boop. |
| **Smart Scope** | File reads auto-allowed silently. Writes ask once per session. Shell commands always ask. |
| **Permanent** | Everything auto-allowed. No prompts. |

## Settings

Click the menu bar icon and select **Settings** to configure:

- **Consent Mode** — choose your permission mode
- **Toast notifications** — toggle auto-approve notifications on/off
- **Alert sound** — pick from 14 macOS system sounds
- **Launch at login** — start Boop automatically when you log in
- **Reveal config** — open `~/.boop/` in Finder

## How It Works

Boop uses Claude Code's native `type: "http"` hook for `PermissionRequest` events. On launch, it starts a local HTTP server (port 29001, with automatic fallback to 29002–29010) and patches `~/.claude/settings.json` to route permission requests to it.

When Claude Code needs permission, it POSTs a JSON request to Boop. Boop shows the overlay, waits for your decision, and returns the response. The entire flow is local — nothing leaves your machine.

## Uninstall

```bash
bash scripts/uninstall.sh
```

Removes the app, deregisters the hook from `~/.claude/settings.json`, and optionally removes `~/.boop/` config.

## Building a Release

To create a universal binary (arm64 + x86_64) for distribution:

```bash
bash scripts/build-release.sh
```

This builds, signs with Developer ID (if available), submits for Apple notarization, and produces `Boop.zip` ready for GitHub Releases.

## Requirements

- macOS 13.0+ (Ventura or later)
- Claude Code with HTTP hook support

## License

MIT
