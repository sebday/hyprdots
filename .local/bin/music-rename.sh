#!/usr/bin/env bash
# Rename files and folders in a directory:
#   (1) Replace " " with "_"
#   (2) Replace "_-_" with "-"
#   (3) Lowercase
#   (4) Remove funky symbols (keep only a-z, 0-9, _, -, .)
#
# Albumart: In each folder, finds jpg/jpeg/gif images. If multiple exist,
# keeps the largest as albumart.{ext}. If one has "back" in the filename,
# keeps it as albumartback.{ext}; when back is the largest, uses next-largest as albumart.
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

process_albumart() {
    local dir="$1"
    local images=()
    while IFS= read -r -d '' img; do
        [[ -n "$img" ]] && images+=("$img")
    done < <(find "$dir" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.gif" \) -print0 2>/dev/null)

    [[ ${#images[@]} -eq 0 ]] && return

    # Find largest by filesize
    local largest="" largest_size=0
    for img in "${images[@]}"; do
        local size
        size=$(stat -c '%s' "$img" 2>/dev/null)
        if [[ $size -gt $largest_size ]]; then
            largest_size=$size
            largest="$img"
        fi
    done

    [[ -z "$largest" ]] && return

    # Find one with "back" in filename (case insensitive)
    local back_img=""
    for img in "${images[@]}"; do
        if [[ "$(basename "$img" | tr '[:upper:]' '[:lower:]')" == *back* ]]; then
            back_img="$img"
            break
        fi
    done

    # When multiple images and we have a "back" image, keep both albumart and albumartback
    local keep_back=false
    if [[ ${#images[@]} -gt 1 ]] && [[ -n "$back_img" ]]; then
        keep_back=true
    fi

    # If back is the largest, use next-largest as albumart; otherwise largest is albumart
    local albumart_img="$largest"
    if [[ "$keep_back" == true ]] && [[ "$back_img" == "$largest" ]]; then
        # Find second largest (excluding the back)
        local second="" second_size=0
        for img in "${images[@]}"; do
            [[ "$img" == "$largest" ]] && continue
            local size
            size=$(stat -c '%s' "$img" 2>/dev/null)
            if [[ $size -gt $second_size ]]; then
                second_size=$size
                second="$img"
            fi
        done
        [[ -n "$second" ]] && albumart_img="$second"
    fi

    local ext ext_back
    ext=$(echo "${albumart_img##*.}" | tr '[:upper:]' '[:lower:]')
    ext_back=$(echo "${back_img##*.}" | tr '[:upper:]' '[:lower:]')
    local dest="$dir/albumart.$ext"
    local dest_back="$dir/albumartback.$ext_back"

    for img in "${images[@]}"; do
        if [[ "$img" == "$albumart_img" ]]; then
            # Rename to albumart
            if [[ "$(basename "$img")" != "albumart.$ext" ]]; then
                if [[ "$DRY_RUN" == true ]]; then
                    echo "Would rename to albumart: $(basename "$img") -> albumart.$ext"
                else
                    mv -n "$img" "$dest"
                    echo "Albumart: $(basename "$img") -> albumart.$ext"
                fi
                ((count++)) || true
            fi
        elif [[ "$keep_back" == true ]] && [[ "$img" == "$back_img" ]]; then
            # Rename to albumartback
            if [[ "$DRY_RUN" == true ]]; then
                echo "Would rename to albumartback: $(basename "$img") -> albumartback.$ext_back"
            else
                mv -n "$img" "$dest_back"
                echo "Albumartback: $(basename "$img") -> albumartback.$ext_back"
            fi
            ((count++)) || true
        else
            # Remove duplicate
            if [[ "$DRY_RUN" == true ]]; then
                echo "Would remove (duplicate): $(basename "$img")"
            else
                rm "$img"
                echo "Removed duplicate: $(basename "$img")"
            fi
            ((count++)) || true
        fi
    done
}

count=0
errors=0

# Process from deepest to shallowest so parent renames don't break child paths
while IFS= read -r -d '' path; do
    [[ -z "$path" ]] && continue

    # Albumart: consolidate jpg/jpeg/gif to single albumart.{ext} per directory
    if [[ -d "$path" ]]; then
        process_albumart "$path"
    fi

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
