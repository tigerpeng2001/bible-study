#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/config.sh"

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 path/to/file.pages" >&2
  exit 2
fi

INPUT_PAGES="$1"

# Convert relative -> repo-root relative if the caller passed an absolute path
if [[ "$INPUT_PAGES" = /* ]]; then
  # absolute path: convert to repo-root-relative
  REPO_ROOT=$(git rev-parse --show-toplevel)
  # remove leading repo root if present
  if [[ "$INPUT_PAGES" = "$REPO_ROOT"* ]]; then
    INPUT_PAGES="${INPUT_PAGES#$REPO_ROOT/}"
  else
    # absolute path outside repo -> use as-is but we still compute REL_PATH below
    :
  fi
fi

# 1) get substring AFTER the first "pages/" directory
#    e.g. Japanese/聖書新共同訳/pages/マルコ/マルコ.pages  ->  マルコ/マルコ.pages
if [[ "$INPUT_PAGES" == *"/pages/"* ]]; then
  REL_PATH="${INPUT_PAGES#*/pages/}"
elif [[ "$INPUT_PAGES" == pages/* ]]; then
  REL_PATH="${INPUT_PAGES#pages/}"
else
  # fallback: if no pages/ in path, use the basename
  REL_PATH="$(basename "$INPUT_PAGES")"
fi

REL_DIR="$(dirname "$REL_PATH")"
if [[ "$REL_DIR" == "." ]]; then
  REL_DIR=""
fi

BASE_NAME="$(basename "$INPUT_PAGES" .pages)"

# Build output paths under *top-level* epub/html/markdown, mirroring REL_DIR
if [[ -n "$REL_DIR" ]]; then
  EPUB_OUT="epub/$REL_DIR/$BASE_NAME.epub"
  HTML_DIR="html/$REL_DIR"
  MD_OUT="markdown/$REL_DIR/$BASE_NAME.md"
else
  EPUB_OUT="epub/$BASE_NAME.epub"
  HTML_DIR="html"
  MD_OUT="markdown/$BASE_NAME.md"
fi

mkdir -p "$(dirname "$EPUB_OUT")"
mkdir -p "$HTML_DIR"
mkdir -p "$(dirname "$MD_OUT")"

# Absolute paths for osascript
REPO_ROOT=$(git rev-parse --show-toplevel)
ABS_INPUT="$REPO_ROOT/$INPUT_PAGES"
ABS_EPUB="$(cd "$(dirname "$EPUB_OUT")" && pwd)/$(basename "$EPUB_OUT")"

mkdir -p "$(dirname "$ABS_EPUB")"

log "Exporting Pages -> EPUB: $ABS_INPUT -> $ABS_EPUB"
$OSASCRIPT_BIN "$SCRIPT_DIR/export_pages_to_epub.applescript" "$ABS_INPUT" "$ABS_EPUB"

# Unzip EPUB to tmp dir
UNZIP_DIR="$TMPDIR/$(date +%s%N)_$BASE_NAME"
mkdir -p "$UNZIP_DIR"
unzip -q "$ABS_EPUB" -d "$UNZIP_DIR"

# locate html/xhtml
if [ -d "$UNZIP_DIR/OEBPS" ]; then
  SRC_HTML="$UNZIP_DIR/OEBPS"
else
  SRC_HTML="$UNZIP_DIR"
fi

# Clear target HTML dir (we want a clean mirror)
rm -rf "$HTML_DIR"
mkdir -p "$HTML_DIR"

shopt -s nullglob
for f in "$SRC_HTML"/*.xhtml "$SRC_HTML"/*.html; do
  cp "$f" "$HTML_DIR/"
done
shopt -u nullglob

# Convert to Markdown (concatenate chapters)
: > "$MD_OUT"
# iterate in sorted order for deterministic output
for chapter in $(ls -1 "$HTML_DIR" | sort); do
  src="$HTML_DIR/$chapter"
  echo "<!-- Converted: $chapter -->" >> "$MD_OUT"
  pandoc "${PANDOC_OPTS[@]}" "$src" -o - >> "$MD_OUT"
  echo -e "\n\n" >> "$MD_OUT"
done

log "Wrote: $EPUB_OUT, $HTML_DIR/*, $MD_OUT"

# cleanup tmp
rm -rf "$UNZIP_DIR"

exit 0

