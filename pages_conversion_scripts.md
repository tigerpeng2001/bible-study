# Automatic Pages → EPUB → HTML → Markdown Conversion

These are the scripts and hook to enable local, automatic conversion when any `.pages` file under `Japanese/pages/**` is committed. The pipeline mirrors the `pages/` folder structure into `epub/`, `html/`, and `markdown/` directories.

---

## Files to add to your repo (paths shown)

- `.git/hooks/pre-commit`  (executable)
- `scripts/export_pages_to_epub.applescript`
- `scripts/epub_to_md.sh`  (executable)
- `scripts/config.sh`      (sourced by other scripts)

Copy each block below into the matching file path and make the hook + `epub_to_md.sh` executable.

---

## File: scripts/config.sh

```bash
#!/usr/bin/env bash
# Configuration for Pages -> EPUB -> HTML -> Markdown pipeline

# Root of the content (relative to repo root)
ROOT_DIR="Japanese"

# directories (will be created if missing)
PAGES_DIR="${ROOT_DIR}/*/pages"
EPUB_DIR="${ROOT_DIR}/*/epub"
HTML_DIR="${ROOT_DIR}/*/html"
MARKDOWN_DIR="${ROOT_DIR}/*/markdown"

# pandoc options — preserve raw HTML (ruby tags)
PANDOC_OPTS=(--wrap=preserve -f html -t gfm)

# Temporary working dir for unzipping
TMPDIR=".git/pages_build"

# AppleScript runner binary (osascript)\OSASCRIPT_BIN="/usr/bin/osascript"

# Debug: set to 1 to print more logs
VERBOSE=0

log(){ if [ "$VERBOSE" -eq 1 ]; then echo "[pages-convert] $*"; fi }

mkdir -p "$TMPDIR"
```

---

## File: scripts/export_pages_to_epub.applescript

```applescript
-- Usage:
-- osascript export_pages_to_epub.applescript "/full/path/to/input.pages" "/full/path/to/output.epub"

on run argv
    if (count of argv) < 2 then
        return "Usage: osascript export_pages_to_epub.applescript INPUT.pages OUTPUT.epub"
    end if

    set inputPath to item 1 of argv
    set outputPath to item 2 of argv

    tell application "Pages"
        open POSIX file inputPath
        delay 0.5
        try
            export front document to POSIX file outputPath as EPUB
        on error errMsg number errNum
            -- propagate error
            close front document saving no
            error errMsg number errNum
        end try
        close front document saving no
    end tell

    return "OK"
end run
```

---

## File: scripts/epub_to_md.sh

```bash
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# repo-root relative execution expected
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/config.sh"

function usage(){
  echo "Usage: $0 INPUT.pages OUTPUT_BASE_DIR"
  echo "Example: $0 \"Japanese/聖書新共同訳/pages/聖書新共同訳.pages\" \"Japanese/聖書新共同訳\""
}

if [ "$#" -ne 2 ]; then
  usage
  exit 2
fi

INPUT_PAGES="$1"
OUT_BASE="$2"

# Ensure output directories exist (mirroring will be created by caller)
mkdir -p "$OUT_BASE/epub"
mkdir -p "$OUT_BASE/html"
mkdir -p "$OUT_BASE/markdown"

# Compute filenames
BASE_NAME=$(basename "$INPUT_PAGES" .pages)
PARENT_DIR=$(dirname "$INPUT_PAGES")
# We expect PARENT_DIR like .../pages or .../somefolder/pages
ROOT_PARENT=$(dirname "$PARENT_DIR")

# Destination EPUB path (mirror structure)
REL_DIR=${PARENT_DIR#*/} # not exact; we'll create target directly under OUT_BASE
EPUB_OUT="$OUT_BASE/epub/$BASE_NAME.epub"

log "Exporting $INPUT_PAGES -> $EPUB_OUT"

# Use AppleScript to export Pages -> EPUB
# NOTE: osascript requires absolute paths
ABS_INPUT=$(cd "$(dirname "$INPUT_PAGES")" && pwd)/$(basename "$INPUT_PAGES")
ABS_EPUB=$(cd "$(dirname "$EPUB_OUT")" || mkdir -p "$(dirname "$EPUB_OUT")"; pwd)/$(basename "$EPUB_OUT")

mkdir -p "$(dirname "$ABS_EPUB")"

$OSASCRIPT_BIN "$SCRIPT_DIR/export_pages_to_epub.applescript" "$ABS_INPUT" "$ABS_EPUB"

# Unzip EPUB to html output directory
UNZIP_DIR="$TMPDIR/$(date +%s%N)_$BASE_NAME"
mkdir -p "$UNZIP_DIR"

unzip -q "$ABS_EPUB" -d "$UNZIP_DIR"

# Find XHTML / HTML files (commonly under OEBPS)
HTML_SRC_DIR=""
if [ -d "$UNZIP_DIR/OEBPS" ]; then
  HTML_SRC_DIR="$UNZIP_DIR/OEBPS"
else
  # fallback: search for .xhtml
  HTML_SRC_DIR="$UNZIP_DIR"
fi

# Copy html files to target html folder (mirror)
HTML_TARGET_DIR="$OUT_BASE/html/$BASE_NAME"
mkdir -p "$HTML_TARGET_DIR"

# move or copy xhtml files
shopt -s nullglob
for f in "$HTML_SRC_DIR"/*.xhtml "$HTML_SRC_DIR"/*.html; do
  cp "$f" "$HTML_TARGET_DIR/"
done
shopt -u nullglob

# Convert main HTML files to markdown using pandoc
# We'll concatenate chapter files if many
MD_OUT="$OUT_BASE/markdown/$BASE_NAME.md"

# Create or empty MD_OUT
: > "$MD_OUT"

# Convert each xhtml file in natural sort order
for chapter in $(ls -1 "$HTML_TARGET_DIR" | sort); do
  src="$HTML_TARGET_DIR/$chapter"
  echo "# Converted: $chapter" >> "$MD_OUT"
  pandoc "${PANDOC_OPTS[@]}" "$src" -o - >> "$MD_OUT"
  echo "\n\n" >> "$MD_OUT"
done

log "Generated Markdown: $MD_OUT"

# Clean up
rm -rf "$UNZIP_DIR"

# Stage outputs (git add) — caller/hook may handle staging
# git add "$EPUB_OUT" "$HTML_TARGET_DIR" "$MD_OUT"

exit 0
```

---

## File: .git/hooks/pre-commit

> **Important:** this hook must be executable. It looks for staged `.pages` files under `Japanese/**/pages/` and runs the conversion for each changed file.

```bash
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

SCRIPT_DIR="scripts"
HOOK_LOG=".git/hooks/pages_convert.log"

# find staged .pages files under Japanese/**/pages
PAGES_CHANGED=$(git diff --cached --name-only --diff-filter=ACM | grep -E '^Japanese/.*/pages/.*\.pages$' || true)

if [ -z "$PAGES_CHANGED" ]; then
  exit 0
fi

echo "[pre-commit] Detected .pages changes:"
for p in $PAGES_CHANGED; do
  echo "  - $p"
done

# For each changed .pages, run conversion
for PAGE_FILE in $PAGES_CHANGED; do
  # derive base folder (assume structure Japanese/<book>*/pages/<file>.pages)
  BOOK_DIR=$(dirname "$(dirname "$PAGE_FILE")")
  OUT_BASE="$BOOK_DIR"

  echo "[pre-commit] Converting $PAGE_FILE -> $OUT_BASE"
  "$SCRIPT_DIR/epub_to_md.sh" "$PAGE_FILE" "$OUT_BASE" >> "$HOOK_LOG" 2>&1 || {
    echo "[pre-commit] Conversion failed for $PAGE_FILE — check $HOOK_LOG"
    # Prevent commit if conversion fails
    exit 1
  }

  # Add generated files to the commit
  git add "$OUT_BASE/epub/" "$OUT_BASE/html/" "$OUT_BASE/markdown/"
done

exit 0
```

---

## Installation notes

1. Copy the files into your repository at the exact paths shown.
2. Make the scripts executable:

```bash
chmod +x scripts/epub_to_md.sh
chmod +x .git/hooks/pre-commit
```

3. Ensure `pandoc` is installed on your Mac:

```bash
brew install pandoc
```

4. Make sure Pages is installed and scriptable (it normally is on macOS).

5. Test manually first:

```bash
# simulate converting one file
./scripts/epub_to_md.sh "Japanese/聖書新共同訳/pages/聖書新共同訳.pages" "Japanese/聖書新共同訳"
```

6. Commit your changes — the hook will run and update markdown.

---

If you’d like, I can now (choose one):

- Split each script into separate canvas files (I already created this single canvas doc) — reply **split**
- Create a downloadable ZIP containing the scripts — reply **zip**
- Walk through a dry-run with your actual `.pages` file (you'll need to run the command locally) — reply **dryrun**

---

*End of scripts document.*

