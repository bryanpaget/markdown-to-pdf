# Markdown to PDF Converter

A standalone GitHub composite Action that converts a Markdown file to a PDF using
[Pandoc](https://pandoc.org/) and [XeLaTeX](https://tug.org/xetex/).

This repository is **PDF-only**. The companion Word converter lives in a separate
action (`markdown-to-word`); the two can be chained together in a downstream CI
workflow if you need both formats from the same source.

## Features

- Markdown → PDF via Pandoc + XeLaTeX (great font and Unicode/emoji support).
- Table of contents and numbered sections by default.
- Optional BibTeX citations (`citeproc`) when a bibliography is provided.
- Bundled Lua filters: page breaks (`\newpage` / `<!-- pagebreak -->`) and
  ` ```ascii ` code blocks rendered to images via `ditaa`.
- Customisable through a Pandoc defaults file (`settings/pdf-settings.yml`) and
  free-form `extra_pandoc_args`.
- `::error` / `::warning` annotations for missing files or failed conversions.

## Usage

```yaml
name: Build PDF
on:
  workflow_dispatch:

jobs:
  pdf:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Repository
        uses: actions/checkout@v4

      - name: Convert Markdown to PDF
        uses: gccloudone/markdown-to-pdf@v1
        with:
          markdown_file: "docs/sample.md"
          output_file: "output/sample.pdf"
          title: "My Document"
          author: "Jane Doe"
          date: "2026-07-16"
          classification: "Unclassified | Non classifie"
          version: "v1.0.0"
          bibliography: "references.bib"

      - name: Upload PDF
        uses: actions/upload-artifact@v4
        with:
          name: pdf
          path: output/sample.pdf
```

> The composite action does not perform its own checkout — the calling workflow
> must check out the repository first.

## Inputs

| Input               | Required | Default                          | Description                                                                 |
|---------------------|----------|----------------------------------|-----------------------------------------------------------------------------|
| `markdown_file`     | yes      | —                                | Path to the Markdown file (relative to the workspace).                      |
| `output_file`       | no       | `output/output.pdf`              | Path to the output PDF (relative to the workspace).                         |
| `settings_file`     | no       | `settings/pdf-settings.yml`      | Pandoc defaults YAML. Resolved against the workspace first, then the action repo. |
| `title`             | no       | `[Untitled Document]`            | Document title (PDF metadata).                                              |
| `author`            | no       | `""`                             | Document author (PDF metadata).                                             |
| `date`              | no       | `""`                             | Document date (PDF metadata).                                               |
| `classification`    | no       | `Unclassified \| Non classifie`  | Free-form classification string (Pandoc metadata `classification`).         |
| `version`           | no       | `""`                             | Document version (Pandoc metadata `version`).                               |
| `bibliography`      | no       | `references.bib`                 | BibTeX file (relative to workspace). Enables `citeproc` when it exists.     |
| `extra_pandoc_args` | no       | `""`                             | Additional raw Pandoc arguments (e.g. `--variable=foo:bar`).                |
| `lua_filters`       | no       | `pagebreak.lua,ascii-to-image.lua` | Comma-separated Lua filters. Resolved against `filters/`, then the workspace. |

## Local usage

```bash
./convert-to-pdf.sh "My Document" docs/sample.md output/sample.pdf \
  settings/pdf-settings.yml references.bib "Unclassified | Non classifie" \
  "Jane Doe" "2026-07-16" "v1.0.0" "" "pagebreak.lua,ascii-to-image.lua"
```

All arguments can also be supplied via environment variables
(`TITLE`, `MARKDOWN_FILE`, `OUTPUT_FILE`, `SETTINGS_FILE`, `BIBLIOGRAPHY`,
`CLASSIFICATION`, `AUTHOR`, `DATE`, `VERSION`, `EXTRA_PANDOC_ARGS`, `LUA_FILTERS`).

## Customising

- **Settings:** provide your own `settings_file` (a Pandoc defaults file). See
  `settings/pdf-settings.yml` for the available keys (fonts, margins,
  `header-includes`, etc.). Core LaTeX packages and citeproc macros live in the
  template, so `header-includes` is empty by default.
- **Filters:** drop additional `.lua` files into `filters/` and reference them
  via `lua_filters`. The `mermaid.lua` filter is bundled but not enabled by
  default (it requires `mmdc`).
- **Template:** `template/latex-template.tex` is a Word-like letter template with
  narrow margins; override via the `template` key in your settings file.
- **Extra preamble:** to inject your own LaTeX packages, either edit the template
  or pass `extra_pandoc_args: "-H your-preamble.tex"` (a preamble file in your
  repo). Passing raw LaTeX via the `header-includes` metadata is not recommended
  because Pandoc escapes backslashes there.
- **Citations:** provide a BibTeX file via `bibliography`; the action enables
  `citeproc` automatically. A sample `references.bib` is included.

## Requirements (for local runs)

- `pandoc` (≥ 3.0)
- `xelatex` (TeX Live `texlive-xetex`)
- `ditaa` (for the `ascii` filter)
- Recommended fonts: DejaVu, Liberation, Noto Color Emoji, Symbola, TeX Gyre.

## Repository layout

```
action.yml                 # Composite GitHub Action (PDF)
convert-to-pdf.sh          # Conversion script (also runnable locally)
settings/pdf-settings.yml  # Default Pandoc defaults
filters/                   # Bundled Lua filters
template/latex-template.tex# LaTeX template
docs/sample.md             # Sample input
.github/workflows/test.yml # Self-test workflow
```
