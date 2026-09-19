# Neomas

> **This repository contains no application source code.** It contains the
> publication workflow and the installers for public Neomas releases.

**Official site: https://neomas.app**

## Download

Grab the latest build here: **[Releases → latest](../../releases/latest)**

| File | For |
|---|---|
| `Neomas-<version>-arm64.dmg` | Apple Silicon Mac (M1, M2, M3, M4) |
| `Neomas-<version>-x64.dmg` | Intel Mac (pre-2020) |
| `Neomas-Setup-<version>.exe` | Windows 10 / 11, 64-bit |

## Automatic updates

Once installed, Neomas updates itself from Cloudflare R2. A published GitHub
release is the trigger: GitHub Actions validates its installers, manifests and
blockmaps, uploads versioned files and stable download aliases to R2, then
publishes the update manifests last. If an upload fails, the previous update
feed stays active.

The Neomas application source remains private.

The workflow uses an R2 S3 key restricted to the `omega-updates` bucket. Its
access key and secret stay in GitHub Actions secrets; the endpoint, bucket name
and public base URL are repository variables.

## Install warnings

- **macOS**: the application is signed and notarized by Apple. Open the DMG,
  drag Neomas to Applications, then launch it normally.
- **Windows**: SmartScreen may show a reputation warning on the first downloads
  of a version. More info, then Run anyway.

## Something wrong?

Write to **metakaihos@pm.me** and tell me your machine.
Issues on this repository are not monitored: it only serves files.
