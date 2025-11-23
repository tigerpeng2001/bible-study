#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/config.sh"

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 INPUT.pages OUTPUT_BASE_DIR" >&2
  exit 2
fi

INPUT_PAGES="$1"
OUT_BASE="$2"

mkdir -p "$OUT_BASE/epub" "$OUT_BASE/html" "$OUT_BASE/markdown"

BASE_NAME=$(basename "$INPUT_PAGES" .pages)
EPUB_OUT="$OUT_BASE/epub/$BASE_NAME.epub"

ABS_INPUT=$(cd "$(dirname "$INPUT_PAGES")" && pwd)/$(basename "$INPUT_PAGES")
mkdir -p "$(dirname "$EPUB_OUT")"
ABS_EPUB=$(cd "$(dirname "$EPUB_OUT")" && pwd)/$(basename "$EPUB_OUT")

$OSASCRIPT_BIN "$SCRIPT_DIR/export_pages_to_epub.applescript" "$ABS_INPUT" "$ABS_EPUB"

UNZIP_DIR="$TMPDIR/$(date +%s%N)_$BASE_NAME"
mkdir -p "$UNZIP_DIR"
unzip -q "$ABS_EPUB" -d "$UNZIP_DIR"

HTML_SRC_DIR="$UNZIP_DIR/OEBPS"
[ ! -d "$HTML_SRC_DIR" ] && HTML_SRC_DIR="$UNZIP_DIR"

HTML_TARGET_DIR="$OUT_BASE/html/$BASE_NAME"
mkdir -p "$HTML_TARGET_DIR"

shopt -s nullglob
for f in "$HTML_SRC_DIR"/*.xhtml "$HTML_SRC_DIR"/*.html; do
  cp "$f" "$HTML_TARGET_DIR/"
done
shopt -u nullglob

MD_OUT="$OUT_BASE/markdown/$BASE_NAME.md"
: > "$MD_OUT"

for chapter in $(ls -1 "$HTML_TARGET_DIR" | sort); do
  src="$HTML_TARGET_DIR/$chapter"
  echo "# Converted: $chapter" >> "$MD_OUT"
  pandoc "${PANDOC_OPTS[@]}" "$src" -o - >> "$MD_OUT"
  echo -e "\n\n" >> "$MD_OUT"
done

rm -rf "$UNZIP_DIR"

