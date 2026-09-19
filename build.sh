#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST="$ROOT/dist"
PKG="$DIST/pkg"
CACHE="$ROOT/.cache"
NAME="${PACKAGE_NAME:-DD2-ReShade-Preset}"
SHADERS="$PKG/reshade-shaders/Shaders"
TEXTURES="$PKG/reshade-shaders/Textures"

# name|url|ref (empty ref = latest commit of the default branch)
REPOS=(
  "iMMERSE|https://github.com/martymcmodding/iMMERSE|"
  "METEOR|https://github.com/martymcmodding/METEOR|"
  "qUINT|https://github.com/martymcmodding/qUINT|"
  "AstrayFX|https://github.com/BlueSkyDefender/AstrayFX|"
)

sync_repo() {
  local name="$1" url="$2" ref="$3" dir="$CACHE/$1" commit

  if [ -d "$dir/.git" ]; then
    git -C "$dir" fetch --quiet origin
  else
    git clone --quiet "$url" "$dir"
  fi
  git -C "$dir" checkout --quiet "${ref:-origin/HEAD}"

  if [ -d "$dir/Shaders" ]; then
    cp -a "$dir/Shaders/." "$SHADERS/"
  else
    echo "  warning: $name has no Shaders folder, copying any .fx/.fxh files found"
    find "$dir" -path "$dir/.git" -prune -o -name '*.fx*' -type f -exec cp -a {} "$SHADERS/" \;
  fi
  if [ -d "$dir/Textures" ]; then
    cp -a "$dir/Textures/." "$TEXTURES/"
  fi

  commit="$(git -C "$dir" rev-parse --short HEAD)"
  echo "$name $commit" >> "$DIST/versions.txt"
  echo "  $name -> $commit"
}

patch_longexposure() {
  local file="$SHADERS/MartysMods_LONGEXPOSURE.fx"
  if [ -f "$file" ]; then
    sed -i 's/\[flatten\]//' "$file"
    echo "  patched MartysMods_LONGEXPOSURE.fx"
  fi
}

write_notes() {
  {
    echo "## Included versions"
    echo
    echo "| Pack | Commit |"
    echo "|---|---|"
    while read -r pack commit; do
      echo "| $pack | \`$commit\` |"
    done < "$DIST/versions.txt"
  } > "$DIST/notes.md"
}

rm -rf "$DIST"
mkdir -p "$SHADERS" "$TEXTURES" "$CACHE"
: > "$DIST/versions.txt"

echo "Fetching packs..."
for entry in "${REPOS[@]}"; do
  IFS='|' read -r name url ref <<< "$entry"
  sync_repo "$name" "$url" "$ref"
done

echo "Patching..."
patch_longexposure

echo "Adding package/ contents..."
cp -a "$ROOT/package/." "$PKG/"
find "$PKG" -name .gitkeep -delete

echo "Creating zip..."
(cd "$PKG" && zip -qr "$DIST/$NAME.zip" .)
write_notes

echo "Done: $DIST/$NAME.zip"
