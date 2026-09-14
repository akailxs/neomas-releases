# Neomas — installeurs officiels (miroir)

> **Ce dépôt ne contient aucun code source.** Il n'héberge que les installeurs
> publiés de Neomas, en **miroir**. Le code source de Neomas est privé.

**Site officiel : https://neomas.netlify.app** — c'est la source de vérité.
Ce miroir existe pour un seul cas : le site ou le serveur de téléchargement est
indisponible, et tu as quand même besoin de l'installeur.

## Télécharger

Prends la dernière version ici : **[Releases → latest](../../releases/latest)**

| Fichier | Pour |
|---|---|
| `Neomas-<version>-arm64.dmg` | Mac Apple Silicon (M1, M2, M3, M4) |
| `Neomas-<version>.dmg` | Mac Intel (avant 2020) |
| `Neomas Setup <version>.exe` | Windows 10 / 11, 64 bits |

## Les mises à jour ne passent PAS par ici

Une fois Neomas installé, l'application se met à jour toute seule depuis son
propre serveur de distribution. Ce dépôt n'est **pas** un flux de mise à jour :
il ne contient volontairement aucun manifeste (`latest.yml`, `latest-mac.yml`)
ni fichier `.blockmap`. Installer depuis ce miroir donne exactement le même
binaire que depuis le site ; la suite se passe dans l'app.

## Avertissements d'installation

- **macOS** : au tout premier lancement, clic droit sur l'app puis « Ouvrir »,
  puis « Ouvrir » encore. Un double-clic normal sera refusé. Une seule fois.
- **Windows** : SmartScreen peut afficher un avertissement de réputation sur les
  premiers téléchargements d'une version. « Informations complémentaires » puis
  « Exécuter quand même ».

## Un problème ?

Écris à **metakaihos@pm.me** en précisant ta machine.
Les *issues* de ce dépôt ne sont pas suivies : il ne sert qu'à distribuer des fichiers.

---

# Neomas — official installers (mirror)

> **This repository contains no source code.** It only mirrors the published
> Neomas installers. The Neomas source code is private.

**Official site: https://neomas.netlify.app** — that is the source of truth.
This mirror exists for one case only: the site or the download server is down
and you still need the installer.

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
