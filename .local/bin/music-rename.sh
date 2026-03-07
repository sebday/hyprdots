#!/usr/bin/env bash
# Rename files and folders in a directory:
#   (1) Replace " " with "_"
#   (2) Replace "_-_" with "-"
#   (3) Lowercase
#   (4) Remove funky symbols (keep only a-z, 0-9, _, -, .)
#
# Usage: music-rename.sh [directory] [--dry-run]

set -euo pipefail

DRY_RUN=false
DIR=""

for arg in "$@"; do
    case "$arg" in
        --dry-run)
            DRY_RUN=true
            ;;
        -*)
            echo "Unknown option: $arg" >&2
            echo "Usage: $0 [directory] [--dry-run]" >&2
            exit 1
            ;;
        *)
            DIR="$arg"
            ;;
    esac
done

DIR="${DIR:-$HOME/music}"

if [[ ! -d "$DIR" ]]; then
    echo "Error: $DIR is not a directory" >&2
    exit 1
fi

# Resolve symlinks to get real path
DIR=$(readlink -f "$DIR")

sanitize_name() {
    local name="$1"
    # (1) Replace " " with "_"
    name="${name// /_}"
    # (2) Replace "_-_" with "-"
    name="${name//_-_/-}"
    # (3) Lowercase
    name=$(echo "$name" | tr '[:upper:]' '[:lower:]')
    # (4) Remove funky symbols (keep only a-z, 0-9, _, -, .)
    name=$(echo "$name" | sed 's/[^a-z0-9_.-]//g')
    # Collapse multiple _ or - into single
    name=$(echo "$name" | sed -E 's/__+/_/g; s/--+/-/g')
    # Remove trailing _ or - before extension
    name=$(echo "$name" | sed -E 's/[-_]+\.([^.]*)$/.\1/')
    # Trim leading/trailing _ or -
    name=$(echo "$name" | sed -E 's/^[-_]+//; s/[-_]+$//')
    echo "$name"
}

count=0
errors=0

# Process from deepest to shallowest so parent renames don't break child paths
while IFS= read -r -d '' path; do
    [[ -z "$path" ]] && continue

    dirname=$(dirname "$path")
    basename=$(basename "$path")

    newname=$(sanitize_name "$basename")

    if [[ -z "$newname" ]]; then
        echo "Warning: would produce empty name, skipping: $path" >&2
        ((errors++)) || true
        continue
    fi

    if [[ "$basename" != "$newname" ]]; then
        dest="$dirname/$newname"
        if [[ -e "$dest" && "$path" != "$dest" ]]; then
            echo "Warning: destination exists, skipping: $basename -> $newname" >&2
            ((errors++)) || true
            continue
        fi
        if [[ "$DRY_RUN" == true ]]; then
            echo "Would rename: $basename -> $newname"
        else
            mv -n "$path" "$dest"
            echo "Renamed: $basename -> $newname"
        fi
        ((count++)) || true
    fi
done < <(find "$DIR" -depth -print0 2>/dev/null)

if [[ "$DRY_RUN" == true ]]; then
    echo ""
    echo "Dry run: $count item(s) would be renamed."
else
    echo ""
    echo "Done: $count item(s) renamed."
fi

[[ $errors -gt 0 ]] && exit 1
exit 0
