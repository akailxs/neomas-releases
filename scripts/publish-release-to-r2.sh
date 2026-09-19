#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ASSETS_DIR="${RELEASE_ASSETS_DIR:-release-assets}"
BUCKET="${R2_BUCKET_NAME:-omega-updates}"
PUBLIC_BASE="${R2_PUBLIC_BASE_URL:-https://pub-1512f6b35ee14bf09b18c478e5eb110c.r2.dev}"
ENDPOINT="${R2_ENDPOINT:?R2_ENDPOINT manque}"
TAG="${RELEASE_TAG:?RELEASE_TAG manque}"
VERSION="${TAG#v}"
export TAG VERSION

node scripts/validate-release-assets.mjs "$TAG"

put_object() {
  local key="$1"
  local file="$2"
  echo "Upload $key"
  aws s3 cp "$file" "s3://$BUCKET/$key" \
    --endpoint-url "$ENDPOINT" \
    --only-show-errors
}

echo "Publication atomique de $TAG vers R2/$BUCKET"

# Tous les octets versionnés passent avant les alias et surtout avant les
# manifestes. Un échec laisse ainsi l'ancien feed entièrement utilisable.
for file in "$ASSETS_DIR"/*; do
  base="$(basename "$file")"
  case "$base" in
    latest-mac.yml|latest.yml) continue ;;
  esac
  put_object "updates/$base" "$file"
done

if [ -f "$ASSETS_DIR/latest-mac.yml" ]; then
  arm_dmgs=("$ASSETS_DIR"/*-arm64.dmg)
  intel_dmgs=("$ASSETS_DIR"/*-x64.dmg)
  if [ ! -f "${intel_dmgs[0]}" ] && [ -f "$ASSETS_DIR/Neomas-$VERSION.dmg" ]; then
    intel_dmgs=("$ASSETS_DIR/Neomas-$VERSION.dmg")
  fi
  put_object "updates/latest/Neomas-mac-arm64.dmg" "${arm_dmgs[0]}"
  put_object "updates/latest/Neomas-mac-x64.dmg" "${intel_dmgs[0]}"
fi

if [ -f "$ASSETS_DIR/latest.yml" ]; then
  windows_installers=("$ASSETS_DIR"/*.exe)
  put_object "updates/latest/Neomas-Setup.exe" "${windows_installers[0]}"
fi

metadata="$(mktemp)"
trap 'rm -f "$metadata"' EXIT
node -e 'const fs=require("fs");fs.writeFileSync(process.argv[1],JSON.stringify({version:process.env.VERSION,tag:process.env.TAG,publishedAt:process.env.RELEASE_PUBLISHED_AT||new Date().toISOString()},null,2)+"\n")' "$metadata"
put_object "updates/latest/release.json" "$metadata"

# Les manifestes basculent les clients. Ils sont toujours envoyés en dernier.
for manifest in latest-mac.yml latest.yml; do
  if [ -f "$ASSETS_DIR/$manifest" ]; then
    put_object "updates/$manifest" "$ASSETS_DIR/$manifest"
  fi
done

for manifest in latest-mac.yml latest.yml; do
  if [ -f "$ASSETS_DIR/$manifest" ]; then
    remote="$(curl -fsS "$PUBLIC_BASE/updates/$manifest?release=$VERSION")"
    printf '%s\n' "$remote" | grep -q "^version: $VERSION$"
  fi
done
curl -fsSI "$PUBLIC_BASE/updates/latest/release.json?release=$VERSION" >/dev/null

echo "R2 publie $TAG et ses alias stables."
