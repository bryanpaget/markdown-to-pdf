# Markdown to PDF Converter

A standalone GitHub composite Action that converts a Markdown file to a PDF using
[Pandoc](https://pandoc.org/) and [XeLaTeX](https://tug.org/xetex/).

This repository is **PDF‑only**. The companion Word converter lives in a separate
action (`markdown-to-word`); the two can be chained together in a downstream CI
workflow if you need both formats from the same source.

## Features

- Markdown → PDF via Pandoc + XeLaTeX (excellent font, Unicode, and emoji support).
- Table of contents and numbered sections by default.
- Optional BibTeX citations (`citeproc`) when a bibliography is provided.
- Bundled Lua filters: page breaks (`\newpage` / `<!-- pagebreak -->`) and
  ` ```ascii ` code blocks rendered as images via `ditaa`.
- Fully customisable through a Pandoc defaults file (`settings/pdf-settings.yml`)
  and free‑form `extra_pandoc_args`.
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

> The composite action does **not** perform its own checkout – the calling workflow must check out the repository first.

## Inputs

| Input               | Required | Default                          | Description                                                                 |
|---------------------|----------|----------------------------------|-----------------------------------------------------------------------------|
| `markdown_file`     | yes      | —                                | Path to the Markdown file (relative to the workspace).                      |
| `output_file`       | no       | `output/output.pdf`              | Path to the output PDF (relative to the workspace).                         |
| `settings_file`     | no       | `settings/pdf-settings.yml`      | Pandoc defaults YAML. Resolved against the workspace first, then the action repo. |
| `title`             | no       | `[Untitled Document]`            | Document title (PDF metadata).                                              |
| `author`            | no       | `""`                             | Document author (PDF metadata).                                             |
| `date`              | no       | `""`                             | Document date (PDF metadata).                                               |
| `classification`    | no       | `Unclassified \| Non classifie`  | Free‑form classification string (Pandoc metadata `classification`).         |
| `version`           | no       | `""`                             | Document version (Pandoc metadata `version`).                               |
| `bibliography`      | no       | `references.bib`                 | BibTeX file (relative to workspace). Enables `citeproc` when present.       |
| `extra_pandoc_args` | no       | `""`                             | Additional raw Pandoc arguments (e.g. `--variable=foo:bar`).                |
| `lua_filters`       | no       | `pagebreak.lua,ascii-to-image.lua` | Comma‑separated Lua filters. Resolved against `filters/`, then the workspace. |

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

### PDF styling (fonts, margins, line spacing)

The default settings are defined in `settings/pdf-settings.yml`. The bundled
LaTeX template (`template/latex-template.tex`) reads these variables directly:

| Setting         | Effect                               |
|-----------------|--------------------------------------|
| `fontsize`      | Body text size (e.g. `10pt`)         |
| `mainfont`      | Main font family (e.g. `DejaVu Sans`)|
| `monofont`      | Monospaced font (e.g. `DejaVu Sans Mono`)|
| `geometry`      | Page margins (e.g. `margin=0.75in`)  |
| `linestretch`   | Line spacing multiplier (e.g. `1.15`)|
| `classoption`   | Extra options for `\documentclass`   |
| `titlepage`     | Set to `false` to suppress the title page |

To use your own settings, provide a custom `settings_file` in the action inputs.
The file must follow Pandoc’s [defaults syntax](https://pandoc.org/MANUAL.html#defaults-files).

### Table formatting (shrink wide tables)

The default `settings/pdf-settings.yml` injects the following LaTeX code
(via `metadata.header-includes`) to make tables more compact and print‑friendly:

```yaml
metadata:
  header-includes: |
    \usepackage{caption}
    \captionsetup[table]{font=small, labelfont=bf}
    \AtBeginEnvironment{tabular}{\small}
    \AtBeginEnvironment{longtable}{\small}
    \setlength{\tabcolsep}{4pt}
    \renewcommand{\arraystretch}{1.1}
```

You can adjust these values in your own settings file or replace them entirely.

### Lua filters

- `pagebreak.lua` – converts `\newpage` or `<!-- pagebreak -->` into page breaks.
- `ascii-to-image.lua` – renders ` ```ascii ` code blocks as PNG images via `ditaa`.
- `mermaid.lua` – bundled but **not enabled** by default (requires `mmdc`).
  To use it, set `lua_filters: "pagebreak.lua,ascii-to-image.lua,mermaid.lua"` and ensure
  `mmdc` is installed (the action does not install it by default).

### Custom LaTeX preamble

If the bundled template does not suit your needs, you have two options:

1. **Edit the template** – modify `template/latex-template.tex` directly.
2. **Inject LaTeX code** – use `extra_pandoc_args: "-H your-preamble.tex"`,
   where `your-preamble.tex` is a file in your repository containing raw LaTeX.
   This is more portable than relying on `header-includes` in the defaults file,
   because pandoc may escape backslashes in YAML strings (though using `|` blocks works).

### Template override

The action always uses `template/latex-template.tex` (bundled). To use a different
template, you can pass `extra_pandoc_args: "--template=path/to/your-template.tex"`.
Make sure the template file exists in the workspace.

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
template/latex-template.tex# LaTeX template (uses variables from settings)
docs/sample.md             # Sample input
.github/workflows/test.yml # Self-test workflow
```

## License

GPL or similar
