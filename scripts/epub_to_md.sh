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

# ──────────────────────────────────────────────
# 1. Compute relative path inside pages/
# ──────────────────────────────────────────────

# Strip leading "pages/"
REL_PATH="${INPUT_PAGES#pages/}"

# Extract subdirectory (e.g., マルコによる福音書)
REL_DIR="$(dirname "$REL_PATH")"

# Extract base filename without .pages
BASE_NAME="$(basename "$INPUT_PAGES" .pages)"

# ──────────────────────────────────────────────
# 2. Compute correct output paths (NEVER under pages/)
# ──────────────────────────────────────────────

EPUB_OUT="epub/$REL_DIR/$BASE_NAME.epub"
HTML_DIR="html/$REL_DIR"
MD_OUT="markdown/$REL_DIR/$BASE_NAME.md"

mkdir -p "$(dirname "$EPUB_OUT")"
mkdir -p "$HTML_DIR"
mkdir -p "$(dirname "$MD_OUT")"

# ──────────────────────────────────────────────
# 3. Absolute paths (AppleScript requires absolute)
# ──────────────────────────────────────────────
ABS_INPUT=$(cd "$(dirname "$INPUT_PAGES")" && pwd)/$(basename "$INPUT_PAGES")
ABS_EPUB=$(cd "$(dirname "$EPUB_OUT")" && pwd)/$(basename "$EPUB_OUT")

# ──────────────────────────────────────────────
# 4. Export Pages → EPUB
# ──────────────────────────────────────────────
$OSASCRIPT_BIN "$SCRIPT_DIR/export_pages_to_epub.applescript" "$ABS_INPUT" "$ABS_EPUB"

# ──────────────────────────────────────────────
# 5. Unzip EPUB to temp area
# ──────────────────────────────────────────────
UNZIP_DIR="$TMPDIR/$(date +%s%N)_$BASE_NAME"
mkdir -p "$UNZIP_DIR"

unzip -q "$ABS_EPUB" -d "$UNZIP_DIR"

if [ -d "$UNZIP_DIR/OEBPS" ]; then
  SRC_HTML="$UNZIP_DIR/OEBPS"
else
  SRC_HTML="$UNZIP_DIR"
fi

# Clean HTML dir
mkdir -p "$HTML_DIR"
rm -rf "$HTML_DIR"/*
cp "$SRC_HTML"/*.xhtml "$HTML_DIR"/ 2>/dev/null || true
cp "$SRC_HTML"/*.html  "$HTML_DIR"/ 2>/dev/null || true

# ──────────────────────────────────────────────
# 6. Convert XHTML → Markdown
# ──────────────────────────────────────────────
: > "$MD_OUT"

for chapter in $(ls -1 "$HTML_DIR" | sort); do
  src="$HTML_DIR/$chapter"
  echo "# Converted: $chapter" >> "$MD_OUT"
  pandoc "${PANDOC_OPTS[@]}" "$src" -o - >> "$MD_OUT"
  echo -e "\n\n" >> "$MD_OUT"
done

# Cleanup temp
rm -rf "$UNZIP_DIR"

