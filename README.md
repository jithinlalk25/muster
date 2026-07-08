# Muster

A native macOS menu-bar app that shows a live **roll call of your Claude Code sessions** —
so you can see, at a glance, which ones are working and which ones are waiting on you.

![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)
![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black.svg)

<!-- Add a screenshot at assets/screenshot.png and uncomment:
![Muster](assets/screenshot.png)
-->

## Why

When you run several Claude Code sessions at once, it's easy to lose track of which one just
finished and needs your input. Muster watches them all through Claude Code's hooks and surfaces
their status in your menu bar: a badge tells you how many need you, and a click shows the full roll call.

## Features

- **Menu-bar badge** — a `person.2` icon that turns orange with a count when a session needs your attention.
- **Floating panel** — a live list of sessions, each with a status dot:
  - 🔵 **Working** — Claude is running a tool
  - 🟠 **Your turn** — Claude finished and is waiting on you (sorted to the top)
  - ⚪️ **Idle**
- **Transcript peek** — click a session to see its title and recent messages, read live from the transcript.
- **Non-intrusive** — a menu-bar agent with no Dock icon; the panel remembers its position and won't auto-hide.
- **First-run setup** — one click installs the hooks; your existing `~/.claude/settings.json` is **merged, never replaced**.

## Requirements

- macOS 13 (Ventura) or later — Apple Silicon or Intel
- [Claude Code](https://claude.com/claude-code)

## Install

### Homebrew (recommended)

```bash
brew install --cask jithinlalk25/homebrew-tap/muster
```

> Homebrew asks you to trust a third-party tap once. If it says the tap is untrusted, run
> `brew trust jithinlalk25/tap` and re-run the install.

Update later with `brew upgrade --cask muster`. Releases are Developer ID-signed and notarized.

### Build from source

```bash
git clone https://github.com/jithinlalk25/muster.git
cd muster
./Scripts/build-app.sh          # produces a universal Muster.app at the repo root
open Muster.app                 # or move it to /Applications
```

## How it works

Muster adds a small `muster-hook` command to your Claude Code hooks (`~/.claude/settings.json`).
On each session event (a tool starting, a turn ending, …) the hook sends one line over a **local
UNIX socket** to the running app, which updates the roll call. Nothing leaves your machine — there
is no network access, no telemetry.

On first launch, Muster opens a setup window showing exactly what it will add and installs it on
your confirmation. The hook is **fail-open**: if the app isn't running, it does nothing and never
blocks or slows Claude Code.

## Uninstall

Open **Settings… → Uninstall hooks** from Muster's menu-bar menu first (this cleanly removes only
Muster's entries from `settings.json`), then delete the app — or `brew uninstall --cask muster`.

## Development

```bash
swift test               # run the test suite
./Scripts/build-app.sh   # assemble Muster.app
```

Releasing (signing, notarization, Homebrew) is documented in [RELEASING.md](RELEASING.md).

## License

[MIT](LICENSE) © 2026 Jithin Lal K
