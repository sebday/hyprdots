#!/bin/bash
# Backup .env files from ~/projects, preserving directory structure.

set -euo pipefail

PROJECTS="${HOME}/projects"
STAMP="$(date +%Y-%m-%d_%H%M%S)"
OUT="${PROJECTS}/env-backup-${STAMP}.zip"

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

if [ "${#files[@]}" -eq 0 ]; then
  echo "no .env files found in $PROJECTS" >&2
  exit 1
fi

# Strip $PROJECTS/ prefix so zip entries keep project folder structure.
rel_files=()
for file in "${files[@]}"; do
  rel_files+=("${file#"$PROJECTS"/}")
done

cd "$PROJECTS"
zip -q "$OUT" "${rel_files[@]}"
count="${#rel_files[@]}"

echo "backed up $count .env file(s) to $OUT"
notify-send "Projects backed up" "$count .env file(s) → $(basename "$OUT")"
