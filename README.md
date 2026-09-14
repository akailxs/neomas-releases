# Neomas

> **This repository contains no source code.** It only mirrors the published
> Neomas installers. The Neomas source code is private.

**Official site: https://neomas.netlify.app** 

## Download

Grab the latest build here: **[Releases → latest](../../releases/latest)**

| File | For |
|---|---|
| `Neomas-<version>-arm64.dmg` | Apple Silicon Mac (M1, M2, M3, M4) |
| `Neomas-<version>.dmg` | Intel Mac (pre-2020) |
| `Neomas Setup <version>.exe` | Windows 10 / 11, 64-bit |

## Updates do NOT come from here

Once installed, Neomas updates itself from its own distribution server. This
repository is **not** an update feed: it deliberately carries no manifest
(`latest.yml`, `latest-mac.yml`) and no `.blockmap` files. Installing from this
mirror gives you exactly the same binary as the site; everything after that
happens inside the app.

## Install warnings

- **macOS**: on the very first launch, right-click the app, then Open, then Open
  again. A plain double-click will be refused. Once only.
- **Windows**: SmartScreen may show a reputation warning on the first downloads
  of a version. More info, then Run anyway.

## Something wrong?

Write to **metakaihos@pm.me** and tell me your machine.
Issues on this repository are not monitored: it only serves files.
