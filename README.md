# Gate

Native macOS menu bar app that replaces Claude Code's terminal permission prompts with a glass-style overlay in the bottom-right corner.

## Requirements

- macOS 13.0+

## Install

### Quick Install (pre-built binary)

No Xcode required. Download `Gate.zip` from the [latest release](../../releases/latest), then:

```bash
git clone <repo-url>
cd Gate
# Place Gate.zip in the repo root
bash scripts/install.sh --prebuilt
```

### Build from Source

Requires Xcode Command Line Tools (`xcode-select --install`).

```bash
git clone <repo-url>
cd Gate
bash scripts/install.sh
```

The install script:
1. Builds the app from source (`swift build -c release`)
2. Installs it to `/Applications/Gate.app`
3. Registers the `PermissionRequest` hook in `~/.claude/settings.json`
4. Launches the app immediately

A lock shield icon appears in your menu bar. You're done.

## Usage

When Claude Code needs permission, a glass overlay appears in the bottom-right corner showing:

- **What** Claude wants to do (command, file path, or URL)
- **Why** Claude needs it (from the session transcript)
- **Risk level** (HIGH / MEDIUM / LOW)

**Actions:**
- `Allow this time` (↵) — one-off approval
- `Always allow [category]` — remembered based on your permission mode
- `Deny` (⎋) — blocks the action

Auto-approved tools show a brief toast notification in the bottom-right corner (configurable in Settings).

## Settings

Click the menu bar icon → **Settings…**

| Setting | Description |
|---------|-------------|
| Session Only | "Always allow" lasts until you quit Gate |
| Permanent | "Always allow" is saved and never asks again |
| Smart Scope | Reads auto-allowed silently; writes ask once; shell always asks |

Toggle **Launch at login** to start automatically when you log in.

## Team Distribution

```bash
git clone <repo-url>
cd Gate
bash scripts/install.sh --prebuilt
```

Each team member runs the same command. No Xcode or build tools required.

## Uninstall

```bash
bash scripts/uninstall.sh
```

Removes the app, deregisters the hook from `~/.claude/settings.json`, and optionally removes `~/.claude-gate/`.

## How It Works

Gate uses Claude Code's native `type: "http"` `PermissionRequest` hook. Claude Code POSTs permission requests to Gate's local HTTP server. Gate shows the overlay, waits for your decision, and returns the response. If Gate isn't running, Claude Code falls back to its default terminal prompt automatically.

The app automatically selects an available port (starting from 29001) and updates the hook URL in `~/.claude/settings.json` on each launch.

## Building a Release

To create a universal binary (arm64 + x86_64) for distribution:

```bash
bash scripts/build-release.sh
```

This produces `Gate.zip` ready to upload to GitHub Releases.
