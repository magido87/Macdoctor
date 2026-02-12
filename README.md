# MacDoctor

A terminal-based diagnostic and maintenance tool for macOS. One script, no dependencies, nothing leaves your machine.

![Shell Script](https://img.shields.io/badge/shell-zsh-blue) ![macOS](https://img.shields.io/badge/macOS-12%2B-brightgreen) ![License](https://img.shields.io/badge/license-MIT-green)

---

## Install

```bash
git clone https://github.com/YOUR_USERNAME/macdoctor.git
cd macdoctor
chmod +x macdoctor.sh
./macdoctor.sh
```

To run it from anywhere, add an alias to your `~/.zshrc`:

```bash
alias macdoctor="/path/to/macdoctor.sh"
```

---

## What does it do?

MacDoctor checks the health of your Mac and tells you what's going on in plain language. It reads CPU, memory, disk, battery, security settings, startup items, thermals, and more — then surfaces the stuff that actually matters.

When you run a scan, you get observations like:

> "Swap is active (2.1 GB) — your system has been under memory pressure."
> "14 startup items found — some of these may be slowing your boot."

These come from pattern-matching rules running locally in the script. No cloud, no API, no AI service.

---

## Features at a glance

**Scans** — Three levels: Quick (~10s), Deep (~30s), and Ultra (~2 min). Each goes deeper into caches, logs, startup items, SMART disk health, and process auditing.

**Dashboard** — Live or static overview of CPU, memory, disk, battery, thermals, swap, network, load averages, and top processes.

**Health Score** — A single number (0–100) based on CPU, memory, and disk pressure. Tracks over time so you can spot trends.

**Fix & Cleanup** — Three tiers (Safe, Deeper, Aggressive) with before/after comparison. An Optimization Wizard walks you through it step by step.

**Security Audit** — Checks FileVault, Firewall, Gatekeeper, SIP, and Time Machine backup status. Offers one-click fixes.

**WiFi Diagnostics** — Signal quality, SNR, channel congestion, TX rate, nearby networks, DNS, and public IP.

**Storage Analyzer** — Breaks down disk usage by category (apps, caches, logs, downloads, etc.) and finds your largest files.

**Advanced Tools** — Process inspector, live system monitors, network speed test, disk benchmark, and a full semantic analysis engine.

---

## Themes

11 built-in color themes that change every element in the UI:

Bronze · Terminal · Neon · Amber · Classic · Minimal · Frost · Solar · Midnight · Atom · Warm

---

## Settings

On first launch, a setup wizard lets you pick your theme, result style, and user level. Everything is saved to `~/.config/macdoctor/settings.conf` and can be changed anytime from the Settings menu.

**User levels** control how much you see in menus — Simple for the basics, Standard for most features, Expert for everything.

**Home screen widgets** let you toggle what shows on the main screen: battery, network, uptime, thermal state.

**Result styles** change how scan output looks: Cards, Table, or Visual (progress bars and gauges).

---

## Requirements

- macOS 12 (Monterey) or newer
- zsh (default shell since Catalina)
- A terminal with 256-color support (Terminal.app, iTerm2, Warp, etc.)

Optional:
- **Homebrew** — for a few extended features (jq, smartmontools)
- **sudo** — needed for deep scans and some security fixes

---

## Project structure

```
macdoctor/
├── macdoctor.sh    # The entire app — single file
├── .gitignore
└── README.md
```

One file, roughly 5000 lines of zsh. Includes a theme engine, a UI toolkit (progress bars, box drawing, badges, gauges), data collection across 20+ macOS subsystems, a rule-based analysis engine, and a settings system with first-run wizard.

---

## Contributing

Found a bug? Want to add something? PRs welcome.

1. Fork the repo
2. Create a branch (`git checkout -b fix/something`)
3. Test locally (`zsh -n macdoctor.sh` for syntax check, then run it)
4. Submit a PR

---

## License

MIT
