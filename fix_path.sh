#!/usr/bin/env bash

set -euo pipefail

if [ $# -ne 2 ]; then
    echo "Usage: $0 <txt1> <txt2>"
    exit 1
fi

txt1="$1"
txt2="$2"

# Escape '&' in replacement text so sed doesn't treat it specially
txt2_escaped=$(printf '%s' "$txt2" | sed 's/&/\\&/g')

# Find all regular files and replace txt1 with txt2
find . -type f -print0 | while IFS= read -r -d '' file; do
    sed -i "s|$txt1|$txt2_escaped|g" "$file"
done

