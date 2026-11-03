#!/usr/bin/env bash
# Contrôle « installation comme un utilisateur » d'un DMG Neomas (macOS uniquement).
#
# Les 12 contrôles de release vérifiaient l'app SUR LE DMG MONTÉ. 1.1.15 y passait,
# puis était « endommagée » une fois copiée sur le disque d'un utilisateur. Ce
# script vérifie donc l'app APRÈS copie, par plusieurs chemins :
#   1. ditto                         (ce que font Squirrel et la plupart des outils)
#   2. NSFileManager copyItem        (API Foundation, équivalent d'un glisser Finder)
#   3. Finder lui-même via AppleScript (au mieux : peut être indisponible sur un runner)
#   4. ditto vers un volume HFS+     (impose des noms NFD : rend déterministe le cas
#                                     « les noms reviennent en NFD » vu chez un utilisateur)
# et, sur chaque copie : noms vs sceau, codesign --verify --deep --strict, spctl, stapler.
# Règle de bundle : aucun chemin non ASCII dans Contents/.
#
# Usage : scripts/check-mac-install.sh <fichier.dmg> [<fichier.dmg> ...]
# Sortie non nulle si UN SEUL contrôle obligatoire échoue : la publication s'arrête.
set -uo pipefail

if [ "$(uname -s)" != "Darwin" ]; then
  echo "check-mac-install : macOS requis (codesign, spctl, hdiutil, ditto)" >&2
  exit 2
fi
if [ "$#" -eq 0 ]; then
  echo "Usage : $0 <fichier.dmg> [...]" >&2
  exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="${APP_NAME:-Neomas.app}"
FINDER_COPY_TIMEOUT="${FINDER_COPY_TIMEOUT:-180}"
failures=()
WORK="$(mktemp -d "${TMPDIR:-/tmp}/neomas-install-check.XXXXXX")"
MOUNTS=()

cleanup() {
  local m
  for m in "${MOUNTS[@]:-}"; do
    [ -n "$m" ] && hdiutil detach -quiet -force "$m" >/dev/null 2>&1 || true
  done
  rm -rf "$WORK" 2>/dev/null || true
}
trap cleanup EXIT

run() {
  # run <obligatoire:1|0> <libellé> <commande...> : affiche la sortie brute et le code.
  local mandatory="$1" label="$2" rc
  shift 2
  echo "\$ $*"
  "$@" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "[OK] $label"
  elif [ "$mandatory" = 1 ]; then
    echo "[FAIL] $label (exit $rc)"
    failures+=("$label")
  else
    echo "[INFO] $label (exit $rc, non bloquant)"
  fi
  return 0
}

spctl_assess() {
  # spctl n'a de valeur que si Gatekeeper est actif : « override=security disabled »
  # est un faux positif, traité comme un échec.
  local app="$1" out rc
  out="$(spctl -a -vv -t exec "$app" 2>&1)"
  rc=$?
  printf '%s\n' "$out"
  if printf '%s' "$out" | grep -q 'override=security disabled'; then
    echo "Gatekeeper désactivé sur cette machine : évaluation non significative" >&2
    return 3
  fi
  return "$rc"
}

stapler_validate() {
  # `stapler validate` interroge le service de tickets d'Apple (CloudKit). Une coupure
  # réseau du runner (NSURLErrorDomain, exit 68) n'est pas un défaut de l'app : on
  # retente dans ce seul cas. Un ticket absent ou invalide échoue sans erreur réseau
  # et reste donc bloquant dès le premier essai.
  local app="$1" out rc attempt
  for attempt in 1 2 3 4; do
    out="$(xcrun stapler validate "$app" 2>&1)"
    rc=$?
    printf '%s\n' "$out"
    if [ "$rc" -eq 0 ] || ! printf '%s' "$out" | grep -q 'NSURLErrorDomain'; then
      return "$rc"
    fi
    echo "stapler : erreur réseau vers Apple, nouvel essai ($attempt/4) dans $((attempt * 10)) s"
    sleep $((attempt * 10))
  done
  return "$rc"
}

verify_copy() {
  local label="$1" app="$2"
  echo
  echo "----- [$label] $app"
  # Le navigateur met en quarantaine le DMG ; la copie hérite de l'attribut. On le
  # pose explicitement pour que l'évaluation corresponde au premier lancement.
  xattr -w com.apple.quarantine "0081;$(printf '%x' "$(date +%s)");Safari;" "$app" 2>/dev/null || true
  run 1 "[$label] noms sur disque == noms scellés, tous ASCII" python3 -I "$ROOT/scripts/compare-seal-names.py" "$app"
  run 1 "[$label] codesign --verify --deep --strict" codesign --verify --deep --strict --verbose=2 "$app"
  run 1 "[$label] spctl -a -vv" spctl_assess "$app"
  run 1 "[$label] stapler validate" stapler_validate "$app"
}

finder_copy() {
  # Glisser Finder réel. Peut demander une autorisation Apple Events : délai borné.
  local src="$1" dest_dir="$2"
  perl -e 'alarm shift; exec @ARGV' "$FINDER_COPY_TIMEOUT" osascript \
    -e 'on run argv' \
    -e 'tell application "Finder" to duplicate (POSIX file (item 1 of argv) as alias) to (POSIX file (item 2 of argv) as alias) with replacing' \
    -e 'end run' "$src" "$dest_dir"
}

nsfilemanager_copy() {
  local src="$1" dest="$2" js="$WORK/copy.js"
  cat > "$js" <<'JXA'
ObjC.import('Foundation')
function run(argv) {
  const err = Ref()
  if (!$.NSFileManager.defaultManager.copyItemAtPathToPathError(argv[0], argv[1], err)) {
    throw new Error('NSFileManager copy failed: ' + ObjC.unwrap(err[0].localizedDescription))
  }
}
JXA
  osascript -l JavaScript "$js" "$src" "$dest"
}

echo "=== Contexte"
sw_vers 2>&1 || true
uname -m
spctl --status 2>&1 || true

for DMG in "$@"; do
  DMG="$(cd "$(dirname "$DMG")" && pwd)/$(basename "$DMG")"
  name="$(basename "$DMG" .dmg)"
  echo
  echo "================ $name"
  shasum -a 256 "$DMG"
  xattr -w com.apple.quarantine "0081;$(printf '%x' "$(date +%s)");Safari;" "$DMG" 2>/dev/null || true

  base="$WORK/$name"
  mkdir -p "$base/mnt" "$base/ditto" "$base/nsfm" "$base/finder" "$base/hfs"
  if ! hdiutil attach -nobrowse -readonly -noautoopen -mountpoint "$base/mnt" "$DMG"; then
    echo "[FAIL] [$name] hdiutil attach"
    failures+=("[$name] hdiutil attach")
    continue
  fi
  MOUNTS+=("$base/mnt")
  src="$base/mnt/$APP_NAME"

  echo
  echo "----- [$name] règle de bundle : chemins non ASCII dans Contents/"
  nonascii="$(LC_ALL=C find "$src/Contents" -name '*[^ -~]*' | LC_ALL=C sort)"
  count="$(printf '%s' "$nonascii" | grep -c . || true)"
  echo "\$ LC_ALL=C find \"$src/Contents\" -name '*[^ -~]*' | wc -l"
  echo "$count"
  if [ "$count" -ne 0 ]; then
    printf '%s\n' "$nonascii"
    echo "[FAIL] [$name] aucun chemin non ASCII dans le bundle signé"
    failures+=("[$name] chemins non ASCII ($count)")
  else
    echo "[OK] [$name] aucun chemin non ASCII dans le bundle signé"
  fi

  echo
  echo "----- [$name] référence : app sur le DMG monté (ce que vérifiaient les 12 contrôles)"
  run 0 "[$name/dmg-monté] codesign --verify --deep --strict" codesign --verify --deep --strict --verbose=2 "$src"
  run 0 "[$name/dmg-monté] spctl -a -vv" spctl_assess "$src"

  run 1 "[$name] copie ditto" ditto "$src" "$base/ditto/$APP_NAME"
  [ -d "$base/ditto/$APP_NAME" ] && verify_copy "$name/ditto" "$base/ditto/$APP_NAME"

  run 1 "[$name] copie NSFileManager (équivalent Finder)" nsfilemanager_copy "$src" "$base/nsfm/$APP_NAME"
  [ -d "$base/nsfm/$APP_NAME" ] && verify_copy "$name/nsfilemanager" "$base/nsfm/$APP_NAME"

  run 0 "[$name] copie Finder (AppleScript, au mieux)" finder_copy "$src" "$base/finder"
  [ -d "$base/finder/$APP_NAME" ] && verify_copy "$name/finder" "$base/finder/$APP_NAME"

  if hdiutil create -quiet -size 2g -fs HFS+ -volname NEOMASNFD -type UDIF "$base/hfs.dmg" \
     && hdiutil attach -nobrowse -noautoopen -mountpoint "$base/hfs" "$base/hfs.dmg" >/dev/null; then
    MOUNTS+=("$base/hfs")
    run 1 "[$name] copie ditto vers HFS+ (noms NFD)" ditto "$src" "$base/hfs/$APP_NAME"
    [ -d "$base/hfs/$APP_NAME" ] && verify_copy "$name/hfs+-nfd" "$base/hfs/$APP_NAME"
  else
    echo "[FAIL] [$name] création du volume HFS+"
    failures+=("[$name] volume HFS+")
  fi
done

echo
echo "================ Résumé"
if [ "${#failures[@]}" -eq 0 ]; then
  echo "Installation utilisateur : tous les contrôles obligatoires passent."
  exit 0
fi
echo "Installation utilisateur : ${#failures[@]} contrôle(s) obligatoire(s) en échec — publication interdite :"
printf '  - %s\n' "${failures[@]}"
exit 1
