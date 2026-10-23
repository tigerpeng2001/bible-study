#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -eq 0 ]; then
  echo "Usage: bash scripts/validate_yaml.sh FILE [FILE ...]" >&2
  exit 2
fi

if ! command -v yq >/dev/null 2>&1; then
  echo "YAML validation requires Mike Farah's yq v4. Install it with: brew install yq" >&2
  exit 2
fi

if [[ "$(yq --version)" != *"github.com/mikefarah/yq/"*"version v4."* ]]; then
  echo "YAML validation requires Mike Farah's yq v4. Install it with: brew install yq" >&2
  exit 2
fi

status=0
for file in "$@"; do
  if ! yq eval '.' -- "$file" >/dev/null; then
    echo "$file: YAML validation failed." >&2
    status=1
  fi
done

exit "$status"
