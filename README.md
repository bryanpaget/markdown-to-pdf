# Markdown/Word to PDF

A GitHub composite Action that converts Markdown or Word (`.docx`/`.doc`) files
to PDF. Markdown files are first converted to `.docx` via
[Pandoc](https://pandoc.org/), then the Word document is converted to PDF using
[LibreOffice](https://www.libreoffice.org/) in headless mode.

![Markdown source to rendered PDF comparison](assets/screenshot-comparison.png)

The PDF preserves the document's layout, fonts, and template styling, which is
not possible with a separate Pandoc/LaTeX render.

## Performance

Key optimization opportunities for this action:

| Area | Issue | Recommendation |
|------|-------|---------------|
| **apt-get update** | Called separately in LibreOffice and font install steps. Each call is ~5-10s. | Consolidate into one `apt-get update` before installing any packages. |
| **Pandoc download** | Downloaded from GitHub releases every run (~20MB). | Add `actions/cache` for the `.deb` file keyed by version, or pre-install in a custom runner. |
| **FontConfig write** | `/etc/fonts/conf.d/99-calibri-carlito.conf` is rewritten every run. | Idempotent by design — negligible impact but could check before writing. |
| **LibreOffice profile** | Fresh temp profile per run avoids lock contention. | Correct as-is; no change needed. |
| **font install** | `ttf-mscorefonts-installer` (~30MB) installs every run. | Cache the apt packages using `actions/cache` for `apt-get install` artifacts. |
| **Python processing** | `fix-docx-tables.py` reads/writes the entire DOCX zip in memory. | Fine for typical docs (<10MB). For very large documents with embedded media, stream process. |

Most of these are inherent to running a composite action on a fresh runner.
The largest real-world gains come from **caching Pandoc and font packages**
and **consolidating apt operations**.

## Usage

### From a Markdown file

```yaml
- name: Convert Markdown to PDF
  uses: bryanpaget/markdown-to-pdf@main
  with:
    markdown_file: "docs/readme.md"
    pdf_file: "output/readme.pdf"
```

### From a Word document

```yaml
- name: Convert Word to PDF
  uses: bryanpaget/markdown-to-pdf@main
  with:
    docx_file: "output/document.docx"
    pdf_file: "output/document.pdf"
```

## Inputs

| Input           | Required | Description                                             |
|-----------------|----------|---------------------------------------------------------|
| `docx_file`     | no       | Path to the source Word document (.docx/.doc).          |
| `markdown_file` | no       | Path to a Markdown file (auto-converted to .docx first).|
| `pdf_file`      | yes      | Path where the resulting PDF should be written.         |

Provide either `docx_file` or `markdown_file` (not both).

## Outputs

| Output    | Description                                  |
|-----------|----------------------------------------------|
| `pdf_file`| Resolved path to the generated PDF.          |

## Sample PDFs

Pre-built sample PDFs are attached to each
[release](https://github.com/bryanpaget/markdown-to-pdf/releases). They are
generated from [`samples/complex-document.md`](samples/complex-document.md) —
a document exercising tables, lists, code blocks, blockquotes, and extensive
formatting. Both the Markdown→PDF and DOCX→PDF paths are included.

To generate them locally:

```bash
pandoc samples/complex-document.md -o samples/complex-document.docx
python3 fix-docx-tables.py samples/complex-document.docx
soffice --headless --convert-to pdf samples/complex-document.docx
```

## Requirements

- `libreoffice-writer` (auto-installed if missing)
- `pandoc` (auto-installed if using `markdown_file`)

## License

GPL or similar
