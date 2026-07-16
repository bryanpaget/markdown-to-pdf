#!/usr/bin/env bash
set -euo pipefail

# === CONFIGURATION ===
DEFAULT_TITLE="[Untitled Document]"
DEFAULT_MD_FILE="docs/sample.md"
DEFAULT_OUTPUT_FILE="output/sample.pdf"
DEFAULT_SETTINGS_FILE="settings/pdf-settings.yml"
DEFAULT_BIBLIOGRAPHY="references.bib"
DEFAULT_CLASSIFICATION="Unclassified | Non classifie"

# === RESOLVE DIRECTORIES ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
WORKSPACE_ROOT="${GITHUB_WORKSPACE:-$PWD}"

# === ARGUMENT PARSING ===
TITLE="${1:-${TITLE:-$DEFAULT_TITLE}}"
MARKDOWN_FILE="${2:-${MARKDOWN_FILE:-$DEFAULT_MD_FILE}}"
OUTPUT_FILE="${3:-${OUTPUT_FILE:-$DEFAULT_OUTPUT_FILE}}"
SETTINGS_FILE="${4:-${SETTINGS_FILE:-$DEFAULT_SETTINGS_FILE}}"
BIBLIOGRAPHY="${5:-${BIBLIOGRAPHY:-$DEFAULT_BIBLIOGRAPHY}}"
CLASSIFICATION="${6:-${CLASSIFICATION:-$DEFAULT_CLASSIFICATION}}"
AUTHOR="${7:-${AUTHOR:-}}"
DATE="${8:-${DATE:-}}"
VERSION="${9:-${VERSION:-}}"
EXTRA_PANDOC_ARGS="${10:-${EXTRA_PANDOC_ARGS:-}}"
LUA_FILTERS_INPUT="${11:-${LUA_FILTERS:-}}"

usage() {
    echo "Usage: $0 [title] [markdown_file] [output_file] [settings_file] [bibliography] [classification] [author] [date] [version] [extra_pandoc_args] [lua_filters]"
    exit 1
}
[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage

# === DEPENDENCIES ===
command -v pandoc >/dev/null 2>&1 || { echo "::error::pandoc not installed."; exit 1; }
command -v xelatex >/dev/null 2>&1 || { echo "::error::xelatex not installed."; exit 1; }

# === RESOLVE INPUT PATHS ===
[[ "$MARKDOWN_FILE" != /* ]] && MARKDOWN_FILE="$WORKSPACE_ROOT/$MARKDOWN_FILE"
[[ "$OUTPUT_FILE" != /* ]] && OUTPUT_FILE="$WORKSPACE_ROOT/$OUTPUT_FILE"
if [[ -n "$SETTINGS_FILE" && "$SETTINGS_FILE" != /* ]]; then
    [[ -f "$WORKSPACE_ROOT/$SETTINGS_FILE" ]] && SETTINGS_FILE="$WORKSPACE_ROOT/$SETTINGS_FILE" || SETTINGS_FILE="$REPO_ROOT/$SETTINGS_FILE"
fi
[[ -n "$BIBLIOGRAPHY" && "$BIBLIOGRAPHY" != /* ]] && BIBLIOGRAPHY="$WORKSPACE_ROOT/$BIBLIOGRAPHY"

# === VALIDATE ===
[[ -f "$MARKDOWN_FILE" ]] || { echo "::error::Markdown file not found: $MARKDOWN_FILE"; exit 1; }
if [[ -n "$SETTINGS_FILE" && ! -f "$SETTINGS_FILE" ]]; then
    echo "::warning::Settings file not found; disabling --defaults."
    SETTINGS_FILE=""
fi
[[ -n "$BIBLIOGRAPHY" && ! -f "$BIBLIOGRAPHY" ]] && BIBLIOGRAPHY=""

# === BUILD PANDOC COMMAND ===
mkdir -p "$(dirname "$OUTPUT_FILE")"
PANDOC_CMD=(pandoc "$MARKDOWN_FILE")

# Defaults file.
if [[ -n "$SETTINGS_FILE" && -f "$SETTINGS_FILE" ]]; then
    PANDOC_CMD+=(--defaults="$SETTINGS_FILE")
fi

# Metadata.
PANDOC_CMD+=(--metadata=title:"$TITLE")
[[ -n "$AUTHOR" ]] && PANDOC_CMD+=(--metadata=author:"$AUTHOR")
[[ -n "$DATE" ]] && PANDOC_CMD+=(--metadata=date:"$DATE")
[[ -n "$CLASSIFICATION" ]] && PANDOC_CMD+=(--metadata=classification:"$CLASSIFICATION")
[[ -n "$VERSION" ]] && PANDOC_CMD+=(--metadata=version:"$VERSION")

# Lua filters – default to only pagebreak.lua (removed ascii-to-image to avoid issues).
if [[ -z "$LUA_FILTERS_INPUT" ]]; then
    LUA_FILTERS_INPUT="pagebreak.lua"
fi
IFS=',' read -r -a FILTER_LIST <<< "$LUA_FILTERS_INPUT"
for f in "${FILTER_LIST[@]}"; do
    f="$(echo "$f" | xargs)"
    [[ -z "$f" ]] && continue
    if [[ "$f" != /* ]]; then
        [[ -f "$REPO_ROOT/filters/$f" ]] && f="$REPO_ROOT/filters/$f" || f="$WORKSPACE_ROOT/$f"
    fi
    [[ -f "$f" ]] && PANDOC_CMD+=(--lua-filter="$f") || echo "::warning::Lua filter '$f' not found; skipping."
done

# Citations.
[[ -n "$BIBLIOGRAPHY" && -f "$BIBLIOGRAPHY" ]] && PANDOC_CMD+=(--citeproc --bibliography="$BIBLIOGRAPHY")

# TOC, sections.
PANDOC_CMD+=(--toc --number-sections)

# PDF engine.
PANDOC_CMD+=(--pdf-engine=xelatex --pdf-engine-opt=--shell-escape)

# Extra args.
if [[ -n "$EXTRA_PANDOC_ARGS" ]]; then
    # shellcheck disable=SC2206
    PANDOC_CMD+=($EXTRA_PANDOC_ARGS)
fi

PANDOC_CMD+=(-o "$OUTPUT_FILE")

# === RUN ===
echo "::group::Pandoc command"
echo "${PANDOC_CMD[*]}"
echo "::endgroup::"
echo "🔄 Converting '$MARKDOWN_FILE' -> '$OUTPUT_FILE' (PDF via XeLaTeX)..."
if "${PANDOC_CMD[@]}"; then
    if [[ -f "$OUTPUT_FILE" ]]; then
        echo "✅ PDF generated: $OUTPUT_FILE"
        exit 0
    else
        echo "::error::Pandoc exited successfully but no output file."
        exit 1
    fi
else
    echo "::error::Pandoc conversion failed."
    exit 1
fi
