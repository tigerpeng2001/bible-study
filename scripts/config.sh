#!/usr/bin/env bash
# Configuration for Pages -> EPUB -> HTML -> Markdown pipeline

ROOT_DIR="Japanese"
PAGES_DIR="${ROOT_DIR}/*/pages"
EPUB_DIR="${ROOT_DIR}/*/epub"
HTML_DIR="${ROOT_DIR}/*/html"
MARKDOWN_DIR="${ROOT_DIR}/*/markdown"

PANDOC_OPTS=(--wrap=preserve -f html -t gfm)
TMPDIR=".git/pages_build"
OSASCRIPT_BIN="/usr/bin/osascript"
VERBOSE=0

log(){ if [ "$VERBOSE" -eq 1 ]; then echo "[pages-convert] $*"; fi }

mkdir -p "$TMPDIR"

