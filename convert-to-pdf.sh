#!/usr/bin/env bash
#
# convert-to-pdf.sh
#
# Converts a Markdown file to a PDF using Pandoc + XeLaTeX.
#
# Designed to be invoked from the composite GitHub Action (action.yml) but also
# runnable locally. All paths are resolved relative to the GitHub workspace
# (GITHUB_WORKSPACE) for inputs and relative to the action repo for bundled
# assets (filters, templates, settings).
#
set -euo pipefail

# === CONFIGURATION (defaults) ===
DEFAULT_TITLE="[Untitled Document]"
DEFAULT_MD_FILE="docs/sample.md"
DEFAULT_OUTPUT_FILE="output/sample.pdf"
DEFAULT_SETTINGS_FILE="settings/pdf-settings.yml"
DEFAULT_BIBLIOGRAPHY="references.bib"
DEFAULT_LATEX_TEMPLATE="template/latex-template.tex"
DEFAULT_CLASSIFICATION="Unclassified | Non classifie"

# === RESOLVE DIRECTORIES ===
# SCRIPT_DIR: where this script lives (inside the action repo).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# REPO_ROOT: the action repo root (used for bundled filters/templates/settings).
REPO_ROOT="$SCRIPT_DIR"
# Export so the Pandoc defaults file can reference ${REPO_ROOT} for the
# template path (otherwise pandoc resolves it relative to the CWD, which is
# the *calling* repo when this action is used as a composite/sub-action).
export REPO_ROOT
# WORKSPACE_ROOT: the user's checked-out repo (where inputs usually live).
WORKSPACE_ROOT="${GITHUB_WORKSPACE:-$PWD}"

# === ARGUMENT PARSING ===
# Positional args (used when invoked directly):
#   1: title
#   2: markdown_file
#   3: output_file
#   4: settings_file
#   5: bibliography
#   6: classification
#   7: author
#   8: date
#   9: version
#  10: extra_pandoc_args
#  11: lua_filters (comma-separated)
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

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
fi

# === CHECK DEPENDENCIES ===
if ! command -v pandoc >/dev/null 2>&1; then
    echo "::error::'pandoc' is not installed. Please install it and try again."
    exit 1
fi

if ! command -v xelatex >/dev/null 2>&1; then
    echo "::error::'xelatex' (TeX Live XeLaTeX) is not installed. Please install texlive-xetex and try again."
    exit 1
fi

# === RESOLVE INPUT PATHS ===
# Markdown, output, bibliography, and extra settings are resolved against the
# workspace (user repo) unless already absolute.
if [[ "$MARKDOWN_FILE" != /* ]]; then
    MARKDOWN_FILE="$WORKSPACE_ROOT/$MARKDOWN_FILE"
fi
if [[ "$OUTPUT_FILE" != /* ]]; then
    OUTPUT_FILE="$WORKSPACE_ROOT/$OUTPUT_FILE"
fi
if [[ "$SETTINGS_FILE" != /* && -n "$SETTINGS_FILE" ]]; then
    # Settings may live in the workspace OR bundled in the action repo.
    if [[ -f "$WORKSPACE_ROOT/$SETTINGS_FILE" ]]; then
        SETTINGS_FILE="$WORKSPACE_ROOT/$SETTINGS_FILE"
    else
        SETTINGS_FILE="$REPO_ROOT/$SETTINGS_FILE"
    fi
fi
if [[ -n "$BIBLIOGRAPHY" && "$BIBLIOGRAPHY" != /* ]]; then
    BIBLIOGRAPHY="$WORKSPACE_ROOT/$BIBLIOGRAPHY"
fi

# === VALIDATE REQUIRED FILES ===
if [[ ! -f "$MARKDOWN_FILE" ]]; then
    echo "::error::Markdown file '$MARKDOWN_FILE' not found."
    exit 1
fi

# Settings file is optional; only validate if it was explicitly provided and
# resolves to a path that does not exist.
if [[ -n "$SETTINGS_FILE" && "$SETTINGS_FILE" != "settings/pdf-settings.yml" && ! -f "$SETTINGS_FILE" ]]; then
    echo "::warning::Settings file '$SETTINGS_FILE' not found; continuing without --defaults."
    SETTINGS_FILE=""
fi

# Bibliography is optional; only use it if it exists.
if [[ -n "$BIBLIOGRAPHY" && ! -f "$BIBLIOGRAPHY" ]]; then
    echo "::warning::Bibliography '$BIBLIOGRAPHY' not found; continuing without citations."
    BIBLIOGRAPHY=""
fi

# === BUILD PANDOC COMMAND ===
mkdir -p "$(dirname "$OUTPUT_FILE")"

PANDOC_CMD=(pandoc "$MARKDOWN_FILE")

# Defaults file (if present).
if [[ -n "$SETTINGS_FILE" && -f "$SETTINGS_FILE" ]]; then
    PANDOC_CMD+=(--defaults="$SETTINGS_FILE")
fi

# Metadata.
PANDOC_CMD+=(--metadata=title:"$TITLE")
if [[ -n "$AUTHOR" ]]; then
    PANDOC_CMD+=(--metadata=author:"$AUTHOR")
fi
if [[ -n "$DATE" ]]; then
    PANDOC_CMD+=(--metadata=date:"$DATE")
fi
if [[ -n "$CLASSIFICATION" ]]; then
    PANDOC_CMD+=(--metadata=classification:"$CLASSIFICATION")
fi
if [[ -n "$VERSION" ]]; then
    PANDOC_CMD+=(--metadata=version:"$VERSION")
fi

# Lua filters.
#
# The user may pass a comma-separated list of filter paths (LUA_FILTERS_INPUT).
# Any path that is not absolute is resolved against the action repo's filters/
# directory first, then the workspace. If no list is provided, we fall back to
# the bundled filters that make sense for PDF output.
if [[ -z "$LUA_FILTERS_INPUT" ]]; then
    LUA_FILTERS_INPUT="pagebreak.lua,ascii-to-image.lua"
fi

# Convert comma-separated list to an array.
IFS=',' read -r -a FILTER_LIST <<< "$LUA_FILTERS_INPUT"
for f in "${FILTER_LIST[@]}"; do
    f="$(echo "$f" | xargs)"   # trim whitespace
    [[ -z "$f" ]] && continue
    if [[ "$f" != /* ]]; then
        if [[ -f "$REPO_ROOT/filters/$f" ]]; then
            f="$REPO_ROOT/filters/$f"
        elif [[ -f "$WORKSPACE_ROOT/$f" ]]; then
            f="$WORKSPACE_ROOT/$f"
        fi
    fi
    if [[ -f "$f" ]]; then
        PANDOC_CMD+=(--lua-filter="$f")
    else
        echo "::warning::Lua filter '$f' not found; skipping."
    fi
done

# Citations.
if [[ -n "$BIBLIOGRAPHY" && -f "$BIBLIOGRAPHY" ]]; then
    PANDOC_CMD+=(--citeproc --bibliography="$BIBLIOGRAPHY")
fi

# Structure: table of contents + numbered sections.
PANDOC_CMD+=(--toc --number-sections)

# ==========================================================
# LaTeX template (bundled in the action repo).
# Resolve absolute path to the template and add --template.
# ==========================================================
#
echo "::debug::Checking for $LATEX_TEMPLATE_PATH"
ls -la "$REPO_ROOT/template/" || echo "::debug::template/ directory missing"
LATEX_TEMPLATE_PATH="$REPO_ROOT/$DEFAULT_LATEX_TEMPLATE"
if [[ -f "$LATEX_TEMPLATE_PATH" ]]; then
    PANDOC_CMD+=(--template="$LATEX_TEMPLATE_PATH")
else
    echo "::warning::LaTeX template '$LATEX_TEMPLATE_PATH' not found; using pandoc default."
fi

echo "::debug::Checking for $LATEX_TEMPLATE_PATH"
ls -la "$REPO_ROOT/template/" || echo "::debug::template/ directory missing"

# PDF engine.
PANDOC_CMD+=(--pdf-engine=xelatex --pdf-engine-opt=--shell-escape)

# Extra user-supplied args (word-split intentionally).
if [[ -n "$EXTRA_PANDOC_ARGS" ]]; then
    # shellcheck disable=SC2206
    PANDOC_CMD+=($EXTRA_PANDOC_ARGS)
fi

# Output.
PANDOC_CMD+=(-o "$OUTPUT_FILE")

# === RUN PANDOC ===
echo "::group::Pandoc command"
echo "${PANDOC_CMD[*]}"
echo "::endgroup::"

echo "🔄 Converting '$MARKDOWN_FILE' -> '$OUTPUT_FILE' (PDF via XeLaTeX)..."
if "${PANDOC_CMD[@]}"; then
    if [[ -f "$OUTPUT_FILE" ]]; then
        echo "✅ PDF generated: $OUTPUT_FILE"
        exit 0
    else
        echo "::error::Pandoc exited successfully but output file '$OUTPUT_FILE' was not created."
        exit 1
    fi
else
    echo "::error::Pandoc failed to convert '$MARKDOWN_FILE' to PDF."
    exit 1
fi
