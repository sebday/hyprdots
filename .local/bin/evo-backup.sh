#!/bin/bash
# Backup project .env files and evo-shell secrets, preserving paths.

set -euo pipefail

PROJECTS="${HOME}/projects"
STAMP="$(date +%Y-%m-%d_%H%M%S)"
OUT="${PROJECTS}/env-backup-${STAMP}.zip"
EVO_SECRETS="${XDG_DATA_HOME:-$HOME/.local/share}/evo-shell/secrets.env"

if [ ! -d "$PROJECTS" ]; then
  echo "projects directory not found: $PROJECTS" >&2
  exit 1
fi

mapfile -d '' -t files < <(
  find "$PROJECTS" -type f \( -name '.env' -o -name '.env.*' \) \
    ! -name '.env.example' \
    ! -name '.env.sample' \
    ! -name '.env.template' \
    -print0
)

# Strip $PROJECTS/ prefix so zip entries keep project folder structure.
rel_files=()
for file in "${files[@]}"; do
  rel_files+=("${file#"$PROJECTS"/}")
done

extra=0
if [ -f "$EVO_SECRETS" ]; then
  extra=1
fi

if [ "${#rel_files[@]}" -eq 0 ] && [ "$extra" -eq 0 ]; then
  echo "no .env files found in $PROJECTS and missing $EVO_SECRETS" >&2
  exit 1
fi

if [ "${#rel_files[@]}" -gt 0 ]; then
  (cd "$PROJECTS" && zip -q "$OUT" "${rel_files[@]}")
fi

if [ "$extra" -eq 1 ]; then
  # Keep ~/.local/share/evo-shell path inside the archive.
  (cd "$HOME" && zip -q "$OUT" ".local/share/evo-shell/secrets.env")
fi

count=$((${#rel_files[@]} + extra))

echo "backed up $count file(s) to $OUT"
notify-send "Evo backup" "$count file(s) → $(basename "$OUT")"
