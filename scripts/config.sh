ROOT_DIR="."
PANDOC_OPTS=(--wrap=preserve -f html -t gfm)
TMPDIR=".git/pages_build"
OSASCRIPT_BIN="/usr/bin/osascript"
VERBOSE=0
log(){ if [ "$VERBOSE" -eq 1 ]; then echo "[pages] $*"; fi; }
mkdir -p "$TMPDIR"

